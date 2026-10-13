-- Diving: the camera locks into first person while your head is underwater (third person
-- on land), Shift / the DASH button gives a burst of speed, divers trail bubbles, and the
-- camera shakes for the chase. Diving also takes out your speargun for you.
-- Underwater you swim with smooth acceleration and a short glide, where you look (W goes
-- where the camera points), Space swims up and Ctrl / C swims down. Near the surface normal
-- Roblox swimming takes over again so you can climb out.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Zones = require(Shared.Zones)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local DiveController = {}
DiveController.FirstPerson = false
DiveController.Underwater = false
DiveController.DashCharge = 1 -- 0..1, 1 = ready
DiveController.Dashing = false

local Audio
local BASE_FOV = 70
local dashUntil, dashReadyAt = 0, 0
local dashBase = nil
local shakeAmp, shakeUntil, shakeSeed = 0, 0, 0
local listeners = {}
local swimVel = Vector3.zero
local swimDir = Vector3.zero -- the direction you're pressing (dash goes this way)
local swimming = false
local SWIM_ACCEL, SWIM_GLIDE = 7, 2.6 -- how fast you reach full speed, and how slowly you coast to a stop
local fov = { Speed = 0, Dash = 0, Punch = 0 } -- extra field of view: swim speed, dash, kicks (spear fire)

local function charParts()
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local head = char and char:FindFirstChild("Head")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and head and root then
		return humanoid, head, root
	end
	return nil
end

function DiveController.OnChange(fn)
	table.insert(listeners, fn)
end

-- A quick water-coloured wash that hides the camera cut when you go under or come up.
local wash
local function washScreen(color: Color3, from: number, time: number)
	if not wash then
		local gui = Instance.new("ScreenGui")
		gui.Name = "DiveWash"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 2
		gui.Parent = player:WaitForChild("PlayerGui")
		wash = Instance.new("Frame")
		wash.Size = UDim2.fromScale(1, 1)
		wash.BorderSizePixel = 0
		wash.BackgroundTransparency = 1
		wash.Parent = gui
	end
	wash.BackgroundColor3 = color
	wash.BackgroundTransparency = from
	TweenService:Create(wash, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

local function setFirstPerson(on: boolean)
	if on == DiveController.FirstPerson then
		return
	end
	DiveController.FirstPerson = on
	if on then
		washScreen(Color3.fromRGB(40, 140, 200), 0.15, 0.5)
	else
		washScreen(Color3.fromRGB(215, 240, 255), 0.35, 0.4)
	end
	if on then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		-- push the camera back out to a normal third-person distance
		player.CameraMinZoomDistance = 12
		task.spawn(function()
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			player.CameraMinZoomDistance = 0.5
		end)
	end
	for _, fn in listeners do
		task.spawn(fn, on)
	end
end

-- Camera shake (the chase uses this). Strength ~0.1 .. 1.
function DiveController.Shake(strength: number, duration: number)
	if strength >= shakeAmp or os.clock() > shakeUntil then
		shakeAmp = strength
	end
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

-- A short field-of-view kick (negative = zoom in), e.g. when firing.
function DiveController.Punch(amount: number)
	fov.Punch += amount
end

-- A shove (a guardian's bite): carried into the swim so it isn't cancelled out.
function DiveController.Knock(velocity: Vector3)
	swimVel = velocity
end

-- Dash ----------------------------------------------------------------------------------------
local function dash()
	local humanoid, _, root = charParts()
	if not humanoid or not DiveController.Underwater then
		return
	end
	local now = os.clock()
	if now < dashReadyAt then
		return
	end
	dashReadyAt = now + Config.Dash.Cooldown
	dashUntil = now + Config.Dash.Duration
	dashBase = humanoid.WalkSpeed
	DiveController.Dashing = true
	humanoid.WalkSpeed = dashBase * Config.Dash.Multiplier
	-- dash where you're steering (A/D + Shift sidesteps), or straight ahead
	local dir = if swimDir.Magnitude > 0.2 then swimDir.Unit else camera.CFrame.LookVector
	root.AssemblyLinearVelocity += dir * dashBase * 0.9
	swimVel += dir * dashBase * 1.1
	if Audio then
		Audio.Play("Dash")
	end
	-- burst of bubbles
	local head = player.Character and player.Character:FindFirstChild("Head")
	local att = head and head:FindFirstChild("DiveBubbles")
	local emitter = att and att:FindFirstChildOfClass("ParticleEmitter")
	if emitter then
		emitter:Emit(18)
	end
end

local function endDash()
	DiveController.Dashing = false
	local humanoid = charParts()
	if humanoid and dashBase and math.abs(humanoid.WalkSpeed - dashBase * Config.Dash.Multiplier) < 0.01 then
		humanoid.WalkSpeed = dashBase
	end
	dashBase = nil
end

local touchDown = false -- the DOWN touch button (phones)

local function bindDash(on: boolean)
	if on then
		ContextActionService:BindAction("SwimDown", function(_, state)
			touchDown = state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change
			return Enum.ContextActionResult.Pass
		end, true)
		ContextActionService:SetTitle("SwimDown", "DOWN")
		ContextActionService:SetPosition("SwimDown", UDim2.new(1, -250, 1, -110))
		ContextActionService:BindAction("DiveDash", function(_, state)
			if state == Enum.UserInputState.Begin then
				dash()
			end
			return Enum.ContextActionResult.Sink
		end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
		ContextActionService:SetTitle("DiveDash", "DASH")
		ContextActionService:SetPosition("DiveDash", UDim2.new(1, -170, 1, -150))
	else
		ContextActionService:UnbindAction("DiveDash")
		ContextActionService:UnbindAction("SwimDown")
		touchDown = false
	end
end

-- Bubbles on every diver's head --------------------------------------------------------------------
local function bubbleEmitter(head: BasePart)
	if head:FindFirstChild("DiveBubbles") then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "DiveBubbles"
	att.Position = Vector3.new(0, 0.2, -0.5)
	att.Parent = head
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	e.LightEmission = 0.4
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.3) })
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(25, 25)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, 4, 0)
	e.Rate = 0
	e.Parent = att
end

local function updateBubbles()
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local head = char and char:FindFirstChild("Head")
		if head then
			bubbleEmitter(head)
			local att = head:FindFirstChild("DiveBubbles")
			local e = att and att:FindFirstChildOfClass("ParticleEmitter")
			if e then
				local under = Zones.InWater(head.Position + Vector3.new(0, 0.6, 0))
				local fast = if p == player and swimming then math.min(swimVel.Magnitude, 40) * 0.35 else 0
				e.Rate = if under then 3 + fast else 0
			end
		end
	end
end

-- Smooth swimming ---------------------------------------------------------------------------------
local function swimMover(root: BasePart)
	local lv = root:FindFirstChild("SwimMover")
	if lv then
		return lv
	end
	local att = root:FindFirstChild("SwimAttachment") or Instance.new("Attachment")
	att.Name = "SwimAttachment"
	att.Parent = root
	lv = Instance.new("LinearVelocity")
	lv.Name = "SwimMover"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	lv.Enabled = false
	lv.Parent = root
	return lv
end

local function stopSwim(root: BasePart?)
	swimming = false
	local lv = root and root:FindFirstChild("SwimMover")
	if lv then
		lv.Enabled = false
	end
end

local function held(...): boolean
	for _, key in { ... } do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function swimStep(dt: number, humanoid: Humanoid, head: BasePart, root: BasePart)
	-- only while fully under (the surface and climbing out use normal physics)
	local inPit = Zones.InWater(Vector3.new(head.Position.X, Zones.WaterLevel - 1, head.Position.Z))
	local submerged = inPit and head.Position.Y < Zones.WaterLevel - 1.1
	if not submerged or humanoid.Sit or humanoid.PlatformStand then
		if swimming then
			stopSwim(root)
		end
		swimDir = Vector3.zero
		-- duck dive: Ctrl / C at the surface pushes you under
		if inPit and not humanoid.Sit and head.Position.Y < Zones.WaterLevel + 1.5 and held(Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonL2) then
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, math.min(v.Y, -14), v.Z)
		end
		return
	end
	if not swimming then
		swimming = true
		swimVel = root.AssemblyLinearVelocity
	end
	-- the move keys / thumbstick, turned to follow the camera's pitch
	local cf = camera.CFrame
	local look = cf.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-flat.Z, 0, flat.X)
	local move = humanoid.MoveDirection
	local dir = look * move:Dot(flat) + right * move:Dot(right)
	if humanoid.Jump or held(Enum.KeyCode.Space, Enum.KeyCode.ButtonA) then
		dir += Vector3.new(0, 1, 0)
	end
	if touchDown or held(Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonL2) then
		dir -= Vector3.new(0, 1, 0)
	end
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end
	swimDir = dir
	local target = dir * humanoid.WalkSpeed
	local rate = if target.Magnitude >= swimVel.Magnitude then SWIM_ACCEL else SWIM_GLIDE
	swimVel = swimVel:Lerp(target, 1 - math.exp(-rate * dt))
	local lv = swimMover(root)
	lv.MaxForce = root.AssemblyMass * 600
	lv.VectorVelocity = swimVel
	lv.Enabled = true
end

-- Per frame -------------------------------------------------------------------------------------
local bubbleTimer = 0
local function step(dt: number)
	local humanoid, head, root = charParts()
	if humanoid then
		local y = head.Position.Y
		local inPit = Zones.InWater(Vector3.new(head.Position.X, Zones.WaterLevel - 1, head.Position.Z))
		local under = inPit and y < Zones.WaterLevel - 0.4
		DiveController.Underwater = under
		if DiveController.FirstPerson then
			if not inPit or y > Zones.WaterLevel - 0.3 then
				setFirstPerson(false)
			end
		elseif inPit and y < Zones.WaterLevel - 1.6 then
			setFirstPerson(true)
		end
		swimStep(dt, humanoid, head, root)
	else
		DiveController.Underwater = false
		setFirstPerson(false)
		swimming = false
	end

	local now = os.clock()
	if DiveController.Dashing and now >= dashUntil then
		endDash()
	end
	DiveController.DashCharge = math.clamp(1 - (dashReadyAt - now) / Config.Dash.Cooldown, 0, 1)

	bubbleTimer += dt
	if bubbleTimer > 0.5 then
		bubbleTimer = 0
		updateBubbles()
	end
end

-- After the camera scripts: camera shake (chase, hits)
local function cameraFX(dt: number)
	local now = os.clock()
	-- field of view: wider the faster you swim, wider still while dashing, plus kicks
	local humanoid = charParts()
	local speedK = if swimming and humanoid and humanoid.WalkSpeed > 0 then math.clamp(swimVel.Magnitude / humanoid.WalkSpeed, 0, 1.6) else 0
	fov.Speed += (speedK * 5 - fov.Speed) * math.min(1, dt * 4)
	fov.Dash += ((if DiveController.Dashing then 9 else 0) - fov.Dash) * math.min(1, dt * (if DiveController.Dashing then 10 else 3))
	fov.Punch *= math.exp(-dt * 12)
	camera.FieldOfView = BASE_FOV + fov.Speed + fov.Dash + fov.Punch
	if now >= shakeUntil then
		return
	end
	local cf = camera.CFrame
	do
		shakeSeed += dt * 30
		local a = shakeAmp * math.clamp((shakeUntil - now) / 0.3, 0, 1)
		cf *= CFrame.Angles(math.noise(shakeSeed, 0) * a * 0.05, math.noise(0, shakeSeed) * a * 0.05, 0)
			+ Vector3.new(math.noise(shakeSeed, 7) * a * 0.3, math.noise(7, shakeSeed) * a * 0.3, 0)
	end
	camera.CFrame = cf
end

function DiveController.Init(audio)
	Audio = audio
	BASE_FOV = camera.FieldOfView
	player.CameraMaxZoomDistance = math.max(player.CameraMaxZoomDistance, 40)
	RunService.RenderStepped:Connect(step)
	RunService:BindToRenderStep("DiveCameraFX", Enum.RenderPriority.Camera.Value + 2, cameraFX)
	DiveController.OnChange(function(on)
		bindDash(on)
		-- hold the speargun automatically when you dive
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if on and humanoid and not char:FindFirstChildOfClass("Tool") then
			local backpack = player:FindFirstChild("Backpack")
			local tool = backpack and backpack:FindFirstChildOfClass("Tool")
			if tool then
				humanoid:EquipTool(tool)
			end
		end
		if Audio then
			Audio.Play(if on then "Dive" else "Surface")
		end
		if not on and DiveController.Dashing then
			endDash()
		end
	end)
	player.CharacterAdded:Connect(function()
		swimming = false
		swimVel = Vector3.zero
		DiveController.Dashing = false
		dashBase = nil
		camera.FieldOfView = BASE_FOV
		fov.Speed, fov.Dash, fov.Punch = 0, 0, 0
	end)
end

return DiveController
