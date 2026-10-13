-- Diving: air drains while your head is underwater and refills at the surface (drowning
-- hurts), and your swim speed comes from your Flippers level. The client reads the
-- Oxygen / OxygenMax attributes on the player.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)
local DataService = require(script.Parent.DataService)

local DiverService = {}

local TICK = 0.2

local function level(data, key, max)
	return math.clamp(if data then data[key] else 1, 1, max)
end

function DiverService.MaxAir(player: Player): number
	local data = DataService.Get(player)
	return Config.Tank.Air[level(data, "TankLevel", Config.Tank.MaxLevel)]
end

function DiverService.SwimSpeed(player: Player): number
	local data = DataService.Get(player)
	local speed = Config.Fins.Speed[level(data, "FinLevel", Config.Fins.MaxLevel)]
	if player:GetAttribute("TurboFins") then
		speed *= 1.15
	end
	return speed
end

function DiverService.IsUnderwater(position: Vector3): boolean
	return Zones.InWater(position + Vector3.new(0, 0.4, 0))
end

-- Re-applies swim speed (call after an upgrade)
function DiverService.Refresh(player: Player)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = DiverService.SwimSpeed(player)
	end
	player:SetAttribute("OxygenMax", DiverService.MaxAir(player))
end

function DiverService.Init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(char)
			DataService.WaitFor(player)
			local m = DiverService.MaxAir(player)
			player:SetAttribute("OxygenMax", m)
			player:SetAttribute("Oxygen", m)
			local humanoid = char:WaitForChild("Humanoid", 10)
			if humanoid then
				humanoid.WalkSpeed = DiverService.SwimSpeed(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end
	DataService.OnChanged:Connect(function(player)
		DiverService.Refresh(player)
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local head = char and char:FindFirstChild("Head")
				local humanoid = char and char:FindFirstChildOfClass("Humanoid")
				if head and humanoid and humanoid.Health > 0 then
					local m = DiverService.MaxAir(player)
					local air = math.min(player:GetAttribute("Oxygen") or m, m)
					if DiverService.IsUnderwater(head.Position) then
						air = math.max(0, air - TICK)
						if air <= 0 then
							humanoid:TakeDamage(Config.DrownDamage * TICK)
						end
					else
						air = math.min(m, air + Config.AirRefill * TICK)
					end
					player:SetAttribute("OxygenMax", m)
					player:SetAttribute("Oxygen", math.floor(air * 10 + 0.5) / 10)
				end
			end
		end
	end)
end

return DiverService
