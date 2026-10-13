-- Server-authoritative fishing: the server validates the cast, rolls the fish,
-- times the bite and checks the reel result so clients can't spawn fish.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local RodData = require(Shared.RodData)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local FishingService = {}

type Session = {
	Token: number,
	Fish: any,
	Kg: number,
	Zone: string,
	BiteAt: number,
	Bitten: boolean,
}

local sessions: { [Player]: Session } = {}
local nextToken = 0
local rng = Random.new()

local function isWater(result: RaycastResult)
	local part = result.Instance
	if result.Material == Enum.Material.Water then
		return true
	end
	if CollectionService:HasTag(part, Config.WaterTag) then
		return true
	end
	return table.find(Config.WaterNames, part.Name) ~= nil
end

local function equippedRod(player: Player)
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("RodId") then
		return tool
	end
	return nil
end

local function clear(player: Player)
	sessions[player] = nil
end


local function onCast(player: Player, target)
	if typeof(target) ~= "Vector3" or target ~= target then
		return false, "Bad cast"
	end
	if sessions[player] then
		return false, "Already fishing"
	end
	local data = DataService.Get(player)
	if not data or not equippedRod(player) then
		return false, "Equip your rod first"
	end
	if #data.Inventory >= Config.InventoryCap then
		return false, "Your bag is full! Sell some fish."
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "No character"
	end
	local rod = RodData.ById[data.Rod] or RodData.ById.Basic
	if (target - root.Position).Magnitude > rod.Range + 5 then
		return false, "Too far! Get closer to the water."
	end

	-- Re-check what's at that spot ourselves instead of trusting the client.
	local params = RaycastParams.new()
	local ignore = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	local result = workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -10, 0), params)
	if not result or not isWater(result) then
		return false, "You can only fish in water"
	end

	-- Standing on your own base's dock gets dock-only fish and your dock upgrades.
	local zone = if PlotService.IsOnOwnDock(player) then "Dock" else "Open"
	local luck, biteSpeed = rod.Luck, rod.BiteSpeed
	if zone == "Dock" then
		local bonus = data.DockLevel - 1
		luck *= 1 + Config.Dock.LuckPerLevel * bonus
		biteSpeed *= 1 + Config.Dock.BiteSpeedPerLevel * bonus
	end

	local fish, kg = FishData.Roll(zone, luck, rng)
	nextToken += 1
	local token = nextToken
	local delay = rng:NextNumber(Config.BiteDelayMin, Config.BiteDelayMax) / biteSpeed
	sessions[player] = {
		Token = token,
		Fish = fish,
		Kg = kg,
		Zone = zone,
		BiteAt = os.clock() + delay,
		Bitten = false,
	}

	task.delay(delay, function()
		local s = sessions[player]
		if not s or s.Token ~= token then
			return
		end
		s.Bitten = true
		local rarity = FishData.GetRarity(fish.Id)
		Remotes.Bite:FireClient(player, token, rarity.Difficulty)
		-- Drop abandoned bites.
		task.delay(Config.MaxReelTime, function()
			local s2 = sessions[player]
			if s2 and s2.Token == token then
				clear(player)
				Remotes.CatchResult:FireClient(player, false, { Reason = "It got away..." })
			end
		end)
	end)

	return true, token, zone
end

local function onReel(player: Player, token, success)
	local s = sessions[player]
	if not s or s.Token ~= token then
		return
	end
	clear(player)

	if not s.Bitten then
		-- Reeled in before anything bit: just a cancel.
		return
	end
	local elapsed = os.clock() - s.BiteAt
	if success ~= true or elapsed < Config.MinReelTime or elapsed > Config.MaxReelTime then
		Remotes.CatchResult:FireClient(player, false, { Reason = "The fish got away!" })
		return
	end

	local data = DataService.Get(player)
	if not data then
		return
	end
	if #data.Inventory >= Config.InventoryCap then
		Remotes.CatchResult:FireClient(player, false, { Reason = "Your bag is full!" })
		return
	end
	table.insert(data.Inventory, { Id = s.Fish.Id, Kg = s.Kg })
	data.Caught += 1
	local best = data.Discovered[s.Fish.Id]
	local isNew = best == nil
	local isRecord = best ~= nil and s.Kg > best
	if isNew or isRecord then
		data.Discovered[s.Fish.Id] = s.Kg
	end
	DataService.Changed(player)

	Remotes.CatchResult:FireClient(player, true, {
		Id = s.Fish.Id,
		Kg = s.Kg,
		Rarity = s.Fish.Rarity,
		Value = FishData.GetValue(s.Fish.Id, s.Kg),
		New = isNew,
		Record = isRecord,
	})

	if FishData.RarityIndex[s.Fish.Rarity] >= FishData.RarityIndex.Legendary then
		Remotes.Announce:FireAllClients(player.DisplayName, s.Fish.Id, s.Fish.Rarity, s.Kg)
	end
end

function FishingService.Init()
	Remotes.Cast.OnServerInvoke = onCast
	Remotes.Reel.OnServerEvent:Connect(onReel)
	Players.PlayerRemoving:Connect(clear)
end

return FishingService
