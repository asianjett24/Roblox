-- What diving looks like: a blue tint and fog that get darker with depth, bubbles from your
-- head, a splash when you enter, and the air + depth meter.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FishPath = require(Shared.FishPath)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local UnderwaterController = {}

local Kit
local tint, blur
local atmosphere, surfaceAtmo
local wasUnder = false
local hud = {}
local bubbles

local function underwater(pos: Vector3)
	return pos.Y < Config.WaterLevel - 0.2 and math.abs(pos.X) < Config.PondHalf and math.abs(pos.Z) < Config.PondHalf
end

local function buildHud(gui)
	local C, F, make, text = Kit.Color, Kit.Font, Kit.make, Kit.text
	local holder = make("Frame", {
		Size = UDim2.fromOffset(360, 74),
		Position = UDim2.new(0.5, 0, 1, -104),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Kit.shadow(holder, 18, 3, 0)
	local card = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08, ZIndex = 1, Parent = holder }, {
		Kit.corner(18),
		Kit.stroke(Color3.new(1, 1, 1), 1, 0.88),
	})
	-- Depth block
	local depthBox = make("Frame", { Size = UDim2.fromOffset(96, 54), Position = UDim2.fromOffset(10, 10), BackgroundColor3 = C.PanelLo, Parent = card }, { Kit.corner(12) })
	Kit.icon("depth", 16, C.Accent, { Position = UDim2.fromOffset(8, 8), Parent = depthBox })
	local depth = text("0m", 22, F.Black, C.Text, { Position = UDim2.fromOffset(28, 3), Parent = depthBox })
	local zone = text("", 11, F.Bold, C.Sub, { Position = UDim2.fromOffset(9, 33), Size = UDim2.new(1, -14, 0, 14), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = depthBox })
	-- Air block
	Kit.icon("bubbles", 18, C.Accent, { Position = UDim2.fromOffset(118, 14), Parent = card })
	text("AIR", 13, F.Black, C.Sub, { Position = UDim2.fromOffset(142, 14), Parent = card })
	local seconds = text("", 15, F.Black, C.Text, { Position = UDim2.new(1, -16, 0, 12), AnchorPoint = Vector2.new(1, 0), Parent = card })
	local track = make("Frame", { Size = UDim2.new(1, -134, 0, 14), Position = UDim2.fromOffset(118, 42), BackgroundColor3 = C.PanelLo, Parent = card }, { Kit.round() })
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track }, {
		Kit.round(),
		make("UIGradient", { Name = "G", Color = ColorSequence.new(C.Accent, C.AccentDeep), Rotation = 0 }),
	})
	hud = { Holder = holder, Depth = depth, Zone = zone, Seconds = seconds, Fill = fill, Track = track }
end

local function setUnder(under: boolean)
	local goalTint = if under then { TintColor = Color3.fromRGB(150, 210, 255), Saturation = -0.05, Contrast = 0.08 } else { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0 }
	Kit.tween(tint, 0.35, goalTint)
	Kit.tween(blur, 0.35, { Size = if under then 3 else 0 })
	if atmosphere and surfaceAtmo then
		if under then
			Kit.tween(atmosphere, 0.35, { Density = 0.5, Haze = 1.5, Color = Color3.fromRGB(70, 150, 210), Decay = Color3.fromRGB(20, 70, 130) })
		else
			Kit.tween(atmosphere, 0.5, surfaceAtmo)
		end
	end
end

local function findAtmosphere()
	local found = Lighting:FindFirstChildOfClass("Atmosphere")
	if found and found ~= atmosphere then
		atmosphere = found
		surfaceAtmo = { Density = found.Density, Haze = found.Haze, Color = found.Color, Decay = found.Decay }
	end
end

local function step()
	if not atmosphere or not atmosphere.Parent then
		findAtmosphere()
	end
	local camPos = camera.CFrame.Position
	local under = underwater(camPos)
	if under ~= wasUnder then
		wasUnder = under
		setUnder(under)
	end
	if under then
		local k = math.clamp((Config.WaterLevel - camPos.Y) / 300, 0, 1)
		tint.Brightness = -0.03 - 0.28 * k
		tint.TintColor = Color3.fromRGB(150, 210, 255):Lerp(Color3.fromRGB(50, 90, 170), k)
		if atmosphere then
			atmosphere.Density = 0.45 + 0.3 * k
			atmosphere.Color = Color3.fromRGB(70, 150, 210):Lerp(Color3.fromRGB(8, 22, 52), k)
		end
	end

	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	local headUnder = head ~= nil and underwater(head.Position)
	if bubbles then
		bubbles.Enabled = headUnder
	end

	local air = player:GetAttribute("Oxygen")
	local maxAir = player:GetAttribute("OxygenMax")
	local show = headUnder or (air and maxAir and air < maxAir - 0.05)
	hud.Holder.Visible = show and true or false
	if show and head and air and maxAir then
		local depthStuds = math.max(0, Config.WaterLevel - head.Position.Y)
		hud.Depth.Text = string.format("%dm", math.floor(depthStuds * 2 + 0.5))
		local zone = FishPath.ZoneAt(head.Position.Y)
		hud.Zone.Text = if zone then string.upper(zone.Display) else "SURFACE"
		local frac = math.clamp(air / math.max(maxAir, 1), 0, 1)
		hud.Fill.Size = UDim2.fromScale(frac, 1)
		local C = Kit.Color
		hud.Fill.G.Color = if frac < 0.25 then ColorSequence.new(C.Danger, C.DangerDeep) else ColorSequence.new(C.Accent, C.AccentDeep)
		hud.Seconds.Text = string.format("%ds", math.ceil(air))
		hud.Seconds.TextColor3 = if frac < 0.25 then C.Danger else C.Text
	end
end

local function onCharacter(char: Model)
	local head = char:WaitForChild("Head", 10)
	if not head then
		return
	end
	bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	bubbles.LightEmission = 0.4
	bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.28) })
	bubbles.Lifetime = NumberRange.new(1.2, 2)
	bubbles.Rate = 6
	bubbles.Speed = NumberRange.new(2, 4)
	bubbles.SpreadAngle = Vector2.new(25, 25)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Enabled = false
	bubbles.Parent = head
end

function UnderwaterController.Init(uiController)
	Kit = uiController.Kit
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "UnderwaterTint"
	tint.Parent = camera
	blur = Instance.new("BlurEffect")
	blur.Name = "UnderwaterBlur"
	blur.Size = 0
	blur.Parent = camera
	findAtmosphere()
	buildHud(uiController.GetGui())
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService.RenderStepped:Connect(step)
end

return UnderwaterController
