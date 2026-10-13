-- Spawns the fish that swim in the pond, checks spear hits and hands out catches.
-- Fish positions come from FishPath segments, so clients draw the same fish with no streaming.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local FishPath = require(Shared.FishPath)
local GunData = require(Shared.GunData)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)

local FishService = {}

local fishes = {} -- [id] = fish
local nextId = 0
local rng = Random.new()
local lastShot: { [Player]: any } = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function margin(species)
	return math.max(3, species.Look.L * 0.6)
end

local function snapshot(f)
	return { Id = f.Id, Species = f.Species, Kg = f.Kg, HP = f.HP, MaxHP = f.MaxHP, Seg = f.Seg }
end

local function spawnFish(zone)
	local species, kg = FishData.RollForZone(zone.Name, rng)
	local hp = FishData.GetRarity(species.Id).HP
	nextId += 1
	local t = now()
	local f = {
		Id = nextId,
		Species = species.Id,
		Kg = kg,
		HP = hp,
		MaxHP = hp,
		Zone = zone,
		Speed = species.Speed,
		Seg = FishPath.NewSegment(rng, zone, FishPath.RandomPoint(rng, zone, margin(species)), t, species.Speed, margin(species)),
		NextRepath = t + rng:NextNumber(Config.FishRepath[1], Config.FishRepath[2]),
		FleeUntil = 0,
	}
	fishes[f.Id] = f
	Remotes.FishSpawned:FireAllClients(snapshot(f))
end

local function repath(f, awayFrom: Vector3?)
	local t = now()
	local species = FishData.ById[f.Species]
	local speed = if t < f.FleeUntil then f.Speed * 2 else f.Speed
	f.Seg = FishPath.NewSegment(rng, f.Zone, FishPath.Position(f.Seg, t), t, speed, margin(species), awayFrom)
	f.NextRepath = t + (if awayFrom then Config.FleeTime else rng:NextNumber(Config.FishRepath[1], Config.FishRepath[2]))
end

local function equippedGun(player: Player)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("GunId")
	return id and GunData.ById[id]
end

local function catch(player: Player, f, data)
	fishes[f.Id] = nil
	table.insert(data.Inventory, { Id = f.Species, Kg = f.Kg })
	data.Caught += 1
	local best = data.Discovered[f.Species]
	local isNew = best == nil
	local isRecord = best ~= nil and f.Kg > best
	if isNew or isRecord then
		data.Discovered[f.Species] = f.Kg
	end
	DataService.Changed(player)
	Remotes.FishRemoved:FireAllClients(f.Id, player.UserId)
	Remotes.CatchResult:FireClient(player, true, {
		Id = f.Species,
		Kg = f.Kg,
		Rarity = FishData.ById[f.Species].Rarity,
		Value = FishData.GetValue(f.Species, f.Kg),
		New = isNew,
		Record = isRecord,
	})
	if FishData.RarityIndex[FishData.ById[f.Species].Rarity] >= FishData.RarityIndex.Legendary then
		Remotes.Announce:FireAllClients(player.DisplayName, f.Species, FishData.ById[f.Species].Rarity, f.Kg)
	end
	local zone = f.Zone
	task.delay(Config.FishRespawn, spawnFish, zone)
end

local function onShoot(player: Player, origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or origin ~= origin or direction ~= direction then
		return
	end
	if direction.Magnitude < 0.5 then
		return
	end
	local gun = equippedGun(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not gun or not root or (origin - root.Position).Magnitude > 14 then
		return
	end
	local t = now()
	local last = lastShot[player]
	if last and t - last.Time < gun.Reload * 0.8 then
		return -- firing faster than the gun reloads
	end
	lastShot[player] = { Time = t, Origin = origin, Dir = direction.Unit, Gun = gun, Hits = 0 }
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.SpearFired:FireClient(other, player, origin, direction.Unit, gun.Id)
		end
	end
end

local function onHit(player: Player, fishId, hitTime)
	if type(fishId) ~= "number" or type(hitTime) ~= "number" or hitTime ~= hitTime then
		return
	end
	local shot = lastShot[player]
	local f = fishes[fishId]
	if not shot or not f or shot.Hits > 0 then
		return
	end
	local t = now()
	local flight = shot.Gun.Range / math.min(Config.SpearSpeed, Config.SpearSpeedWater)
	if t - shot.Time > flight + 1.5 then
		return
	end
	hitTime = math.clamp(hitTime, shot.Time, t)
	local species = FishData.ById[f.Species]
	local pos = FishPath.Position(f.Seg, hitTime)
	-- The fish must be within the gun's reach of where the spear was fired from.
	local reach = shot.Gun.Range + species.Look.L * FishData.SizeScale(f.Species, f.Kg) + Config.HitTolerance
	if (pos - shot.Origin).Magnitude > reach then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	if #data.Inventory >= Config.InventoryCap then
		Remotes.Notify:FireClient(player, "Your bag is full! Sell your fish first.", "error")
		return
	end
	shot.Hits += 1
	f.HP -= shot.Gun.Damage
	if f.HP <= 0 then
		catch(player, f, data)
	else
		f.FleeUntil = t + Config.FleeTime
		repath(f, shot.Origin)
		Remotes.FishUpdated:FireAllClients(f.Id, f.Seg, f.HP, player.UserId)
	end
end

function FishService.Init()
	for _, zone in FishPath.Zones do
		for _ = 1, zone.Count do
			spawnFish(zone)
		end
	end

	Remotes.GetFish.OnServerInvoke = function()
		local list = {}
		for _, f in fishes do
			table.insert(list, snapshot(f))
		end
		return list
	end
	Remotes.Shoot.OnServerEvent:Connect(onShoot)
	Remotes.SpearHit.OnServerEvent:Connect(onHit)
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
	end)

	-- Fish wander: every so often each one heads somewhere new.
	task.spawn(function()
		while true do
			task.wait(0.5)
			local t = now()
			for _, f in fishes do
				if t >= f.NextRepath then
					repath(f)
					Remotes.FishUpdated:FireAllClients(f.Id, f.Seg, f.HP, nil)
				end
			end
		end
	end)
end

return FishService
