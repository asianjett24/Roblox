-- Spawns the creatures that swim in the pit, checks spear hits and hands catches to the
-- ChaseService (you carry the catch until you escape the water).
-- Positions come from FishPath segments, so clients draw the same creatures with no streaming.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local FishPath = require(Shared.FishPath)
local GunData = require(Shared.GunData)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)
local DataService = require(script.Parent.DataService)

local FishService = {}

local fishes = {} -- [id] = creature
local nextId = 0
local rng = Random.new()
local lastShot: { [Player]: any } = {}
local ChaseService -- set in Init (avoids a require loop)

local function now()
	return workspace:GetServerTimeNow()
end

local function lengthOf(f)
	return FishData.ById[f.Species].Look.L * FishData.SizeByName[f.Size].Scale
end

local function margin(f)
	return math.max(3, lengthOf(f) * 0.6)
end

-- Rare creatures stay near their guardian's lair, like eggs around a sleeping beast.
local function boxFor(zone, species)
	if FishData.RarityIndex[species.Rarity] < 3 then
		return zone
	end
	local r = Config.LairRadius
	local lair = zone.Lairs[rng:NextInteger(1, #zone.Lairs)]
	local lo = Vector3.new(math.max(zone.Min.X, lair.X - r), zone.Min.Y, math.max(zone.Min.Z, lair.Z - r))
	local hi = Vector3.new(math.min(zone.Max.X, lair.X + r), math.min(zone.Max.Y, lair.Y + r), math.min(zone.Max.Z, lair.Z + r))
	return { Min = lo, Max = hi }
end

local function snapshot(f)
	return { Id = f.Id, Species = f.Species, Kg = f.Kg, Size = f.Size, Mut = f.Mut, HP = f.HP, MaxHP = f.MaxHP, Seg = f.Seg }
end

local function spawnFish(zone)
	local species, size, mut, kg = FishData.Roll(zone.Name, rng)
	local hp = FishData.GetRarity(species.Id).HP
	nextId += 1
	local f = { Id = nextId, Species = species.Id, Kg = kg, Size = size, Mut = mut, HP = hp, MaxHP = hp, Zone = zone, Speed = species.Speed, FleeUntil = 0 }
	f.Box = boxFor(zone, species)
	local t = now()
	f.Seg = FishPath.NewSegment(rng, f.Box, FishPath.RandomPoint(rng, f.Box, margin(f)), t, f.Speed, margin(f))
	f.NextRepath = t + rng:NextNumber(Config.FishRepath[1], Config.FishRepath[2])
	fishes[f.Id] = f
	Remotes.FishSpawned:FireAllClients(snapshot(f))
end

local function repath(f, awayFrom: Vector3?)
	local t = now()
	local speed = if t < f.FleeUntil then f.Speed * 2 else f.Speed
	f.Seg = FishPath.NewSegment(rng, f.Box, FishPath.Position(f.Seg, t), t, speed, margin(f), awayFrom)
	f.NextRepath = t + (if awayFrom then Config.FleeTime else rng:NextNumber(Config.FishRepath[1], Config.FishRepath[2]))
end

local function equippedGun(player: Player)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("GunId")
	return id and GunData.ById[id]
end

local function bagCap(player: Player)
	return if player:GetAttribute("BigBag") then 150 else Config.InventoryCap
end
FishService.BagCap = bagCap

local function onShoot(player: Player, origin, direction)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or origin ~= origin or direction ~= direction then
		return
	end
	if direction.Magnitude < 0.5 then
		return
	end
	local gun = equippedGun(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not gun or not root or (origin - root.Position).Magnitude > 16 then
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
	local pos = FishPath.Position(f.Seg, hitTime)
	-- The creature must be within the gun's reach of where the spear was fired from.
	if (pos - shot.Origin).Magnitude > shot.Gun.Range + lengthOf(f) + Config.HitTolerance then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	if ChaseService.IsCarrying(player) then
		Remotes.Notify:FireClient(player, "Get out of the water to bank your catch first!", "error")
		return
	end
	if #data.Inventory >= bagCap(player) then
		Remotes.Notify:FireClient(player, "Your bag is full! Sell your catch first.", "error")
		return
	end
	shot.Hits += 1
	f.HP -= shot.Gun.Damage
	if f.HP <= 0 then
		fishes[f.Id] = nil
		Remotes.FishRemoved:FireAllClients(f.Id, player.UserId)
		ChaseService.StartCarry(player, { Id = f.Species, Kg = f.Kg, Size = f.Size, Mut = f.Mut }, f.Zone, pos)
		local zone = f.Zone
		task.delay(Config.FishRespawn, spawnFish, zone)
	else
		f.FleeUntil = t + Config.FleeTime
		repath(f, shot.Origin)
		Remotes.FishUpdated:FireAllClients(f.Id, f.Seg, f.HP, player.UserId)
	end
end

function FishService.Init()
	ChaseService = require(script.Parent.ChaseService)
	for _, zone in Zones.List do
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

	-- Creatures wander: every so often each one heads somewhere new.
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
