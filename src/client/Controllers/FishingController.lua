-- Cast -> wait for bite -> reel minigame.
-- Minigame: hold click / tap / Space to lift the green bar and keep the fish inside it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RodData = require(Shared.RodData)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local FishingController = {}

local UI
local state = "idle" -- idle | casting | waiting | reeling
local token = nil
local currentTool: Tool? = nil
local bobber: BasePart? = nil
local line: Beam? = nil
local holding = false
local minigame = nil

local function cleanupVisuals()
	if bobber then
		bobber:Destroy()
		bobber = nil
	end
	if line then
		line:Destroy()
		line = nil
	end
end

local function endMinigame()
	if minigame then
		minigame.Conn:Disconnect()
		minigame.Frame:Destroy()
		minigame = nil
	end
end

local function reset()
	endMinigame()
	cleanupVisuals()
	state = "idle"
	token = nil
	holding = false
end

local function cancel()
	if token then
		Remotes.Reel:FireServer(token, false)
	end
	reset()
end

local function makeBobber(pos: Vector3)
	cleanupVisuals()
	local b = Instance.new("Part")
	b.Name = "Bobber"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.new(0.6, 0.6, 0.6)
	b.Color = Color3.fromRGB(235, 60, 60)
	b.Material = Enum.Material.SmoothPlastic
	b.Anchored = true
	b.CanCollide = false
	b.CanQuery = false
	b.Position = pos + Vector3.new(0, 0.2, 0)
	b.Parent = workspace
	local att = Instance.new("Attachment")
	att.Parent = b
	bobber = b

	local tip = currentTool and currentTool:FindFirstChild("Handle") and currentTool.Handle:FindFirstChild("Tip")
	if tip then
		local beam = Instance.new("Beam")
		beam.Attachment0 = tip
		beam.Attachment1 = att
		beam.Width0 = 0.05
		beam.Width1 = 0.05
		beam.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
		beam.FaceCamera = true
		beam.CurveSize0 = -2
		beam.Parent = b
		line = beam
	end

	-- Gentle idle bob
	TweenService:Create(b, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = b.Position + Vector3.new(0, 0.15, 0),
	}):Play()
end

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

local function startMinigame(difficulty: number)
	state = "reeling"
	local rodId = UI.Data and UI.Data.Rod or "Basic"
	local rod = RodData.ById[rodId] or RodData.ById.Basic

	local gui = UI.GetGui()
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(90, 320)
	frame.Position = UDim2.new(1, -140, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Color3.fromRGB(28, 34, 48)
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 40, 1, -20)
	track.Position = UDim2.fromOffset(10, 10)
	track.BackgroundColor3 = Color3.fromRGB(40, 90, 150)
	track.ClipsDescendants = true
	track.Parent = frame
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 8)

	local zoneSize = math.clamp(0.28 * rod.Control / (0.6 + difficulty * 0.4), 0.12, 0.5)
	local zone = Instance.new("Frame")
	zone.Size = UDim2.fromScale(1, zoneSize)
	zone.AnchorPoint = Vector2.new(0, 1)
	zone.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
	zone.BackgroundTransparency = 0.25
	zone.Parent = track

	local fish = Instance.new("TextLabel")
	fish.Size = UDim2.new(1, 0, 0, 24)
	fish.AnchorPoint = Vector2.new(0, 0.5)
	fish.BackgroundTransparency = 1
	fish.Text = "><>"
	fish.Font = Enum.Font.FredokaOne
	fish.TextScaled = true
	fish.TextColor3 = Color3.fromRGB(255, 220, 90)
	fish.Parent = track

	local progressBg = Instance.new("Frame")
	progressBg.Size = UDim2.new(0, 16, 1, -20)
	progressBg.Position = UDim2.fromOffset(62, 10)
	progressBg.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	progressBg.Parent = frame
	Instance.new("UICorner", progressBg).CornerRadius = UDim.new(0, 6)
	local progressFill = Instance.new("Frame")
	progressFill.AnchorPoint = Vector2.new(0, 1)
	progressFill.Position = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	progressFill.Parent = progressBg
	Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 6)

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(0, 200, 0, 26)
	hint.Position = UDim2.new(0.5, 0, 0, -32)
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.BackgroundTransparency = 1
	hint.Text = "Hold click / tap / Space!"
	hint.Font = Enum.Font.FredokaOne
	hint.TextScaled = true
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextStrokeTransparency = 0.3
	hint.Parent = frame

	-- Positions are 0 (bottom) .. 1 (top)
	local zonePos, zoneVel = 0, 0
	local fishPos, fishTarget, fishTimer = 0.5, 0.5, 0
	local progress = 0.3
	local myToken = token

	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		-- Player bar physics
		zoneVel += (if holding then 2.6 else -2.2) * dt
		zoneVel = math.clamp(zoneVel, -1.4, 1.4)
		zonePos += zoneVel * dt
		if zonePos <= 0 then
			zonePos, zoneVel = 0, math.max(zoneVel, 0) * 0.3
		elseif zonePos >= 1 - zoneSize then
			zonePos, zoneVel = 1 - zoneSize, math.min(zoneVel, 0) * 0.3
		end

		-- Fish darts around more often / faster with difficulty
		fishTimer -= dt
		if fishTimer <= 0 then
			fishTarget = math.random()
			fishTimer = (0.5 + math.random() * 1.3) / difficulty
		end
		fishPos += (fishTarget - fishPos) * math.min(1, dt * (1.2 + difficulty * 1.3))

		local inside = fishPos >= zonePos and fishPos <= zonePos + zoneSize
		progress += (if inside then 0.28 else -0.2 * (0.7 + difficulty * 0.3)) * dt
		progress = math.clamp(progress, 0, 1)

		zone.Position = UDim2.fromScale(0, 1 - zonePos)
		fish.Position = UDim2.fromScale(0, 1 - fishPos)
		progressFill.Size = UDim2.fromScale(1, progress)
		zone.BackgroundColor3 = if inside then Color3.fromRGB(90, 220, 110) else Color3.fromRGB(200, 120, 90)

		if progress >= 1 or progress <= 0 then
			local success = progress >= 1
			endMinigame()
			if token == myToken then
				Remotes.Reel:FireServer(myToken, success)
			end
			cleanupVisuals()
			state = "idle"
			token = nil
		end
	end)
	minigame = { Conn = conn, Frame = frame }
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
			makeBobber(target)
		else
			state = "idle"
			UI.Notify(result, "error")
		end
	elseif state == "waiting" then
		-- Reeled in before a bite.
		cancel()
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
	end)
	tool.Activated:Connect(onActivated)
	tool.Unequipped:Connect(function()
		if currentTool == tool then
			cancel()
			currentTool = nil
		end
	end)
	tool.AncestryChanged:Connect(function()
		if not tool.Parent and currentTool == tool then
			cancel()
			currentTool = nil
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

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	Remotes.Bite.OnClientEvent:Connect(function(biteToken, difficulty)
		if biteToken ~= token or state ~= "waiting" then
			return
		end
		if bobber then
			-- Splash: dunk the bobber
			local p = bobber.Position
			bobber.Position = p - Vector3.new(0, 0.5, 0)
			local bang = Instance.new("BillboardGui")
			bang.Size = UDim2.fromOffset(60, 60)
			bang.StudsOffset = Vector3.new(0, 2.5, 0)
			bang.AlwaysOnTop = true
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundTransparency = 1
			t.Text = "!"
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = Color3.fromRGB(255, 220, 60)
			t.TextStrokeTransparency = 0
			t.Parent = bang
			bang.Parent = bobber
		end
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
