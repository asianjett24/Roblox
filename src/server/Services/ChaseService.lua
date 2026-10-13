-- The chase. Spear a creature and you carry it. The guardian of that zone wakes up and
-- hunts you: get your head out of the water to bank the catch. If it bites you first,
-- you drop the catch, take damage and get knocked away.
--
-- Guardians are simulated here and broadcast ~12 times a second; clients smooth them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)
local DataService = require(script.Parent.DataService)
local DiverService = require(script.Parent.DiverService)

local ChaseService = {}

local carrying: { [Player]: any } = {} -- [player] = { Item, Zone, Since }
local guardians = {} -- one per zone

local function rootOf(player: Player)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
end

-- Keeps a point inside the pit's water (guardians can't leave it or go through walls).
local function clampToWater(p: Vector3, radius: number): Vector3
	local y = math.clamp(p.Y, Zones.List[#Zones.List].Bottom + radius, Zones.WaterLevel - 2.5)
	local z = Zones.At(y) or Zones.List[1]
	local half = z.Half - radius
	return Vector3.new(math.clamp(p.X, -half, half), y, math.clamp(p.Z, -half, half))
end

function ChaseService.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

local function setCarryAttribute(player: Player, item)
	if item then
		player:SetAttribute("Carrying", string.format("%s|%s|%s", item.Id, item.Size or "Normal", item.Mut or ""))
	else
		player:SetAttribute("Carrying", nil)
	end
end

local function pickTarget(g)
	local best, bestDist = nil, math.huge
	for player, c in carrying do
		if c.Zone == g.Zone and not c.Repelled then
			local root = rootOf(player)
			if root then
				local d = (root.Position - g.Pos).Magnitude
				if d < bestDist then
					best, bestDist = player, d
				end
			end
		end
	end
	return best
end

local function setState(g, state, target)
	g.State = state
	g.Target = target
	g.StateTime = os.clock()
end

function ChaseService.StartCarry(player: Player, item, zone, at: Vector3)
	local data = DataService.Get(player)
	local repelled = false
	if data and data.Repellent > 0 then
		data.Repellent -= 1
		repelled = true
		DataService.Changed(player)
	end
	carrying[player] = { Item = item, Zone = zone, Since = os.clock(), Repelled = repelled }
	setCarryAttribute(player, item)
	local g = guardians[zone.Index]
	local fullName = FishData.FullName(item.Id, item.Size, item.Mut)
	if repelled then
		Remotes.ChaseEvent:FireClient(player, "Grabbed", { Item = item, Guardian = g.Spec.Name, Repelled = true })
		Remotes.Notify:FireClient(player, "Shark Repellent used! The " .. g.Spec.Name .. " sleeps on.", "success")
		return
	end
	Remotes.ChaseEvent:FireClient(player, "Grabbed", { Item = item, Guardian = g.Spec.Name, Zone = zone.Name })
	if g.State == "Sleep" or g.State == "Return" then
		setState(g, "Wake", player)
		Remotes.ChaseEvent:FireAllClients("Wake", { Zone = zone.Index, Target = player.UserId, Guardian = g.Spec.Name, Fish = fullName })
	end
end

local function dropCarry(player: Player)
	carrying[player] = nil
	setCarryAttribute(player, nil)
end

local function bank(player: Player)
	local c = carrying[player]
	if not c then
		return
	end
	dropCarry(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local item = c.Item
	table.insert(data.Inventory, { Id = item.Id, Kg = item.Kg, Size = item.Size, Mut = item.Mut })
	data.Caught += 1
	if not c.Repelled then
		data.Escapes += 1
	end
	local entry = data.Discovered[item.Id]
	local isNew = entry == nil
	if not entry then
		entry = { Best = 0, Count = 0, Sizes = {}, Muts = {} }
		data.Discovered[item.Id] = entry
	end
	local isRecord = not isNew and item.Kg > entry.Best
	entry.Best = math.max(entry.Best, item.Kg)
	entry.Count += 1
	entry.Sizes[item.Size or "Normal"] = true
	if item.Mut then
		entry.Muts[item.Mut] = true
	end
	-- Zone completion reward: discover every creature in a zone
	local zoneName = FishData.ById[item.Id].Zone
	if not data.ZoneRewards[zoneName] then
		local all = true
		for _, f in FishData.Fish do
			if f.Zone == zoneName and not data.Discovered[f.Id] then
				all = false
			end
		end
		if all then
			data.ZoneRewards[zoneName] = true
			local reward = 1000 * (Zones.ByName[zoneName].Index ^ 2)
			data.Coins += reward
			Remotes.Notify:FireClient(player, string.format("%s complete! +%d coins", Zones.ByName[zoneName].Display, reward), "success")
		end
	end
	DataService.Changed(player)
	local value = FishData.GetValue(item.Id, item.Kg, item.Size, item.Mut)
	Remotes.CatchResult:FireClient(player, true, {
		Id = item.Id, Kg = item.Kg, Size = item.Size, Mut = item.Mut,
		Rarity = FishData.ById[item.Id].Rarity, Value = value, New = isNew, Record = isRecord,
	})
	Remotes.ChaseEvent:FireAllClients("Escaped", { Player = player.UserId, Zone = c.Zone.Index })
	local rarity = FishData.RarityIndex[FishData.ById[item.Id].Rarity]
	if rarity >= FishData.RarityIndex.Legendary or item.Mut or item.Size == "Colossal" then
		Remotes.Announce:FireAllClients(player.DisplayName, FishData.FullName(item.Id, item.Size, item.Mut), FishData.ById[item.Id].Rarity, item.Kg)
	end
end

local function bite(g, player: Player, root: BasePart)
	local c = carrying[player]
	dropCarry(player)
	local data = DataService.Get(player)
	if data then
		data.Bitten += 1
		DataService.Changed(player)
	end
	local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(g.Spec.Damage)
	end
	local away = (root.Position - g.Pos)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 1, 0)
	Remotes.ChaseEvent:FireAllClients("Bitten", {
		Player = player.UserId, Zone = g.Zone.Index, Guardian = g.Spec.Name, Push = away * Config.Chase.Knockback,
		Fish = c and FishData.FullName(c.Item.Id, c.Item.Size, c.Item.Mut),
	})
	Remotes.CatchResult:FireClient(player, false, { Reason = string.format("The %s got you! Your catch swam away.", g.Spec.Name) })
end

local function step(dt: number)
	-- Banking: carriers whose heads are out of the water keep their catch
	for player, _ in carrying do
		local char = player.Character
		local head = char and char:FindFirstChild("Head")
		local root = rootOf(player)
		if not root or not head then
			dropCarry(player)
		elseif not DiverService.IsUnderwater(head.Position) then
			bank(player)
		end
	end

	for _, g in guardians do
		local spec = g.Spec
		if g.State == "Wake" then
			-- rises out of its lair, roaring
			g.Vel = g.Vel:Lerp(Vector3.new(0, 4, 0), math.min(1, dt * 3))
			g.Pos = clampToWater(g.Pos + g.Vel * dt, spec.L * 0.25)
			if os.clock() - g.StateTime >= spec.Wake then
				setState(g, "Chase", pickTarget(g))
			end
		elseif g.State == "Chase" then
			local target = g.Target
			if not target or not carrying[target] or carrying[target].Zone ~= g.Zone then
				target = pickTarget(g)
				g.Target = target
			end
			local root = target and rootOf(target)
			if not root then
				setState(g, "Return", nil)
			else
				-- Aim a little ahead of the diver
				local aim = root.Position + root.AssemblyLinearVelocity * 0.25
				local desired = aim - g.Pos
				local dir = if desired.Magnitude > 0.1 then desired.Unit else g.Dir
				g.Dir = g.Dir:Lerp(dir, math.min(1, dt * Config.Chase.TurnRate)).Unit
				g.Vel = g.Dir * spec.Speed
				g.Pos = clampToWater(g.Pos + g.Vel * dt, spec.L * 0.2)
				local mouth = g.Pos + g.Dir * spec.L * 0.45
				if (mouth - root.Position).Magnitude <= spec.Bite or (g.Pos - root.Position).Magnitude <= spec.Bite * 0.8 then
					bite(g, target, root)
					local nextTarget = pickTarget(g)
					if nextTarget then
						setState(g, "Chase", nextTarget)
					else
						setState(g, "Return", nil)
					end
				end
			end
		elseif g.State == "Return" then
			local next = pickTarget(g)
			if next then
				setState(g, "Chase", next)
			else
				local home = g.Zone.Lair + Vector3.new(0, spec.L * 0.15, 0)
				local delta = home - g.Pos
				if delta.Magnitude < 2 then
					g.Pos = home
					g.Vel = Vector3.zero
					setState(g, "Sleep", nil)
				else
					local dir = delta.Unit
					g.Dir = g.Dir:Lerp(dir, math.min(1, dt * 2)).Unit
					g.Vel = g.Dir * spec.Speed * Config.Chase.ReturnSpeed
					g.Pos = clampToWater(g.Pos + g.Vel * dt, spec.L * 0.2)
				end
			end
		else -- Sleep: drift slowly around the lair
			local t = os.clock() * 0.2 + g.Zone.Index
			local home = g.Zone.Lair + Vector3.new(math.cos(t) * 3, spec.L * 0.15 + math.sin(t * 1.7), math.sin(t) * 3)
			g.Vel = (home - g.Pos) * 0.5
			g.Pos += g.Vel * dt
			if g.Vel.Magnitude > 0.05 then
				g.Dir = g.Dir:Lerp(g.Vel.Unit, math.min(1, dt)).Unit
			end
		end
	end
end

local function broadcast()
	local list = {}
	for i, g in guardians do
		list[i] = { g.Pos, g.Dir, g.State, if g.Target then g.Target.UserId else 0 }
	end
	Remotes.GuardianState:FireAllClients(list, workspace:GetServerTimeNow())
end

function ChaseService.Init()
	for i, zone in Zones.List do
		local home = zone.Lair + Vector3.new(0, zone.Guardian.L * 0.15, 0)
		guardians[i] = {
			Zone = zone, Spec = zone.Guardian, Pos = home, Vel = Vector3.zero,
			Dir = Vector3.new(1, 0, 0), State = "Sleep", StateTime = os.clock(),
		}
	end
	Players.PlayerRemoving:Connect(function(player)
		carrying[player] = nil
	end)
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			if carrying[player] then
				dropCarry(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		step(math.min(dt, 0.1))
		acc += dt
		if acc >= 1 / 12 then
			acc = 0
			broadcast()
		end
	end)
end

return ChaseService
