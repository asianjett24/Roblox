-- First-time tutorial: the screen goes dark except for a circle around the thing to use
-- next, with a bouncing arrow and a short instruction card. Steps move on by themselves
-- when you do the thing (or with NEXT), and SKIP ends it. Shown once per player.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local TutorialController = {}

local UI, Kit, Dive, Spear, Audio

local function guiCenter(obj: GuiObject?)
	if not obj then
		return nil
	end
	local inset = GuiService:GetGuiInset()
	local c = obj.AbsolutePosition + obj.AbsoluteSize / 2 + Vector2.new(0, inset.Y)
	return c, math.max(obj.AbsoluteSize.X, obj.AbsoluteSize.Y) / 2 + 14
end

local function worldCenter(p: Vector3, radius: number)
	local v, onScreen = camera:WorldToViewportPoint(p)
	if not onScreen or v.Z <= 0 then
		return nil
	end
	return Vector2.new(v.X, v.Y), radius
end

local function isCarrying()
	local v = player:GetAttribute("Carrying")
	return type(v) == "string" and v ~= ""
end

local function nearestWater()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local h = Zones.List[1].Half - 12
	local p = root.Position
	return Vector3.new(math.clamp(p.X, -h, h), Zones.WaterLevel, math.clamp(p.Z, -h, h))
end

-- Steps: Target() -> screen centre + radius (or nil for no circle), Done() -> true to advance.
local function steps()
	local caughtOnce = false
	local escapedOnce = false
	Remotes.ChaseEvent.OnClientEvent:Connect(function(kind, info)
		if (kind == "Escaped" or kind == "Bitten") and info.Player == player.UserId then
			escapedOnce = true
		end
	end)
	return {
		{
			Title = "WELCOME, DIVER!",
			Body = "Spear sea creatures, escape the guardian of each zone, and fill your aquarium!",
			Button = "LET'S GO!",
			Dim = 0.35,
		},
		{
			Title = "GRAB YOUR SPEARGUN",
			Body = if UserInputService.TouchEnabled then "Tap the speargun in your hotbar." else "Press 1 (or click it in your hotbar).",
			Target = function()
				local vp = camera.ViewportSize
				return Vector2.new(vp.X / 2, vp.Y - 46), 46
			end,
			Done = function()
				return Spear.HasGun()
			end,
			Dim = 0.45,
		},
		{
			Title = "DIVE IN!",
			Body = "Walk to the water and swim down. Underwater you see in first person.",
			Target = function()
				local w = nearestWater()
				if not w then
					return nil
				end
				return worldCenter(w, 70)
			end,
			Done = function()
				return Dive.Underwater
			end,
			Dim = 0.6,
		},
		{
			Title = "SPEAR A CREATURE",
			Body = "Aim at a fish and click to fire. Bigger, rarer ones take more hits.",
			Target = function()
				local vp = camera.ViewportSize
				return Vector2.new(vp.X / 2, vp.Y / 2), 70
			end,
			Done = function()
				caughtOnce = caughtOnce or isCarrying()
				return caughtOnce
			end,
			Dim = 0.7,
		},
		{
			Title = "NOW RUN!",
			Body = "The zone's guardian wakes up. Swim UP and get your head out of the water to keep your catch!",
			Target = function()
				local vp = camera.ViewportSize
				return Vector2.new(vp.X / 2, 100), 60
			end,
			Done = function()
				return escapedOnce or not isCarrying()
			end,
			Dim = 0.75,
		},
		{
			Title = "YOUR BAG",
			Body = "Your catches go in your bag. Sell them at the Fish Market or right from here.",
			Target = function()
				return guiCenter(UI.GetAnchor("Bag"))
			end,
			Done = function()
				return UI.IsPanelOpen()
			end,
			Dim = 0.35,
		},
		{
			Title = "GET FASTER",
			Body = "Upgrade your Flippers and Air Tank in the Gear Shop to outswim deeper guardians.",
			Target = function()
				return guiCenter(UI.GetAnchor("Shop"))
			end,
			Done = function()
				return false
			end,
			OnShow = function()
				UI.Open(nil)
			end,
			Button = "GOT IT!",
			Dim = 0.35,
		},
		{
			Title = "YOU'RE READY!",
			Body = "Deeper zones hide rarer creatures... and meaner guardians. Good luck!",
			Button = "START (+100 COINS)",
			Dim = 0.35,
		},
	}
end

local function run()
	local make, text, tween = Kit.make, Kit.text, Kit.tween
	local C, F = Kit.Color, Kit.Font
	local gui = make("ScreenGui", { Name = "Tutorial", IgnoreGuiInset = true, DisplayOrder = 25, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })

	-- the spotlight: a transparent circle whose huge outline darkens everything else
	local hole = make("Frame", { Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui }, { Kit.round() })
	local shade = make("UIStroke", { Color = Color3.fromRGB(4, 8, 22), Thickness = 3000, Transparency = 0.35, Parent = hole })
	local ring = make("Frame", { Size = UDim2.new(1, 10, 1, 10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = hole }, {
		Kit.round(),
		make("UIStroke", { Color = Color3.fromRGB(255, 220, 90), Thickness = 4 }),
	})
	local arrow = Kit.icon("depth", 64, Color3.fromRGB(255, 220, 90), { AnchorPoint = Vector2.new(0.5, 0.5), Parent = gui })

	-- instruction card
	local scaleV = math.clamp(math.min(camera.ViewportSize.X / 1400, camera.ViewportSize.Y / 820), 0.6, 1.1)
	local card = make("Frame", { Size = UDim2.fromOffset(500, 150), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui })
	make("UIScale", { Scale = scaleV, Parent = card })
	local cardPop = make("UIScale", { Parent = make("Frame", { Name = "Pop", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = card }) })
	local pop = cardPop.Parent
	make("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, Parent = pop }, { Kit.corner(20) })
	local face = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = pop }, {
		Kit.corner(20),
		make("UIGradient", { Color = ColorSequence.new(C.PanelTop, C.PanelBottom), Rotation = 90 }),
		Kit.outline(4),
	})
	Kit.checker(face, 20, 0.92, nil, 500, 150)
	local title = text("", 30, F.Title, C.Gold, { Position = UDim2.fromOffset(18, 10), ZIndex = 2, Parent = face })
	local body = text("", 19, F.Bold, C.Text, { Size = UDim2.new(1, -36, 0, 54), Position = UDim2.fromOffset(18, 50), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 2, Parent = face })
	local counter = text("", 14, F.Title, C.Sub, { Position = UDim2.new(0, 18, 1, -30), ZIndex = 2, Parent = face })
	local nextBtn, _, nextLabel = Kit.button("NEXT", "green", { Size = UDim2.fromOffset(190, 44), Position = UDim2.new(1, -204, 1, -56), Parent = face })
	nextBtn.ZIndex = 3
	local skip = Kit.button("SKIP", "gray", { Size = UDim2.fromOffset(100, 40), Position = UDim2.new(1, -16, 0, 16), AnchorPoint = Vector2.new(1, 0), TextSize = 18, Parent = gui })
	make("UIScale", { Scale = scaleV, Parent = skip })

	local list = steps()
	local index = 0
	local pressed = false
	local finished = false
	nextBtn.Activated:Connect(function()
		pressed = true
	end)
	local function finish()
		if finished then
			return
		end
		finished = true
		UI.SetHint(nil)
		Spear.HintLocked = false
		task.spawn(function()
			Remotes.CompleteTutorial:InvokeServer()
		end)
		tween(cardPop, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(shade, 0.35, { Transparency = 1 })
		task.delay(0.4, function()
			gui:Destroy()
		end)
	end
	skip.Activated:Connect(finish)

	local current
	local function show(i)
		index = i
		current = list[i]
		if not current then
			finish()
			return
		end
		if current.OnShow then
			current.OnShow()
		end
		pressed = false
		title.Text = current.Title
		body.Text = current.Body
		counter.Text = string.format("STEP %d / %d", i, #list)
		nextBtn.Visible = current.Button ~= nil
		nextLabel.Text = current.Button or "NEXT"
		cardPop.Scale = 0.5
		tween(cardPop, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(shade, 0.3, { Transparency = current.Dim or 0.35 })
		if Audio then
			Audio.Play("Open")
		end
	end
	show(1)

	local holeRadius, holePos = 0, nil
	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if finished or not gui.Parent then
			conn:Disconnect()
			return
		end
		if (current.Done and current.Done()) or (current.Button and pressed) then
			if Audio then
				Audio.Play("Click")
			end
			if index == #list then
				finish()
				return
			end
			show(index + 1)
			return
		end
		local vp = camera.ViewportSize
		local center, radius = nil, nil
		if current.Target then
			center, radius = current.Target()
			if center and not radius then
				radius = 50
			end
		end
		-- the circle eases toward its target and breathes
		local wantR = if center then radius else 0
		holeRadius += (wantR - holeRadius) * math.min(1, dt * 8)
		if center then
			holePos = if holePos then holePos:Lerp(center, math.min(1, dt * 10)) else center
		end
		local p = holePos or vp / 2
		local breathe = 1 + math.sin(os.clock() * 4) * 0.05
		local r = holeRadius * breathe
		hole.Position = UDim2.fromOffset(p.X, p.Y)
		hole.Size = UDim2.fromOffset(r * 2, r * 2)
		ring.Visible = center ~= nil and holeRadius > 4
		-- arrow points at the circle from above (or below if it's near the top)
		arrow.Visible = center ~= nil
		if center then
			local above = p.Y > vp.Y * 0.3
			local bounce = math.sin(os.clock() * 6) * 10
			if above then
				arrow.Position = UDim2.fromOffset(p.X, p.Y - r - 44 + bounce)
				arrow.Rotation = 0
			else
				arrow.Position = UDim2.fromOffset(p.X, p.Y + r + 44 - bounce)
				arrow.Rotation = 180
			end
		end
		-- card: middle of the screen with no target, else on the far side of the circle
		local cardH = 150 * scaleV
		local y
		if not center then
			y = vp.Y / 2 - cardH / 2
		elseif p.Y > vp.Y * 0.5 then
			y = math.max(20, p.Y - r - 90 - cardH)
		else
			y = math.min(vp.Y - cardH - 20, p.Y + r + 90)
		end
		card.Position = UDim2.fromOffset(vp.X / 2, y)
	end)
end

function TutorialController.Init(ui, dive, spear, intro, audio)
	UI = ui
	Kit = ui.Kit
	Dive = dive
	Spear = spear
	Audio = audio
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
