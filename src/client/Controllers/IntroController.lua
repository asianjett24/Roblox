-- Join intro: the camera sweeps around the island while the title drops in, then PLAY
-- flies the camera down to your diver and pops the HUD in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishData = require(Shared.FishData)
local Zones = require(Shared.Zones)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local IntroController = {}
IntroController.Done = false
local doneListeners = {}

function IntroController.OnDone(fn)
	if IntroController.Done then
		task.spawn(fn)
	else
		table.insert(doneListeners, fn)
	end
end

local function finish()
	IntroController.Done = true
	for _, fn in doneListeners do
		task.spawn(fn)
	end
end

local function setCore(enabled: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
	end)
end

function IntroController.Init(ui, audio)
	local Kit = ui.Kit
	local make, text, tween = Kit.make, Kit.text, Kit.tween
	local C, F = Kit.Color, Kit.Font

	local mainGui = ui.Root
	mainGui.Enabled = false
	setCore(false)

	local gui = make("ScreenGui", { Name = "Intro", IgnoreGuiInset = true, DisplayOrder = 30, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
	local screen = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local uiScale = make("UIScale", { Parent = screen })
	local vp = camera.ViewportSize
	local s = math.clamp(math.min(vp.X / 1400, vp.Y / 820), 0.5, 1.2)
	uiScale.Scale = s
	screen.Size = UDim2.fromScale(1 / s, 1 / s)

	-- cinematic bars + soft top/bottom shading
	local topBar = make("Frame", { Size = UDim2.new(1, 0, 0, 90), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = screen })
	local botBar = make("Frame", { Size = UDim2.new(1, 0, 0, 90), Position = UDim2.fromScale(0, 1), AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = screen })
	make("Frame", { Size = UDim2.new(1, 0, 0.45, 0), Position = UDim2.fromOffset(0, 90), BackgroundColor3 = Color3.fromRGB(8, 20, 50), BorderSizePixel = 0, Parent = screen }, {
		make("UIGradient", { Transparency = NumberSequence.new(0.35, 1), Rotation = 90 }),
	})

	-- Atlas decorations: slow light rays behind the title, rolling waves and rising bubbles
	local rays = Kit.sprite("burst", { Size = UDim2.fromOffset(1300, 1300), Position = UDim2.new(0.5, 0, 0, 230), AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 0.8, Parent = screen })
	local waves = {}
	for _, spec in { { "wave_soft", Color3.fromRGB(70, 170, 235), 0.25, 150, 18 }, { "wave", Color3.fromRGB(25, 95, 180), 0.05, 120, -30 } } do
		local w = Kit.sprite(spec[1], {
			Size = UDim2.new(1, 1024, 0, spec[4]), Position = UDim2.new(0, 0, 1, -88), AnchorPoint = Vector2.new(0, 1),
			ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(512, spec[4]), ImageColor3 = spec[2], ImageTransparency = spec[3], Parent = screen,
		})
		if w then
			table.insert(waves, { Img = w, Speed = spec[5] })
		end
	end
	local bubbles = {}
	if Kit.HasAtlas() then
		for i = 1, 16 do
			local size = math.random(14, 40)
			local b = Kit.sprite("bubble", { Size = UDim2.fromOffset(size, size), Position = UDim2.fromScale(math.random(), 1 + math.random() * 0.6), ImageTransparency = 0.25, Parent = screen })
			table.insert(bubbles, { Img = b, X = math.random(), Speed = 0.04 + math.random() * 0.08, Phase = math.random() * 6, Y = math.random() })
		end
	end

	-- Title
	local logo = make("Frame", { Size = UDim2.fromOffset(900, 260), Position = UDim2.new(0.5, 0, 0, -300), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = screen })
	local line1 = text("SPEARFISHING", 104, F.Title, Color3.new(1, 1, 1), { Size = UDim2.new(1, 0, 0, 116), AutomaticSize = Enum.AutomaticSize.None, Parent = logo })
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 150, 30)), Rotation = 90, Parent = line1 })
	line1:FindFirstChildOfClass("UIStroke").Thickness = 9
	local line2 = text("COVE", 92, F.Title, Color3.new(1, 1, 1), { Size = UDim2.new(1, 0, 0, 100), Position = UDim2.fromOffset(0, 100), AutomaticSize = Enum.AutomaticSize.None, Rotation = -3, Parent = logo })
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(130, 230, 255), Color3.fromRGB(40, 130, 245)), Rotation = 90, Parent = line2 })
	line2:FindFirstChildOfClass("UIStroke").Thickness = 8
	local tagline = text("Spear rare sea creatures. Outswim the guardians.", 26, F.Title, C.Text, { Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 206), AutomaticSize = Enum.AutomaticSize.None, TextTransparency = 1, Parent = logo })
	local tagStroke = tagline:FindFirstChildOfClass("UIStroke")
	if tagStroke then
		tagStroke.Transparency = 1
	end
	-- a fish icon swimming across the title
	local swimmer = Kit.icon("fish", 70, Color3.fromRGB(255, 140, 60), { Position = UDim2.new(-0.1, 0, 0, 120), Parent = logo })

	-- facts
	local creatures = #FishData.Fish
	local facts = make("Frame", { Size = UDim2.fromOffset(900, 44), Position = UDim2.new(0.5, 0, 0, 372), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = screen }, {
		Kit.list(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local chips = {}
	for i, info in { { #Zones.List .. " DIVE ZONES", "blue" }, { creatures .. " CREATURES", "green" }, { #Zones.List .. " GUARDIANS", "red" } } do
		local sw = Kit.Swatch[info[2]]
		local chip = make("Frame", { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, Parent = facts }, {
			Kit.round(), Kit.outline(3), Kit.pad(0, 18),
			make("UIGradient", { Color = ColorSequence.new(sw[1], sw[2]), Rotation = 90 }),
		})
		text(info[1], 20, F.Title, C.Text, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = chip })
		local sc = make("UIScale", { Scale = 0, Parent = chip })
		chips[i] = sc
	end

	-- icon credit (game-icons.net, CC BY 3.0)
	text("Icons: game-icons.net (Lorc, Delapouite & co.), CC BY 3.0", 13, F.Bold, Color3.fromRGB(200, 220, 255), {
		Position = UDim2.new(1, -12, 1, -8), AnchorPoint = Vector2.new(1, 1), TextTransparency = 0.3, Parent = screen,
	})

	-- PLAY
	local play = Kit.button("PLAY", "green", { Size = UDim2.fromOffset(300, 92), Position = UDim2.new(0.5, 0, 1, -150), AnchorPoint = Vector2.new(0.5, 1), TextSize = 52, Parent = screen })
	local playScale = play:FindFirstChildOfClass("UIScale")
	playScale.Scale = 0

	-- Camera orbit ---------------------------------------------------------------------------------
	camera.CameraType = Enum.CameraType.Scriptable
	local angle = math.rad(200)
	local playing = true
	local focus = Vector3.new(0, -10, 40)
	local conn = RunService.RenderStepped:Connect(function(dt)
		if not playing then
			return
		end
		angle += dt * 0.07
		local pos = focus + Vector3.new(math.cos(angle) * 250, 95 + math.sin(angle * 0.7) * 12, math.sin(angle) * 250)
		camera.CFrame = CFrame.lookAt(pos, focus)
		if rays then
			rays.Rotation += dt * 5
		end
		for _, w in waves do
			w.Img.Position = UDim2.new(0, -((os.clock() * math.abs(w.Speed)) % 512) * (if w.Speed < 0 then 1 else -1) - (if w.Speed < 0 then 0 else 512), 1, -88)
		end
		for _, b in bubbles do
			b.Y -= dt * b.Speed
			if b.Y < -0.1 then
				b.Y = 1.1
				b.X = math.random()
			end
			b.Img.Position = UDim2.fromScale(b.X + math.sin(os.clock() * 1.5 + b.Phase) * 0.01, b.Y)
		end
		-- title bob + swimming fish
		line2.Rotation = -3 + math.sin(os.clock() * 1.6) * 2
		swimmer.Position = UDim2.new(((os.clock() * 0.09) % 1.3) - 0.15, 0, 0, 118 + math.sin(os.clock() * 3) * 10)
		swimmer.Rotation = math.sin(os.clock() * 6) * 8
	end)

	-- Entrance
	task.delay(0.3, function()
		tween(logo, 0.8, { Position = UDim2.new(0.5, 0, 0, 100) }, Enum.EasingStyle.Bounce)
		task.wait(0.7)
		tween(tagline, 0.4, { TextTransparency = 0 })
		if tagStroke then
			tween(tagStroke, 0.4, { Transparency = 0 })
		end
		for _, sc in chips do
			tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			task.wait(0.12)
		end
		tween(playScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		-- breathe the play button
		task.spawn(function()
			while playing and gui.Parent do
				tween(playScale, 0.6, { Scale = 1.08 }, Enum.EasingStyle.Sine)
				task.wait(0.6)
				if not playing then
					break
				end
				tween(playScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Sine)
				task.wait(0.6)
			end
		end)
	end)

	local started = false
	play.Activated:Connect(function()
		if started then
			return
		end
		started = true
		if audio then
			audio.Play("Dive")
		end
		local char = player.Character or player.CharacterAdded:Wait()
		local head = char:WaitForChild("Head", 10)
		playing = false
		tween(logo, 0.35, { Position = UDim2.new(0.5, 0, 0, -320) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(playScale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		for _, sc in chips do
			tween(sc, 0.2, { Scale = 0 })
		end
		tween(topBar, 0.6, { Position = UDim2.fromOffset(0, -100) })
		tween(botBar, 0.6, { Position = UDim2.new(0, 0, 1, 100) })
		-- fly down behind the diver
		if head then
			local look = head.CFrame.LookVector
			local goal = CFrame.lookAt(head.Position - look * 14 + Vector3.new(0, 5, 0), head.Position)
			local cfValue = Instance.new("CFrameValue")
			cfValue.Value = camera.CFrame
			local c2 = cfValue.Changed:Connect(function(v)
				camera.CFrame = v
			end)
			local tw = TweenService:Create(cfValue, TweenInfo.new(1.3, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), { Value = goal })
			tw:Play()
			tw.Completed:Wait()
			c2:Disconnect()
			cfValue:Destroy()
		end
		conn:Disconnect()
		camera.CameraType = Enum.CameraType.Custom
		gui:Destroy()
		mainGui.Enabled = true
		setCore(true)
		finish()
	end)
end

return IntroController
