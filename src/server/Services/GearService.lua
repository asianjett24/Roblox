-- Gives each player a speargun Tool for the gun they have equipped.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunData = require(ReplicatedStorage.Shared.GunData)
local GunModels = require(ReplicatedStorage.Shared.GunModels)
local DataService = require(script.Parent.DataService)

local GearService = {}

function GearService.Give(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local gun = GunData.ById[data.Gun] or GunData.ById.Wooden
	for _, container in { player:FindFirstChild("Backpack"), player.Character } do
		if container then
			for _, item in container:GetChildren() do
				if item:IsA("Tool") and item:GetAttribute("GunId") then
					item:Destroy()
				end
			end
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		GunModels.Build(gun, true).Parent = backpack
	end
end

function GearService.Init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			DataService.WaitFor(player)
			player:WaitForChild("Backpack")
			GearService.Give(player)
		end)
		if player.Character then
			task.spawn(function()
				DataService.WaitFor(player)
				GearService.Give(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
end

return GearService
