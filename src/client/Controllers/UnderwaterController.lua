-- What diving looks and feels like: each zone has its own fog colour that gets darker with
-- depth, a headlamp switches on in the deep, a banner announces each new zone, and the
-- dive HUD shows air, depth, the zone's guardian and the dash charge.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Zones)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local UnderwaterController = {}

local UI, Kit, Dive, Guardians, Audio
local tint, blur
local atmosphere, surfaceAtmo
local wasUnder = false
local lastZone = nil
local hud = {}
local lamp
local lowAirTick = 0
local lastHeadY = nil

local function camUnder(pos: Vector3)
	return Zones.InWater(pos + Vector3.new(0, 0.2, 0))
end

-- HUD -----------------------------------------------------------------------------------------------
local function pill(parent, size, pos, anchor)
	local make = Kit.make
	local holder = make("Frame", { Size = size, Position = pos, AnchorPoint = anchor, BackgroundTransparency = 1, Parent = parent })
	make("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = Kit.Color.Ink, BackgroundTransparency = 0.3, Parent = holder }, { Kit.corner(18) })
	local face = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = holder }, {
		Kit.corner(18),
		make("UIGradient", { Color = ColorSequence.new(Kit.Swatch.navy[1], Kit.Swatch.navy[2]), Rotation = 90 }),
		Kit.outline(3),
	})
	return holder, face
end

local function buildHud(gui)
	local C, F, make, text = Kit.Color, Kit.Font, Kit.make, Kit.text
	local root = make("Frame", { Size = UDim2.fromOffset(560, 96), Position = UDim2.new(0.5, 0, 1, -104), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	local scale = make("UIScale", { Parent = root })

	-- depth + zone (left)
	local _, depthFace = pill(root, UDim2.fromOffset(150, 84), UDim2.fromOffset(0, 0))
	Kit.icon("depth", 26, C.Accent, { Position = UDim2.fromOffset(10, 10), Parent = depthFace })
	local depth = text("0m", 30, F.Title, C.Text, { Position = UDim2.fromOffset(40, 4), Parent = depthFace })
	local zone = text("", 14, F.Title, C.Sub, { Size = UDim2.new(1, -18, 0, 18), Position = UDim2.fromOffset(10, 46), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = depthFace })
	local guard = text("", 13, F.Title, C.Text, { Size = UDim2.new(1, -18, 0, 16), Position = UDim2.fromOffset(10, 62), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = depthFace })

	-- air (middle)
	local airHolder, airFace = pill(root, UDim2.fromOffset(300, 84), UDim2.fromOffset(162, 0))
	Kit.icon("bubbles", 34, C.Accent, { Position = UDim2.fromOffset(10, 8), Parent = airFace })
	local airLabel = text("AIR", 22, F.Title, C.Text, { Position = UDim2.fromOffset(52, 8), Parent = airFace })
	local seconds = text("", 22, F.Title, C.Text, { Position = UDim2.new(1, -14, 0, 8), AnchorPoint = Vector2.new(1, 0), Parent = airFace })
	local track = make("Frame", { Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 48), BackgroundColor3 = C.WellLo, ClipsDescendants = true, Parent = airFace }, { Kit.round(), Kit.outline(3) })
	local fill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track }, {
		Kit.round(),
		make("UIGradient", { Name = "G", Color = ColorSequence.new(Color3.fromRGB(120, 225, 255), Color3.fromRGB(40, 140, 245)), Rotation = 90 }),
	})
	make("Frame", { Size = UDim2.new(1, -8, 0.35, 0), Position = UDim2.fromOffset(4, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, Parent = fill }, { Kit.round() })
	local airScale = make("UIScale", { Parent = airHolder })

	-- dash (right)
	local _, dashFace = pill(root, UDim2.fromOffset(86, 84), UDim2.fromOffset(474, 0))
	local dashFill = make("Frame", { Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Kit.Swatch.green[2], BackgroundTransparency = 0.25, Parent = dashFace }, { Kit.corner(18) })
	Kit.icon("fin", 40, C.Text, { Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 2, Parent = dashFace })
	local dashLabel = text("SHIFT", 15, F.Title, C.Text, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -24), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 2, Parent = dashFace })

	-- zone banner
	local banner = make("Frame", { Size = UDim2.fromOffset(520, 92), Position = UDim2.new(0.5, 0, 0, -200), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Visible = false, Parent = gui })
	make("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.3, Parent = banner }, { Kit.corner(20) })
	local bFace = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = banner }, {
		Kit.corner(20),
		make("UIGradient", { Name = "G", Rotation = 90 }),
		Kit.outline(4),
	})
	Kit.checker(bFace, 18, 0.9, nil, 520, 92)
	local bTitle = text("", 36, F.Title, C.Text, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 8), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 2, Parent = bFace })
	local bSub = text("", 17, F.Title, C.Text, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 56), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 2, Parent = bFace })

	hud = {
		Root = root, Scale = scale, Depth = depth, Zone = zone, Guard = guard, Seconds = seconds, Fill = fill, AirScale = airScale,
		DashFill = dashFill, DashLabel = dashLabel, AirLabel = airLabel, Banner = banner, BannerGrad = bFace.G, BannerTitle = bTitle, BannerSub = bSub,
	}
end

local bannerToken = 0
local function showZoneBanner(z)
	bannerToken += 1
	local token = bannerToken
	hud.BannerTitle.Text = string.upper(z.Display)
	hud.BannerSub.Text = string.format("%dm  -  Guardian: %s", math.floor(Zones.Depth(z.Top)), z.Guardian.Name)
	hud.BannerGrad.Color = ColorSequence.new(z.Fog:Lerp(Color3.new(1, 1, 1), 0.15), z.FogDeep)
	hud.Banner.Position = UDim2.new(0.5, 0, 0, -200)
	hud.Banner.Visible = true
	TweenService:Create(hud.Banner, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 186) }):Play()
	task.delay(2.6, function()
		if token == bannerToken then
			UnderwaterController.HideBanner()
		end
	end)
end

function UnderwaterController.HideBanner()
	bannerToken += 1
	local token = bannerToken
	if not hud.Banner.Visible then
		return
	end
	local tw = TweenService:Create(hud.Banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -200) })
	tw:Play()
	tw.Completed:Connect(function()
		if token == bannerToken then
			hud.Banner.Visible = false
		end
	end)
end

-- Look ----------------------------------------------------------------------------------------------
local function findAtmosphere()
	local found = Lighting:FindFirstChildOfClass("Atmosphere")
	if found and found ~= atmosphere then
		atmosphere = found
		surfaceAtmo = { Density = found.Density, Haze = found.Haze, Color = found.Color, Decay = found.Decay, Glare = found.Glare }
	end
end

local function setUnder(under: boolean)
	if under then
		Kit.tween(blur, 0.3, { Size = 2 })
		if atmosphere then
			Kit.tween(atmosphere, 0.3, { Haze = 2, Glare = 0 })
		end
	else
		Kit.tween(tint, 0.4, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0, Brightness = 0 })
		Kit.tween(blur, 0.4, { Size = 0 })
		if atmosphere and surfaceAtmo then
			Kit.tween(atmosphere, 0.5, surfaceAtmo)
		end
	end
end

local function splash(pos: Vector3)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = pos
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(225, 245, 255))
	e.LightEmission = 0.3
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.4, 0.8)
	e.Speed = NumberRange.new(10, 18)
	e.SpreadAngle = Vector2.new(35, 35)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -50, 0)
	e.Rate = 0
	e.Parent = holder
	e:Emit(30)
	task.delay(1.2, function()
		holder:Destroy()
	end)
end

local function step(dt: number)
	if not atmosphere or not atmosphere.Parent then
		findAtmosphere()
	end
	local camPos = camera.CFrame.Position
	local under = camUnder(camPos)
	if under ~= wasUnder then
		wasUnder = under
		setUnder(under)
	end
	local zone = if under then Zones.At(camPos.Y) else nil
	if under and zone then
		-- fog colour: the zone's colour at its top, its deep colour at its bottom
		local k = math.clamp((zone.Top - camPos.Y) / (zone.Top - zone.Bottom), 0, 1)
		local fog = zone.Fog:Lerp(zone.FogDeep, k)
		local deep = math.clamp(Zones.Depth(camPos.Y) / 1040, 0, 1)
		tint.TintColor = fog:Lerp(Color3.new(1, 1, 1), 0.55 - deep * 0.2)
		tint.Brightness = -0.02 - deep * 0.12
		tint.Contrast = 0.06 + deep * 0.08
		tint.Saturation = 0.05
		if atmosphere then
			atmosphere.Density = 0.42 + deep * 0.28
			atmosphere.Color = fog
			atmosphere.Decay = fog:Lerp(Color3.new(0, 0, 0), 0.4)
		end
	end
	-- headlamp below the reef
	local deepEnough = under and camPos.Y < Zones.List[2].Bottom + 20
	lamp.Light.Enabled = deepEnough
	if deepEnough then
		lamp.Part.CFrame = camera.CFrame
	end

	-- a big centre word (RUN! etc.) takes priority over the zone banner
	if hud.Banner.Visible and os.clock() - (UI.SlamAt or -10) < 0.2 then
		UnderwaterController.HideBanner()
	end
	if zone ~= lastZone then
		if zone and lastZone and zone.Index > lastZone.Index then
			showZoneBanner(zone)
		elseif zone and not lastZone then
			showZoneBanner(zone)
		end
		lastZone = zone
	end

	-- splash when your head crosses the surface
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if head then
		local y = head.Position.Y
		if lastHeadY and math.abs(head.Position.X) < Zones.List[1].Half and math.abs(head.Position.Z) < Zones.List[1].Half then
			local w = Zones.WaterLevel
			if (lastHeadY > w and y <= w) or (lastHeadY <= w and y > w) then
				splash(Vector3.new(head.Position.X, w, head.Position.Z))
			end
		end
		lastHeadY = y
	end

	-- HUD
	local air = player:GetAttribute("Oxygen")
	local maxAir = player:GetAttribute("OxygenMax")
	local headUnder = head ~= nil and Zones.InWater(head.Position + Vector3.new(0, 0.4, 0))
	local show = (headUnder or (air and maxAir and air < maxAir - 0.05)) and not UI.IsPanelOpen()
	if show and not hud.Root.Visible then
		hud.Root.Visible = true
		hud.Scale.Scale = 0.6
		Kit.tween(hud.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	elseif not show then
		hud.Root.Visible = false
	end
	if show and head and air and maxAir then
		hud.Depth.Text = string.format("%dm", math.floor(Zones.Depth(head.Position.Y) + 0.5))
		local z = Zones.At(head.Position.Y)
		hud.Zone.Text = if z then string.upper(z.Display) else "SURFACE"
		if z then
			local st = Guardians.StateOf(z.Index)
			hud.Guard.Text = if st == "Sleep" then (z.Guardian.Name .. ": asleep") else (z.Guardian.Name .. ": AWAKE!")
			hud.Guard.TextColor3 = if st == "Sleep" then Color3.fromRGB(170, 220, 255) else Color3.fromRGB(255, 110, 100)
		else
			hud.Guard.Text = ""
		end
		local frac = math.clamp(air / math.max(maxAir, 1), 0, 1)
		hud.Fill.Size = UDim2.fromScale(math.max(frac, 0.03), 1)
		local low = frac < 0.25
		hud.Fill.G.Color = if low then ColorSequence.new(Color3.fromRGB(255, 130, 120), Color3.fromRGB(230, 40, 40)) else ColorSequence.new(Color3.fromRGB(120, 225, 255), Color3.fromRGB(40, 140, 245))
		hud.Seconds.Text = string.format("%ds", math.ceil(air))
		hud.Seconds.TextColor3 = if low then Kit.Color.Danger else Kit.Color.Text
		hud.AirLabel.Text = if low then "LOW AIR!" else "AIR"
		hud.AirLabel.TextColor3 = if low then Kit.Color.Danger else Kit.Color.Text
		if low and headUnder then
			hud.AirScale.Scale = 1 + 0.06 * math.sin(os.clock() * 10)
			lowAirTick -= dt
			if lowAirTick <= 0 then
				lowAirTick = 1
				if Audio then
					Audio.Play("Tick")
				end
			end
		else
			hud.AirScale.Scale = 1
		end
		local charge = Dive.DashCharge
		hud.DashFill.Size = UDim2.fromScale(1, charge)
		hud.DashFill.BackgroundColor3 = if charge >= 1 then Kit.Swatch.green[2] else Kit.Swatch.gray[2]
		hud.DashLabel.Text = if charge >= 1 then "DASH" else string.format("%.0fs", (1 - charge) * 6)
	end
end

function UnderwaterController.Init(ui, dive, guardians, audio)
	UI = ui
	Kit = ui.Kit
	Dive = dive
	Guardians = guardians
	Audio = audio
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "UnderwaterTint"
	tint.Parent = camera
	blur = Instance.new("BlurEffect")
	blur.Name = "UnderwaterBlur"
	blur.Size = 0
	blur.Parent = camera
	local lampPart = Instance.new("Part")
	lampPart.Name = "Headlamp"
	lampPart.Anchored = true
	lampPart.CanCollide = false
	lampPart.CanQuery = false
	lampPart.CanTouch = false
	lampPart.Transparency = 1
	lampPart.Size = Vector3.new(0.2, 0.2, 0.2)
	lampPart.Parent = camera
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 60
	spot.Angle = 70
	spot.Brightness = 2.5
	spot.Color = Color3.fromRGB(220, 240, 255)
	spot.Shadows = false
	spot.Enabled = false
	spot.Parent = lampPart
	lamp = { Part = lampPart, Light = spot }
	findAtmosphere()
	buildHud(ui.GetGui())
	RunService.RenderStepped:Connect(step)
end

return UnderwaterController
