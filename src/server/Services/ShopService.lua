-- Selling fish, buying/equipping spearguns, upgrading your air tank.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local GunData = require(Shared.GunData)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local DataService = require(script.Parent.DataService)
local GearService = require(script.Parent.GearService)

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

	Remotes.BuyGun.OnServerInvoke = function(player, gunId)
		local data = DataService.Get(player)
		local gun = type(gunId) == "string" and GunData.ById[gunId]
		if not data or not gun then
			return false, "Invalid speargun"
		end
		if data.OwnedGuns[gun.Id] then
			return false, "Already owned"
		end
		if data.Coins < gun.Price then
			return false, "Not enough coins"
		end
		data.Coins -= gun.Price
		data.OwnedGuns[gun.Id] = true
		data.Gun = gun.Id
		DataService.Changed(player)
		GearService.Give(player)
		return true, "Bought the " .. gun.Name .. "!"
	end

	Remotes.EquipGun.OnServerInvoke = function(player, gunId)
		local data = DataService.Get(player)
		if not data or type(gunId) ~= "string" or not data.OwnedGuns[gunId] or not GunData.ById[gunId] then
			return false, "You don't own that speargun"
		end
		data.Gun = gunId
		DataService.Changed(player)
		GearService.Give(player)
		return true, "Equipped " .. GunData.ById[gunId].Name
	end

	Remotes.UpgradeTank.OnServerInvoke = function(player)
		local data = DataService.Get(player)
		if not data then
			return false, "Data not loaded"
		end
		if data.TankLevel >= Config.Tank.MaxLevel then
			return false, "Your air tank is maxed out"
		end
		local cost = Config.Tank.Costs[data.TankLevel]
		if data.Coins < cost then
			return false, "Not enough coins"
		end
		data.Coins -= cost
		data.TankLevel += 1
		DataService.Changed(player)
		return true, string.format("Air tank upgraded! %ds of air", Config.Tank.Air[data.TankLevel])
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

	-- Gear shop prompts open the Shop menu.
	local function setupGearShop(part: Instance)
		if not part:IsA("BasePart") or part:FindFirstChild("ShopPrompt") then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShopPrompt"
		prompt.ActionText = "Browse Spearguns"
		prompt.ObjectText = "Gear Shop"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 14
		prompt.Parent = part
		prompt.Triggered:Connect(function(player)
			Remotes.OpenPanel:FireClient(player, "Shop")
		end)
	end
	for _, part in CollectionService:GetTagged(Config.GearShopTag) do
		setupGearShop(part)
	end
	CollectionService:GetInstanceAddedSignal(Config.GearShopTag):Connect(setupGearShop)
end

return ShopService
