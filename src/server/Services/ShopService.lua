-- Selling fish, buying/equipping rods, upgrading your pond.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local RodData = require(Shared.RodData)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local RodService = require(script.Parent.RodService)

local ShopService = {}

local function nearMerchant(player: Player)
	local merchants = CollectionService:GetTagged(Config.MerchantTag)
	if Config.SellAnywhere or #merchants == 0 then
		return true
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, m in merchants do
		if m:IsA("BasePart") and (m.Position - root.Position).Magnitude < 20 then
			return true
		end
	end
	return false
end

function ShopService.SellAll(player: Player)
	local data = DataService.Get(player)
	if not data then
		return false, "Data not loaded"
	end
	if not nearMerchant(player) then
		return false, "Go to the merchant to sell!"
	end
	local total = 0
	for _, item in data.Inventory do
		total += FishData.GetValue(item.Id, item.Kg)
	end
	if total == 0 then
		return false, "Nothing to sell"
	end
	data.Coins += total
	table.clear(data.Inventory)
	DataService.Changed(player)
	return true, "Sold for " .. Format.Number(total) .. " coins!"
end

function ShopService.Init()
	Remotes.SellAll.OnServerInvoke = ShopService.SellAll

	Remotes.BuyRod.OnServerInvoke = function(player, rodId)
		local data = DataService.Get(player)
		local rod = type(rodId) == "string" and RodData.ById[rodId]
		if not data or not rod then
			return false, "Invalid rod"
		end
		if data.OwnedRods[rod.Id] then
			return false, "Already owned"
		end
		if data.Coins < rod.Price then
			return false, "Not enough coins"
		end
		data.Coins -= rod.Price
		data.OwnedRods[rod.Id] = true
		data.Rod = rod.Id
		DataService.Changed(player)
		RodService.Give(player)
		return true, "Bought the " .. rod.Name .. "!"
	end

	Remotes.EquipRod.OnServerInvoke = function(player, rodId)
		local data = DataService.Get(player)
		if not data or type(rodId) ~= "string" or not data.OwnedRods[rodId] then
			return false, "You don't own that rod"
		end
		data.Rod = rodId
		DataService.Changed(player)
		RodService.Give(player)
		return true, "Equipped " .. RodData.ById[rodId].Name
	end

	Remotes.UpgradePond.OnServerInvoke = function(player)
		local data = DataService.Get(player)
		if not data then
			return false, "Data not loaded"
		end
		if data.PondLevel >= Config.Pond.MaxLevel then
			return false, "Pond is max level"
		end
		local cost = Config.Pond.Costs[data.PondLevel]
		if data.Coins < cost then
			return false, "Not enough coins"
		end
		data.Coins -= cost
		data.PondLevel += 1
		DataService.Changed(player)
		return true, "Pond upgraded to level " .. data.PondLevel .. "!"
	end

	-- Merchant prompts on any part tagged "Merchant".
	local function setupMerchant(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("SellPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "SellPrompt"
		prompt.ActionText = "Sell All Fish"
		prompt.ObjectText = "Merchant"
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			local ok, msg = ShopService.SellAll(player)
			Remotes.Notify:FireClient(player, msg, if ok then "success" else "error")
		end)
	end
	for _, part in CollectionService:GetTagged(Config.MerchantTag) do
		setupMerchant(part)
	end
	CollectionService:GetInstanceAddedSignal(Config.MerchantTag):Connect(setupMerchant)
end

return ShopService
