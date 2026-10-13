-- Bounties: every player always has one target creature. Banking one pays a big bonus and
-- rolls a new target, usually from the deepest zone you've caught something in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishData = require(Shared.FishData)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)
local DataService = require(script.Parent.DataService)

local BountyService = {}

local rng = Random.new()
local REWARD = 3 -- times the creature's normal value

function BountyService.Roll(data)
	local deepest = 1
	for id in data.Discovered do
		local f = FishData.ById[id]
		local z = f and Zones.ByName[f.Zone]
		if z then
			deepest = math.max(deepest, z.Index)
		end
	end
	-- mostly your deepest zone, sometimes the one above it
	local zone = Zones.List[math.max(1, deepest - (if rng:NextNumber() < 0.35 then 1 else 0))]
	local pool = {}
	for _, f in FishData.Fish do
		if f.Zone == zone.Name and FishData.RarityIndex[f.Rarity] <= FishData.RarityIndex.Rare and not (data.Bounty and data.Bounty.Id == f.Id) then
			table.insert(pool, f)
		end
	end
	if #pool == 0 then
		for _, f in FishData.Fish do
			if f.Zone == zone.Name then
				table.insert(pool, f)
			end
		end
	end
	local f = pool[rng:NextInteger(1, #pool)]
	local value = FishData.GetValue(f.Id, (f.MinKg + f.MaxKg) / 2, "Normal", nil)
	data.Bounty = { Id = f.Id, Reward = math.max(50, math.floor(value * REWARD / 10 + 0.5) * 10) }
end

-- Called when a catch is banked. Returns the reward if it was the bounty.
function BountyService.OnBank(player: Player, data, item): number?
	local bounty = data.Bounty
	if not bounty or bounty.Id ~= item.Id then
		return nil
	end
	data.Coins += bounty.Reward
	BountyService.Roll(data)
	Remotes.ChaseEvent:FireClient(player, "Bounty", { Id = item.Id, Reward = bounty.Reward })
	return bounty.Reward
end

function BountyService.Init()
	local function onPlayer(player: Player)
		local data = DataService.WaitFor(player)
		if data and not (data.Bounty and FishData.ById[data.Bounty.Id]) then
			BountyService.Roll(data)
			DataService.Changed(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
end

return BountyService
