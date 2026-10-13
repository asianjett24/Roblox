-- Robux store: game passes (permanent perks) and developer products (coins, repellent).
-- IDs live in Config.Store; anything with Id = 0 is a preview and can't be bought yet.
-- Pass perks are exposed as player attributes (VIP, DoubleCoins, TurboFins, BigBag).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local DataService = require(script.Parent.DataService)

local StoreService = {}

local passById, productById = {}, {}
for _, p in Config.Store.Passes do
	if p.Id ~= 0 then
		passById[p.Id] = p
	end
end
for _, p in Config.Store.Products do
	if p.Id ~= 0 then
		productById[p.Id] = p
	end
end

local function applyPass(player: Player, pass)
	player:SetAttribute(pass.Key, true)
	local char = player.Character
	if char and pass.Key == "TurboFins" then
		local DiverService = require(script.Parent.DiverService)
		DiverService.Refresh(player)
	end
end

local function checkPasses(player: Player)
	for _, pass in Config.Store.Passes do
		if pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				applyPass(player, pass)
			end
		end
	end
end

local function grant(player: Player, product): boolean
	local data = DataService.WaitFor(player)
	if not data then
		return false
	end
	if product.Coins then
		data.Coins += product.Coins
	end
	if product.Charges then
		data.Repellent += product.Charges
	end
	DataService.Changed(player)
	Remotes.Notify:FireClient(player, "Thanks for buying " .. product.Name .. "!", "success")
	return true
end

function StoreService.Init()
	Players.PlayerAdded:Connect(checkPasses)
	for _, p in Players:GetPlayers() do
		task.spawn(checkPasses, p)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = passById[passId]
		if purchased and pass then
			applyPass(player, pass)
			Remotes.Notify:FireClient(player, "You now own " .. pass.Name .. "!", "success")
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local product = productById[receipt.ProductId]
		if not player or not product then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if grant(player, product) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return StoreService
