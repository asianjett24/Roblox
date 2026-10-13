-- Air supply. Drains while your head is underwater, refills at the surface,
-- and hurts you when it runs out. The client reads the Oxygen / OxygenMax attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local OxygenService = {}

local TICK = 0.2

local function maxAir(player: Player): number
	local data = DataService.Get(player)
	local level = if data then data.TankLevel else 1
	return Config.Tank.Air[math.clamp(level, 1, #Config.Tank.Air)]
end

function OxygenService.IsUnderwater(position: Vector3): boolean
	return position.Y < Config.WaterLevel - 0.4 and math.abs(position.X) < Config.PondHalf and math.abs(position.Z) < Config.PondHalf
end

function OxygenService.Init()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			local m = maxAir(player)
			player:SetAttribute("OxygenMax", m)
			player:SetAttribute("Oxygen", m)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end

	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local head = char and char:FindFirstChild("Head")
				local humanoid = char and char:FindFirstChildOfClass("Humanoid")
				if head and humanoid and humanoid.Health > 0 then
					local m = maxAir(player)
					local air = math.min(player:GetAttribute("Oxygen") or m, m)
					if OxygenService.IsUnderwater(head.Position) then
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

return OxygenService
