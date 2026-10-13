-- Builds the fishing rod Tool for the player's equipped rod.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RodData = require(ReplicatedStorage.Shared.RodData)
local DataService = require(script.Parent.DataService)

local RodService = {}

local function buildTool(rod)
	local tool = Instance.new("Tool")
	tool.Name = rod.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click water to cast"
	tool:SetAttribute("RodId", rod.Id)
	-- Hold the rod angled up and forward.
	tool.Grip = CFrame.new(0, -2, 0) * CFrame.Angles(math.rad(-20), 0, 0)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.25, 6, 0.25)
	handle.Color = rod.Color
	handle.Material = if rod.Id == "Golden" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.35, 1.2, 0.35)
	grip.Color = Color3.fromRGB(40, 30, 25)
	grip.CanCollide = false
	grip.Massless = true
	grip.CFrame = handle.CFrame * CFrame.new(0, -2.2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = grip
	weld.Parent = grip
	grip.Parent = tool

	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 3, 0)
	tip.Parent = handle

	return tool
end

function RodService.Give(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local rod = RodData.ById[data.Rod] or RodData.ById.Basic
	for _, container in { player:FindFirstChild("Backpack"), player.Character } do
		if container then
			for _, item in container:GetChildren() do
				if item:IsA("Tool") and item:GetAttribute("RodId") then
					item:Destroy()
				end
			end
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		buildTool(rod).Parent = backpack
	end
end

function RodService.Init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			DataService.WaitFor(player)
			player:WaitForChild("Backpack")
			RodService.Give(player)
		end)
		if player.Character then
			task.spawn(function()
				DataService.WaitFor(player)
				RodService.Give(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
end

return RodService
