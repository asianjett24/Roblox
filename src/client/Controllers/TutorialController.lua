-- First-time tutorial. One instruction card at a fixed spot near the bottom of the screen,
-- a bouncing marker in the world for "jump in" and "shoot this fish", and a spotlight
-- (the rest of the screen dims) only when a menu button has to be clicked. Steps move on
-- when you do the thing; getting bitten sends you back to try again. Shown once per player.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishPath = require(Shared.FishPath)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local TutorialController = {}

local UI, Kit, Dive, Spear, Renderer, Audio

local function isCarrying(): boolean
	local v = player:GetAttribute("Carrying")
	return type(v) == "string" and v ~= ""
end

local function bagCount(): number
	return if UI.Data then #UI.Data.Inventory else 0
end

local function nearestWater(): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local h = Zones.List[1].Half - 10
	local p = root.Position
	return Vector3.new(math.clamp(p.X, -h, h), Zones.WaterLevel + 2, math.clamp(p.Z, -h, h))
end

local function run()
	local make, text, tween, icon = Kit.make, Kit.text, Kit.tween, Kit.icon
	local C, F = Kit.Color, Kit.Font

	-- Same coordinates as the main UI (not ignoring the top bar), scaled the same way.
	local gui = make("ScreenGui", { Name = "Tutorial", DisplayOrder = 25, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
	local full = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local screen = make("Frame", { BackgroundTransparency = 1, ZIndex = 2, Parent = gui })
	local uiScale = make("UIScale", { Parent = screen })
	local function fit()
		local sc = if UI.Scale then UI.Scale.Scale else 1
		uiScale.Scale = sc
		screen.Size = UDim2.fromScale(1 / sc, 1 / sc)
	end
	fit()
	if UI.Scale then
		UI.Scale:GetPropertyChangedSignal("Scale"):Connect(fit)
	end

	-- Spotlight: a clear circle whose huge outline dims everything else (menu steps only)
	local hole = make("Frame", { Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = full }, { Kit.round() })
	local shade = make("UIStroke", { Color = Color3.fromRGB(4, 8, 22), Thickness = 3000, Transparency = 1, Parent = hole })
	local ring = make("Frame", { Size = UDim2.new(1, 12, 1, 12), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = hole }, {
		Kit.round(),
		make("UIStroke", { Color = Color3.fromRGB(255, 220, 90), Thickness = 5 }),
	})
	local pointer = icon("down", 56, Color3.fromRGB(255, 220, 90), { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = full })

	-- Instruction card (bottom centre, above the dive HUD)
	local CARD_W, CARD_H = 600, 136
	local card = make("Frame", { Size = UDim2.fromOffset(CARD_W, CARD_H), Position = UDim2.new(0.5, 0, 1, -224), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = screen })
	local pop = make("UIScale", { Parent = card })
	Kit.softShadow(card, 18, 10, 0.3)
	make("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 7), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.2, Parent = card }, { Kit.corner(20) })
	local face = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = card }, {
		Kit.corner(20),
		make("UIGradient", { Color = ColorSequence.new(Kit.Swatch.navy[1], Kit.Swatch.navy[2]), Rotation = 90 }),
		Kit.outline(4),
	})
	Kit.checker(face, 18, 0.93, nil, CARD_W, CARD_H)
	local badge = make("Frame", { Size = UDim2.fromOffset(92, 92), Position = UDim2.fromOffset(16, 22), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = face }, {
		Kit.corner(18),
		make("UIGradient", { Name = "G", Color = ColorSequence.new(Kit.Swatch.blue[1], Kit.Swatch.blue[2]), Rotation = 90 }),
		Kit.outline(3),
	})
	Kit.shine(badge, 14)
	local badgeIcon
	local title = text("", 28, F.Title, C.Gold, { Position = UDim2.fromOffset(124, 12), ZIndex = 3, Parent = face })
	local body = text("", 19, F.Bold, C.Text, {
		Size = UDim2.fromOffset(CARD_W - 140, 70), Position = UDim2.fromOffset(124, 52), AutomaticSize = Enum.AutomaticSize.None,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3, Parent = face,
	})
	local dots = make("Frame", { Size = UDim2.fromOffset(0, 12), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(1, -18, 0, 22), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, ZIndex = 3, Parent = face }, {
		Kit.list(Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center),
	})
	local nextBtn, _, nextLabel = Kit.button("NEXT", "green", { Size = UDim2.fromOffset(170, 46), Position = UDim2.new(1, -14, 1, -14), AnchorPoint = Vector2.new(1, 1), TextSize = 22, Parent = card })
	nextBtn.ZIndex = 4
	local skip = Kit.button("SKIP TUTORIAL", "gray", { Size = UDim2.fromOffset(150, 34), Position = UDim2.new(1, 0, 0, -44), AnchorPoint = Vector2.new(1, 0), TextSize = 15, Parent = card })

	-- World marker: a bouncing arrow with a label (dive spot, target fish)
	local anchor = make("Part", { Name = "TutorialMarker", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), Parent = camera })
	local marker = make("BillboardGui", { Size = UDim2.fromOffset(170, 130), StudsOffsetWorldSpace = Vector3.new(0, 3, 0), AlwaysOnTop = true, LightInfluence = 0, Enabled = false, Adornee = anchor, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
	local markerLabel = text("", 26, F.Title, C.Gold, { Size = UDim2.new(1, 0, 0, 32), AutomaticSize = Enum.AutomaticSize.None, Parent = marker })
	local markerArrow = icon("down", 64, Color3.fromRGB(255, 220, 90), { Position = UDim2.new(0.5, 0, 0, 40), AnchorPoint = Vector2.new(0.5, 0), Parent = marker })

	-- Steps -----------------------------------------------------------------------------------
	local escaped, bitten = false, false
	Remotes.ChaseEvent.OnClientEvent:Connect(function(kind, info)
		if info and info.Player == player.UserId then
			if kind == "Escaped" then
				escaped = true
			elseif kind == "Bitten" then
				bitten = true
			end
		end
	end)
	local startCoins = 0

	local STEPS = {
		{
			Id = "welcome", Icon = "fish", Swatch = "blue",
			Title = "Welcome, diver!",
			Body = "Spear sea creatures, then swim them back up before the guardian bites you.",
			Button = "LET'S GO!",
		},
		{
			Id = "equip", Icon = "shop", Swatch = "orange",
			Title = "Grab your speargun",
			Body = if UserInputService.TouchEnabled then "Tap the speargun at the bottom of the screen." else "Press 1 (or click the speargun at the bottom).",
			Spot = function()
				local vp = camera.ViewportSize
				local inset = GuiService:GetGuiInset()
				return Vector2.new(vp.X / 2, vp.Y - inset.Y - 42), 46
			end,
			Done = function()
				return Spear.HasGun()
			end,
		},
		{
			Id = "dive", Icon = "down", Swatch = "blue",
			Title = "Jump in the water",
			Body = "Follow the arrow and swim down. Underwater you'll see in first person.",
			Marker = function()
				return nearestWater(), "JUMP IN!"
			end,
			Done = function()
				return Dive.Underwater
			end,
		},
		{
			Id = "shoot", Icon = "fish", Swatch = "green",
			Title = "Spear a creature",
			Body = "Aim at the marked fish and click to fire. Rarer ones need more hits.",
			Marker = function()
				local e, d = Renderer.Nearest(camera.CFrame.Position)
				if e and d < 140 then
					return FishPath.Position(e.Seg, workspace:GetServerTimeNow()), "SHOOT IT!"
				end
				return nil, nil
			end,
			OnEnter = function()
				bitten = false
			end,
			Done = function()
				return isCarrying()
			end,
		},
		{
			Id = "escape", Icon = "shark", Swatch = "red",
			Title = "Swim UP to escape!",
			Body = "The guardian woke up! Get your head above the water to keep your catch.",
			OnEnter = function()
				escaped, bitten = false, false
			end,
			Done = function()
				return escaped
			end,
			Back = function()
				if bitten and not isCarrying() then
					UI.Notify("The guardian got you! Try again, and swim up faster.", "error")
					return "shoot"
				end
				return nil
			end,
		},
		{
			Id = "bag", Icon = "bag", Swatch = "green",
			Title = "Open your Bag",
			Body = "Your catch is in your Bag. Click the Bag button (or press B).",
			Spot = function()
				return UI.GetAnchor("Bag")
			end,
			Skip = function()
				return bagCount() == 0
			end,
			Done = function()
				return UI.OpenPanelName() == "Bag"
			end,
		},
		{
			Id = "sell", Icon = "coin", Swatch = "yellow",
			Title = "Sell your catch",
			Body = "Click SELL ALL to turn your fish into coins.",
			Spot = function()
				return UI.GetAnchor("SellAll")
			end,
			OnEnter = function()
				startCoins = if UI.Data then UI.Data.Coins else 0
			end,
			Skip = function()
				return bagCount() == 0
			end,
			Done = function()
				return bagCount() == 0 or (UI.Data ~= nil and UI.Data.Coins > startCoins)
			end,
			Back = function()
				if UI.OpenPanelName() ~= "Bag" and bagCount() > 0 then
					return "bag"
				end
				return nil
			end,
		},
		{
			Id = "shop", Icon = "flippers", Swatch = "orange",
			Title = "Get faster",
			Body = "Faster Flippers help you outswim guardians. Open the Shop (or press V).",
			Spot = function()
				return UI.GetAnchor("Shop")
			end,
			OnEnter = function()
				if UI.OpenPanelName() == "Bag" then
					UI.Open(nil)
				end
			end,
			Done = function()
				return UI.OpenPanelName() == "Shop"
			end,
		},
		{
			Id = "done", Icon = "trophy", Swatch = "yellow",
			Title = "You're ready!",
			Body = "Deeper zones hide rarer creatures and faster guardians. Here's 100 coins to start!",
			Button = "PLAY!",
		},
	}
	local indexOf = {}
	for i, st in STEPS do
		indexOf[st.Id] = i
	end
	local dotFrames = {}
	for i = 1, #STEPS do
		dotFrames[i] = make("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(120, 140, 190), LayoutOrder = i, ZIndex = 3, Parent = dots }, { Kit.round(), Kit.outline(1.5) })
	end

	local index, current = 0, nil
	local pressed, finished = false, false
	nextBtn.Activated:Connect(function()
		pressed = true
	end)

	local function finish()
		if finished then
			return
		end
		finished = true
		Spear.HintLocked = false
		task.spawn(function()
			Remotes.CompleteTutorial:InvokeServer()
		end)
		anchor:Destroy()
		marker:Destroy()
		tween(pop, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(shade, 0.3, { Transparency = 1 })
		task.delay(0.35, function()
			gui:Destroy()
		end)
	end
	skip.Activated:Connect(finish)

	local function show(i)
		while STEPS[i] and STEPS[i].Skip and STEPS[i].Skip() do
			i += 1
		end
		index = i
		current = STEPS[i]
		if not current then
			finish()
			return
		end
		if current.OnEnter then
			current.OnEnter()
		end
		pressed = false
		title.Text = current.Title
		body.Text = current.Body
		nextBtn.Visible = current.Button ~= nil
		nextLabel.Text = current.Button or "NEXT"
		body.Size = UDim2.fromOffset(if current.Button then CARD_W - 320 else CARD_W - 140, 70)
		if badgeIcon then
			badgeIcon:Destroy()
		end
		badgeIcon = icon(current.Icon, 60, nil, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = badge })
		local sw = Kit.Swatch[current.Swatch] or Kit.Swatch.blue
		badge.G.Color = ColorSequence.new(sw[1], sw[2])
		for k, dot in dotFrames do
			dot.BackgroundColor3 = if k < i then Kit.Swatch.green[1] elseif k == i then C.Gold else Color3.fromRGB(120, 140, 190)
			dot.Size = if k == i then UDim2.fromOffset(22, 10) else UDim2.fromOffset(10, 10)
		end
		pop.Scale = 0.6
		tween(pop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		if Audio then
			Audio.Play("Open")
		end
	end

	Spear.HintLocked = true
	UI.SetHint(nil)
	show(1)

	local holeR, holePos = 0, nil
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if finished or not gui.Parent then
			conn:Disconnect()
			return
		end
		UI.SetHint(nil)
		if current.Back then
			local back = current.Back()
			if back then
				show(indexOf[back])
				return
			end
		end
		if (current.Done and current.Done()) or (current.Button and pressed) then
			if Audio then
				Audio.Play("Escape")
			end
			if index >= #STEPS then
				finish()
				return
			end
			show(index + 1)
			return
		end
		-- hide the card while the catch card is on screen
		card.Visible = os.clock() > (UI.CatchUntil or 0)

		-- spotlight for menu steps
		local center, radius = nil, nil
		if current.Spot then
			local a, b = current.Spot()
			if typeof(a) == "Instance" then
				center = a.AbsolutePosition + a.AbsoluteSize / 2
				radius = math.max(a.AbsoluteSize.X, a.AbsoluteSize.Y) / 2 + 12
			elseif a then
				center, radius = a, b or 46
			end
		end
		local wantR = if center then radius else 0
		holeR += (wantR - holeR) * math.min(1, dt * 10)
		if center then
			holePos = if holePos then holePos:Lerp(center, math.min(1, dt * 12)) else center
		end
		hole.Visible = center ~= nil or holeR > 2
		shade.Transparency = if center then 0.45 else 1
		ring.Visible = center ~= nil
		pointer.Visible = center ~= nil
		if holePos then
			local r = holeR * (1 + math.sin(os.clock() * 4) * 0.04)
			hole.Position = UDim2.fromOffset(holePos.X, holePos.Y)
			hole.Size = UDim2.fromOffset(r * 2, r * 2)
			if center then
				local vp = camera.ViewportSize
				local bounce = math.sin(os.clock() * 6) * 8
				-- point at it from whichever side has room
				if holePos.X < vp.X * 0.25 then
					pointer.Position = UDim2.fromOffset(holePos.X + r + 44 + bounce, holePos.Y)
					pointer.Rotation = 90
				elseif holePos.Y > vp.Y * 0.5 then
					pointer.Position = UDim2.fromOffset(holePos.X, holePos.Y - r - 44 + bounce)
					pointer.Rotation = 0
				else
					pointer.Position = UDim2.fromOffset(holePos.X, holePos.Y + r + 44 - bounce)
					pointer.Rotation = 180
				end
			end
		end

		-- world marker for gameplay steps
		local where, label = nil, nil
		if current.Marker then
			where, label = current.Marker()
		end
		marker.Enabled = where ~= nil
		if where then
			anchor.CFrame = CFrame.new(where)
			markerLabel.Text = label or ""
			markerArrow.Position = UDim2.new(0.5, 0, 0, 40 + math.sin(os.clock() * 6) * 8)
		end
	end)
end

function TutorialController.Init(ui, dive, spear, intro, audio, renderer)
	UI = ui
	Kit = ui.Kit
	Dive = dive
	Spear = spear
	Audio = audio
	Renderer = renderer
	intro.OnDone(function()
		-- wait for the save to load
		local t = 0
		while not UI.Data and t < 15 do
			t += task.wait(0.25)
		end
		if UI.Data and not UI.Data.TutorialDone then
			task.wait(0.6)
			run()
		end
	end)
end

return TutorialController
