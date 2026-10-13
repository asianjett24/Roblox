-- Cast -> wait for a bite -> reel minigame.
-- Minigame: hold click / tap / Space to lift the green bar and keep the fish inside it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RodData = require(Shared.RodData)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FishingController = {}

local UI
local Kit
local state = "idle" -- idle | casting | waiting | reeling
local token = nil
local currentTool: Tool? = nil
local holding = false
local minigame = nil
local fxParts = {} -- client-only bobber parts for this cast
local landing: Vector3? = nil -- where the bobber floats
local placeBobber = nil

local WATER_SPLASH = Color3.fromRGB(200, 235, 255)

-- Hints ---------------------------------------------------------------------
local function updateHint()
	if not UI then
		return
	end
	if state == "reeling" then
		UI.SetHint(nil)
	elseif state == "waiting" then
		UI.SetHint("Waiting for a bite...  (click to reel in)")
	elseif currentTool then
		UI.SetHint("Click the water to cast")
	else
		UI.SetHint("Press 1 to hold your rod")
	end
end

-- Effects ---------------------------------------------------------------------
local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = workspace
	table.insert(fxParts, p)
	return p
end

local function clearFx()
	for _, p in fxParts do
		p:Destroy()
	end
	table.clear(fxParts)
	landing = nil
	placeBobber = nil
end

local function splash(pos: Vector3, amount: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.Position = pos
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(WATER_SPLASH)
	e.LightEmission = 0.4
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.4, 0.7)
	e.Speed = NumberRange.new(6, 11)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = holder
	e:Emit(amount)
	task.delay(1, function()
		holder:Destroy()
	end)
end

local function ripple(pos: Vector3)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = WATER_SPLASH
	ring.Transparency = 0.35
	ring.Size = Vector3.new(0.05, 1, 1)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(1.4, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, 7, 7), Transparency = 1 }):Play()
	task.delay(1.4, function()
		ring:Destroy()
	end)
end

local function tipAttachment(): Attachment?
	local handle = currentTool and currentTool:FindFirstChild("Handle")
	return handle and handle:FindFirstChild("Tip")
end

-- Throws the bobber in an arc from the rod tip to the target.
local function throwBobber(target: Vector3, myToken)
	clearFx()
	local float = fxPart({ Name = "Bobber", Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 0.75, 0.75), Color = Color3.fromRGB(230, 50, 50) })
	local cap = fxPart({ Name = "BobberTop", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55), Color = Color3.fromRGB(250, 250, 250) })
	local stick = fxPart({ Name = "BobberStick", Size = Vector3.new(0.1, 0.5, 0.1), Color = Color3.fromRGB(250, 250, 250) })
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 0.55, 0)
	att.Parent = float

	local tip = tipAttachment()
	if tip then
		local line = Instance.new("Beam")
		line.Attachment0 = tip
		line.Attachment1 = att
		line.Width0 = 0.04
		line.Width1 = 0.04
		line.Color = ColorSequence.new(Color3.fromRGB(245, 245, 245))
		line.Transparency = NumberSequence.new(0.15)
		line.FaceCamera = true
		line.Segments = 16
		line.Parent = float
	end

	local function place(pos: Vector3)
		float.CFrame = CFrame.new(pos)
		cap.CFrame = CFrame.new(pos + Vector3.new(0, 0.32, 0))
		stick.CFrame = CFrame.new(pos + Vector3.new(0, 0.7, 0))
	end

	local from = if tip then tip.WorldPosition else target + Vector3.new(0, 6, 0)
	local spot = target + Vector3.new(0, 0.15, 0)
	local dur = 0.45
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		local a = (os.clock() - t0) / dur
		place(from:Lerp(spot, a) + Vector3.new(0, math.sin(a * math.pi) * 6, 0))
		RunService.RenderStepped:Wait()
		if token ~= myToken then
			return
		end
	end
	place(spot)
	splash(spot, 14)
	ripple(spot)
	landing = spot
	placeBobber = place

	-- Idle bob + ripples until something bites
	task.spawn(function()
		local start = os.clock()
		local lastRipple = start
		while token == myToken and state == "waiting" and float.Parent do
			local now = os.clock()
			place(spot + Vector3.new(0, math.sin((now - start) * 3) * 0.08, 0))
			if now - lastRipple > 1.8 then
				lastRipple = now
				ripple(spot)
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

local function biteEffect()
	if not landing or not placeBobber then
		return
	end
	placeBobber(landing - Vector3.new(0, 0.45, 0))
	splash(landing, 22)
	ripple(landing)
	local float = fxParts[1]
	if float then
		local bang = Instance.new("BillboardGui")
		bang.Size = UDim2.fromOffset(56, 56)
		bang.StudsOffset = Vector3.new(0, 3, 0)
		bang.AlwaysOnTop = true
		local circle = Instance.new("TextLabel")
		circle.Size = UDim2.fromScale(1, 1)
		circle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		circle.Text = "!"
		circle.FontFace = Kit.Font.Black
		circle.TextScaled = true
		circle.TextColor3 = Color3.fromRGB(230, 50, 50)
		circle.Parent = bang
		Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)
		local scale = Instance.new("UIScale")
		scale.Scale = 0.2
		scale.Parent = circle
		bang.Parent = float
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- Minigame ------------------------------------------------------------------------
local function endMinigame()
	ContextActionService:UnbindAction("ReelHold")
	if minigame then
		minigame.Conn:Disconnect()
		minigame.Root:Destroy()
		minigame = nil
	end
end

local function reset()
	endMinigame()
	clearFx()
	state = "idle"
	token = nil
	holding = false
	updateHint()
end

local function cancel()
	if token then
		Remotes.Reel:FireServer(token, false)
	end
	reset()
end

local function startMinigame(difficulty: number)
	state = "reeling"
	updateHint()
	-- Space reels instead of jumping while the minigame is up
	ContextActionService:BindActionAtPriority("ReelHold", function(_, inputState)
		holding = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	local C, F, make, text = Kit.Color, Kit.Font, Kit.make, Kit.text
	local rod = RodData.ById[UI.Data and UI.Data.Rod or "Basic"] or RodData.ById.Basic

	local root = make("Frame", {
		Size = UDim2.fromOffset(150, 420),
		Position = UDim2.new(1, -40, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = C.Panel,
		Parent = UI.GetGui(),
	}, { Kit.corner(20), Kit.stroke(Color3.new(1, 1, 1), 2, 0.85) })
	local pop = make("UIScale", { Scale = 0.6, Parent = root })
	Kit.tween(pop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	text("REEL!", 26, F.Black, C.Gold, { Size = UDim2.new(1, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.fromOffset(0, 8), Parent = root })

	local track = make("Frame", {
		Size = UDim2.fromOffset(64, 310),
		Position = UDim2.fromOffset(20, 54),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Parent = root,
	}, { Kit.corner(14), Kit.gradient(Color3.fromRGB(110, 200, 255), Color3.fromRGB(20, 70, 150)) })

	local zoneSize = math.clamp(0.4 * rod.Control / (0.5 + difficulty * 0.5), 0.15, 0.6)
	local zone = make("Frame", {
		Size = UDim2.new(1, -8, zoneSize, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = C.Good,
		BackgroundTransparency = 0.2,
		Parent = track,
	}, { Kit.corner(10), Kit.stroke(Color3.new(1, 1, 1), 2, 0.3) })
	local fish = text("🐟", 30, F.Black, C.Text, { Size = UDim2.new(1, 0, 0, 34), AutomaticSize = Enum.AutomaticSize.None, AnchorPoint = Vector2.new(0, 0.5), Parent = track })

	local meter = make("Frame", { Size = UDim2.fromOffset(22, 310), Position = UDim2.fromOffset(100, 54), BackgroundColor3 = C.Bg, Parent = root }, { Kit.round() })
	local fill = make("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = Color3.new(1, 1, 1), Parent = meter }, {
		Kit.round(),
		Kit.gradient(C.Good, C.Gold),
	})
	text("Hold to reel", 14, F.Bold, C.Sub, { Size = UDim2.new(1, 0, 0, 20), AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.new(0, 0, 1, -40), Parent = root })

	-- 0 = bottom, 1 = top
	local zonePos, zoneVel = 0, 0
	local fishPos, fishTarget, fishTimer = 0.5, 0.5, 0
	local progress = 0.35
	local startedAt = os.clock()
	local myToken = token
	local trackX = track.Position

	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		zoneVel += (if holding then 1.9 else -1.5) * dt
		zoneVel = math.clamp(zoneVel, -0.9, 0.9)
		zonePos += zoneVel * dt
		if zonePos <= 0 then
			zonePos, zoneVel = 0, math.max(zoneVel, 0) * 0.3
		elseif zonePos >= 1 - zoneSize then
			zonePos, zoneVel = 1 - zoneSize, math.min(zoneVel, 0) * 0.3
		end

		fishTimer -= dt
		if fishTimer <= 0 then
			-- short hops, not jumps across the whole bar
			local hop = (0.12 + math.random() * 0.12 * difficulty) * (if math.random() < 0.5 then -1 else 1)
			fishTarget = math.clamp(fishPos + hop, 0.05, 0.95)
			fishTimer = (0.9 + math.random() * 1.4) / difficulty
		end
		local prev = fishPos
		fishPos += (fishTarget - fishPos) * math.min(1, dt * (0.4 + difficulty * 1.0))

		local inside = fishPos >= zonePos and fishPos <= zonePos + zoneSize
		local grace = os.clock() - startedAt < 1 -- no losing progress in the first second
		local change = if inside then 0.34 elseif grace then 0 else -0.1 * difficulty
		progress = math.clamp(progress + change * dt, 0, 1)

		zone.Position = UDim2.new(0, 4, 1 - zonePos, 0)
		fish.Position = UDim2.fromScale(0, 1 - fishPos)
		fish.Rotation = math.clamp((fishPos - prev) / math.max(dt, 1e-3) * -60, -35, 35)
		fill.Size = UDim2.fromScale(1, progress)
		zone.BackgroundColor3 = if inside then C.Good else C.Danger
		track.Position = if inside then trackX else trackX + UDim2.fromOffset(math.random(-2, 2), 0)

		if progress >= 1 or progress <= 0 then
			local success = progress >= 1
			endMinigame()
			if token == myToken then
				Remotes.Reel:FireServer(myToken, success)
			end
			clearFx()
			state = "idle"
			token = nil
			updateHint()
		end
	end)
	minigame = { Conn = conn, Root = root }
end

-- Casting -------------------------------------------------------------------------
local function mouseTarget()
	local mousePos = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = false
	local result = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	return result and result.Position
end

local function onActivated()
	if state == "idle" then
		local target = mouseTarget()
		if not target then
			return
		end
		state = "casting"
		local ok, result = Remotes.Cast:InvokeServer(target)
		if state ~= "casting" then
			-- Unequipped while the request was in flight.
			if ok then
				Remotes.Reel:FireServer(result, false)
			end
			return
		end
		if ok then
			token = result
			state = "waiting"
			updateHint()
			task.spawn(throwBobber, target, result)
		else
			state = "idle"
			UI.Notify(result, "error")
		end
	elseif state == "waiting" then
		cancel() -- reeled in before a bite
	end
end

local bound = setmetatable({}, { __mode = "k" })

local function bindTool(tool: Tool)
	-- Tools move between Backpack and character on every equip; bind once.
	if bound[tool] or not tool:GetAttribute("RodId") then
		return
	end
	bound[tool] = true
	tool.Equipped:Connect(function()
		currentTool = tool
		updateHint()
	end)
	tool.Activated:Connect(onActivated)
	tool.Unequipped:Connect(function()
		if currentTool == tool then
			cancel()
			currentTool = nil
			updateHint()
		end
	end)
	tool.AncestryChanged:Connect(function()
		if not tool.Parent and currentTool == tool then
			cancel()
			currentTool = nil
			updateHint()
		end
	end)
end

local function onCharacter(char: Model)
	reset()
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			bindTool(c)
		end
	end)
	for _, c in char:GetChildren() do
		if c:IsA("Tool") then
			bindTool(c)
		end
	end
end

function FishingController.Init(uiController)
	UI = uiController
	Kit = uiController.Kit

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	updateHint()

	Remotes.Bite.OnClientEvent:Connect(function(biteToken, difficulty)
		if biteToken ~= token or state ~= "waiting" then
			return
		end
		biteEffect()
		startMinigame(difficulty)
	end)

	Remotes.CatchResult.OnClientEvent:Connect(function(success, info)
		if success then
			UI.ShowCatch(info)
		else
			UI.Notify(info.Reason or "It got away...", "error")
			if state ~= "idle" then
				reset()
			end
		end
	end)

	local function isReelInput(input: InputObject)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonR2
			or input.KeyCode == Enum.KeyCode.ButtonA
	end
	UserInputService.InputBegan:Connect(function(input)
		if isReelInput(input) then
			holding = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isReelInput(input) then
			holding = false
		end
	end)
end

return FishingController
