-- Diving: the camera locks into first person while your head is underwater (third person
-- on land), Shift / the DASH button gives a burst of speed, divers trail bubbles, and the
-- camera gets a little roll while swimming plus shakes for the chase.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
local roll = 0
local listeners = {}

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

local function setFirstPerson(on: boolean)
	if on == DiveController.FirstPerson then
		return
	end
	DiveController.FirstPerson = on
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
	root.AssemblyLinearVelocity += camera.CFrame.LookVector * dashBase * 0.9
	TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = BASE_FOV + 10 }):Play()
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
	TweenService:Create(camera, TweenInfo.new(0.4), { FieldOfView = BASE_FOV }):Play()
end

local function bindDash(on: boolean)
	if on then
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
				e.Rate = if under then 3 else 0
			end
		end
	end
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
	else
		DiveController.Underwater = false
		setFirstPerson(false)
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

-- After the camera scripts: swim roll + shake
local function cameraFX(dt: number)
	local humanoid, _, root = charParts()
	local target = 0
	if humanoid and DiveController.FirstPerson then
		local lateral = camera.CFrame.RightVector:Dot(root.AssemblyLinearVelocity)
		target = math.clamp(-lateral / 30, -1, 1) * math.rad(4)
	end
	roll += (target - roll) * math.min(1, dt * 5)
	local cf = camera.CFrame * CFrame.Angles(0, 0, roll)
	local now = os.clock()
	if now < shakeUntil then
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
		if Audio then
			Audio.Play(if on then "Dive" else "Surface")
		end
		if not on and DiveController.Dashing then
			endDash()
		end
	end)
	player.CharacterAdded:Connect(function()
		DiveController.Dashing = false
		dashBase = nil
		camera.FieldOfView = BASE_FOV
	end)
end

return DiveController
