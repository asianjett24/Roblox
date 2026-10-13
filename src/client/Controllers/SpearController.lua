-- Speargun: aiming (with a little lead on moving targets), firing, the spear's flight with
-- a line back to the gun, hit detection, the reticle, and the first-person viewmodel
-- (gun + gloved arms, sway, recoil and a band-pulling reload) used underwater.
-- Above water the character holds the gun in third person and turns to face the aim.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local FishPath = require(Shared.FishPath)
local GunData = require(Shared.GunData)
local GunModels = require(Shared.GunModels)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local SpearController = {}

local UI, Kit, Renderer, Dive, Audio
local gunTool: Tool? = nil
local gun = nil
local loaded = true
local reloadStart, reloadEnd = 0, 0
local aimPoint = Vector3.zero
local aimDir = Vector3.new(0, 0, -1)
local aimFish = nil
local recoil = 0
local reticle = {}
local menuOpen = false
local toolHidden = false

local spearFolder = Instance.new("Folder")
spearFolder.Name = "ClientSpears"
spearFolder.Parent = workspace

local STEEL = Color3.fromRGB(205, 210, 220)
local WATER = Zones.WaterLevel

-- Helpers -------------------------------------------------------------------------------------
local function worldParams()
	local ignore = { spearFolder, camera }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, name in { "ClientFish", "ClientGuardians", "ClientWater" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function toolMuzzle(char: Model?): Attachment?
	local tool = char and char:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	return handle and handle:FindFirstChild("Muzzle")
end

local function isCarrying(): boolean
	local v = player:GetAttribute("Carrying")
	return type(v) == "string" and v ~= ""
end

local function setToolHidden(hidden: boolean)
	if not gunTool or hidden == toolHidden then
		return
	end
	toolHidden = hidden
	for _, p in gunTool:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

local function setThirdPersonSpear(visible: boolean)
	if not gunTool then
		return
	end
	for _, p in gunTool:GetDescendants() do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 5) == "Spear" then
			p.LocalTransparencyModifier = if visible and not toolHidden then 0 else 1
		end
	end
end

local function burst(pos: Vector3, amount: number, color: Color3, speed: number?)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = pos
	holder.Parent = spearFolder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0.5
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.7)
	e.Speed = NumberRange.new((speed or 8) * 0.6, speed or 8)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.Parent = holder
	e:Emit(amount)
	task.delay(1.2, function()
		holder:Destroy()
	end)
end

-- The flying spear: shaft + four-blade tip, pointing down -Z. Its CFrame is the tip.
local function buildSpear(gunInfo)
	local color = if gunInfo and gunInfo.Glow then gunInfo.Trim else STEEL
	local pieces = {}
	local function piece(class, size, offset, shape)
		local p = Instance.new(class)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Metal
		p.Color = color
		p.Size = size
		if shape then
			p.Shape = shape
		end
		p.Parent = spearFolder
		table.insert(pieces, { Part = p, Offset = offset })
		return p
	end
	local shaft = piece("Part", Vector3.new(5.3, 0.1, 0.1), CFrame.new(0, 0, 3.2) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder)
	local tz = 0.275
	piece("WedgePart", Vector3.new(0.04, 0.16, 0.55), CFrame.new(0, 0.08, tz))
	piece("WedgePart", Vector3.new(0.04, 0.16, 0.55), CFrame.new(0, -0.08, tz) * CFrame.Angles(0, 0, math.pi))
	piece("WedgePart", Vector3.new(0.04, 0.16, 0.55), CFrame.new(0.08, 0, tz) * CFrame.Angles(0, 0, math.rad(-90)))
	piece("WedgePart", Vector3.new(0.04, 0.16, 0.55), CFrame.new(-0.08, 0, tz) * CFrame.Angles(0, 0, math.rad(90)))
	local tail = Instance.new("Attachment")
	tail.Position = Vector3.new(-2.65, 0, 0) -- the cylinder runs along its X axis; -X is the back end
	tail.Parent = shaft
	-- bubble trail
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Color = ColorSequence.new(Color3.fromRGB(220, 245, 255))
	trail.Size = NumberSequence.new(0.12, 0.25)
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Lifetime = NumberRange.new(0.4, 0.8)
	trail.Speed = NumberRange.new(0.5, 1.5)
	trail.Rate = 40
	trail.Acceleration = Vector3.new(0, 3, 0)
	trail.Parent = tail
	return pieces, tail, trail
end

local function placeSpear(pieces, cf: CFrame)
	local parts, cfs = {}, {}
	for _, it in pieces do
		table.insert(parts, it.Part)
		table.insert(cfs, cf * it.Offset)
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Fires a spear. mine = this player's own shot (does hit detection and tells the server).
-- rayStart: where hit testing begins on the first frame (the camera for your own first-person
-- shots, so a fish between your face and the muzzle still gets hit).
local function launch(origin: Vector3, dir: Vector3, gunInfo, mine: boolean, muzzle: Attachment?, rayStart: Vector3?)
	local pieces, tail, trail = buildSpear(gunInfo)
	if muzzle then
		local line = Instance.new("Beam")
		line.Attachment0 = muzzle
		line.Attachment1 = tail
		line.Width0 = 0.04
		line.Width1 = 0.04
		line.Color = ColorSequence.new(Color3.fromRGB(240, 240, 240))
		line.Transparency = NumberSequence.new(0.25)
		line.FaceCamera = true
		line.CurveSize0 = 0.6
		line.Parent = tail
	end

	local params = worldParams()
	local pos, traveled = origin, 0
	local testFrom = rayStart
	local range = gunInfo and gunInfo.Range or 50
	local state, stuckId, stuckOffset, timer = "flying", nil, nil, 0
	local spearCF = CFrame.lookAt(origin, origin + dir)
	local retractFrom

	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		if state == "flying" then
			local speed = if pos.Y < WATER then Config.SpearSpeedWater else Config.SpearSpeed
			local stepLen = math.min(speed * dt, range - traveled)
			local nextPos = pos + dir * stepLen
			if pos.Y >= WATER and nextPos.Y < WATER then
				local a = (pos.Y - WATER) / math.max(pos.Y - nextPos.Y, 1e-3)
				burst(pos:Lerp(nextPos, a), 12, Color3.fromRGB(210, 240, 255), 10)
			end
			local from = testFrom or pos
			testFrom = nil
			local wall = workspace:Raycast(pos, nextPos - pos, params)
			local wallDist = if wall then (wall.Position - pos).Magnitude else math.huge
			local best, bestDist = nil, wallDist
			local span = (nextPos - from).Magnitude
			local lead = (pos - from).Magnitude -- extra distance tested behind the spear (first frame only)
			for _, target in Renderer.GetTargets() do
				local d, s = FishPath.SegmentDistance(from, nextPos, target.Head, target.Tail)
				if d <= target.Radius + 0.45 and s * span - lead < bestDist then
					best, bestDist = target, math.max(0, s * span - lead)
				end
			end
			if best then
				local at = pos + dir * bestDist
				spearCF = CFrame.lookAt(at, at + dir)
				local root = Renderer.GetRoot(best.Id)
				if root then
					stuckId, stuckOffset = best.Id, root:ToObjectSpace(spearCF * CFrame.new(0, 0, -0.6))
				end
				state, timer = "stuck", 0
				trail.Enabled = false
				local rarity = FishData.GetRarity(best.Entry.SpeciesId)
				burst(at, 16, rarity.Color:Lerp(Color3.new(1, 1, 1), 0.3), 12)
				if mine then
					Remotes.SpearHit:FireServer(best.Id, workspace:GetServerTimeNow())
					SpearController.OnHit(best)
				end
			elseif wall then
				spearCF = CFrame.lookAt(wall.Position, wall.Position + dir) * CFrame.new(0, 0, -0.4)
				state, timer = "stuck", 0
				trail.Enabled = false
				burst(wall.Position, 6, Color3.fromRGB(200, 190, 170), 5)
			else
				pos = nextPos
				traveled += stepLen
				spearCF = CFrame.lookAt(pos, pos + dir)
				if traveled >= range - 1e-3 then
					state, timer = "stuck", 0.35
				end
			end
		elseif state == "stuck" then
			timer += dt
			if stuckId then
				local root = Renderer.GetRoot(stuckId)
				if root then
					spearCF = root * stuckOffset
				end
			end
			if timer > 0.6 then
				state, timer, retractFrom = "retract", 0, spearCF.Position
			end
		else
			timer += dt / 0.3
			local home = if muzzle and muzzle.Parent then muzzle.WorldPosition else origin
			local a = math.min(timer, 1)
			local p = retractFrom:Lerp(home, a * a)
			spearCF = CFrame.lookAt(p, p + dir)
			if timer >= 1 then
				conn:Disconnect()
				for _, it in pieces do
					it.Part:Destroy()
				end
				return
			end
		end
		placeSpear(pieces, spearCF)
	end)
	placeSpear(pieces, spearCF)
end

-- First-person viewmodel ------------------------------------------------------------------------
local VM_SCALE = 0.72
local SUIT = Color3.fromRGB(30, 34, 48)
local GLOVE = Color3.fromRGB(46, 52, 70)
local CUFF = Color3.fromRGB(40, 200, 255)

local vm = nil -- { Model, Gun, Muzzle, Spears, R = {forearm, hand, cuff}, L = {...} }
local vmState = { Raise = 0, SwayX = 0, SwayY = 0, Bob = 0, LastLook = nil }

local function vmPart(parent, size, color, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function destroyViewmodel()
	if vm then
		vm.Model:Destroy()
		vm = nil
	end
end

local function buildViewmodel(gunInfo)
	destroyViewmodel()
	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	local g = GunModels.Build(gunInfo, false)
	g.Parent = model
	pcall(function()
		g:ScaleTo(VM_SCALE)
	end)
	local spears = {}
	for _, p in g:GetDescendants() do
		if p:IsA("BasePart") then
			p.CastShadow = false
			if string.sub(p.Name, 1, 5) == "Spear" then
				table.insert(spears, p)
			end
		end
	end
	local function arm()
		return {
			Forearm = vmPart(model, Vector3.new(0.5, 0.5, 2), SUIT),
			Cuff = vmPart(model, Vector3.new(0.56, 0.56, 0.16), CUFF, Enum.Material.Neon),
			Hand = vmPart(model, Vector3.new(0.4, 0.46, 0.5), GLOVE),
			Thumb = vmPart(model, Vector3.new(0.16, 0.16, 0.32), GLOVE),
		}
	end
	vm = {
		Model = model,
		Gun = g,
		Muzzle = g.Handle:FindFirstChild("Muzzle"),
		Spears = spears,
		R = arm(),
		L = arm(),
		SpearShown = true,
	}
	vmState.Raise = 0
end

local function setVmSpear(visible: boolean)
	if vm and vm.SpearShown ~= visible then
		vm.SpearShown = visible
		for _, p in vm.Spears do
			p.LocalTransparencyModifier = if visible then 0 else 1
		end
	end
end

-- Places a forearm from elbow to wrist, then the hand and cuff.
local function poseArm(a, wrist: Vector3, elbow: Vector3, handCF: CFrame, parts, cfs)
	local len = (wrist - elbow).Magnitude
	a.Forearm.Size = Vector3.new(0.5, 0.5, len)
	local fore = CFrame.lookAt((wrist + elbow) / 2, wrist)
	table.insert(parts, a.Forearm)
	table.insert(cfs, fore)
	table.insert(parts, a.Cuff)
	table.insert(cfs, fore * CFrame.new(0, 0, -len / 2 + 0.12))
	table.insert(parts, a.Hand)
	table.insert(cfs, handCF)
	table.insert(parts, a.Thumb)
	table.insert(cfs, handCF * CFrame.new(-0.2, 0.12, -0.18) * CFrame.Angles(0, 0.4, 0))
end

local function reloadProgress(): number
	if loaded then
		return 1
	end
	return math.clamp((os.clock() - reloadStart) / math.max(reloadEnd - reloadStart, 0.01), 0, 1)
end

local function updateViewmodel(dt: number)
	if not vm then
		return
	end
	local show = Dive.FirstPerson and gunTool ~= nil
	if not show then
		if vm.Model.Parent then
			vm.Model.Parent = nil
		end
		vmState.Raise = 0
		return
	end
	if not vm.Model.Parent then
		vm.Model.Parent = camera
	end
	local cam = camera.CFrame
	-- sway: the gun lags behind camera turns
	local look = cam.LookVector
	local last = vmState.LastLook or look
	vmState.LastLook = look
	local d = cam:VectorToObjectSpace(last)
	local k = 1 / math.max(dt, 1 / 240) * 0.012
	vmState.SwayX += (math.clamp(d.X * k, -0.25, 0.25) - vmState.SwayX) * math.min(1, dt * 9)
	vmState.SwayY += (math.clamp(d.Y * k, -0.2, 0.2) - vmState.SwayY) * math.min(1, dt * 9)
	-- bob while swimming, slow breathing when still
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local speed = if root then root.AssemblyLinearVelocity.Magnitude else 0
	vmState.Bob += dt * (1.6 + speed * 0.32)
	local bobAmp = 0.015 + math.min(speed / 20, 1.4) * 0.04
	vmState.Raise = math.min(1, vmState.Raise + dt * 4)
	local raise = 1 - (1 - vmState.Raise) ^ 3
	local kick = recoil * recoil

	local gripCF = cam
		* CFrame.new(vmState.SwayX * 0.6, vmState.SwayY * 0.6, 0)
		* CFrame.new(0.95, -1.08 - (1 - raise) * 1.4 + math.sin(vmState.Bob) * bobAmp, -1.85 + kick * 0.45)
		* CFrame.Angles(math.rad(1.5) + kick * 0.2 + vmState.SwayY * 0.4, math.rad(2.5) - vmState.SwayX * 0.5, math.cos(vmState.Bob * 0.5) * bobAmp * 0.6 - vmState.SwayX * 0.3)
	vm.Gun:PivotTo(gripCF)

	local parts, cfs = {}, {}
	local s = VM_SCALE
	-- right hand wraps the pistol grip
	local rHand = gripCF * CFrame.new(0.06, -0.02, 0.02)
	poseArm(vm.R, (rHand * CFrame.new(0.05, -0.1, 0.35)).Position, (cam * CFrame.new(1.55, -2.4, -0.2)).Position, rHand, parts, cfs)
	-- left hand: under the barrel, or pulling the bands back while reloading
	local p = reloadProgress()
	local support = Vector3.new(0, 0.12 * s, -1.75 * s)
	local front = Vector3.new(0, 0.95 * s, -3.75 * s)
	local notch = Vector3.new(0, 1.05 * s, -1.25 * s)
	local lLocal
	if p < 0.3 then
		lLocal = support:Lerp(front, math.sin(p / 0.3 * math.pi / 2))
	elseif p < 0.75 then
		local a = (p - 0.3) / 0.45
		lLocal = front:Lerp(notch, a * a * (3 - 2 * a))
	else
		lLocal = notch:Lerp(support, (p - 0.75) / 0.25)
	end
	setVmSpear(p >= 0.72)
	local lHand = gripCF * CFrame.new(lLocal) * CFrame.Angles(0, 0, math.rad(-90))
	poseArm(vm.L, (lHand * CFrame.new(0.3, 0, 0.3)).Position, (cam * CFrame.new(-1.1, -2.5, -0.3)).Position, lHand, parts, cfs)
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Reticle ------------------------------------------------------------------------------------------
local function buildReticle()
	local C, F, make, text = Kit.Color, Kit.Font, Kit.make, Kit.text
	local gui = make("ScreenGui", { Name = "Reticle", IgnoreGuiInset = true, DisplayOrder = 4, ResetOnSpawn = false, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	local root = make("Frame", { Size = UDim2.fromOffset(48, 48), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	local scale = make("UIScale", { Parent = root })
	local ring = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root }, { Kit.round() })
	make("UIStroke", { Color = C.Ink, Thickness = 5, Transparency = 0.35, Parent = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root }, { Kit.round() }) })
	local ringStroke = make("UIStroke", { Color = C.Text, Thickness = 2.5, Parent = ring })
	make("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Text, Parent = root }, { Kit.round(), Kit.outline(1.5) })
	local ticks = {}
	for i = 0, 3 do
		local horizontal = i % 2 == 0
		local sign = if i < 2 then -1 else 1
		ticks[i] = make("Frame", {
			Size = if horizontal then UDim2.fromOffset(10, 3) else UDim2.fromOffset(3, 10),
			Position = UDim2.new(0.5, if horizontal then sign * 34 else 0, 0.5, if horizontal then 0 else sign * 34),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.Text,
			BorderSizePixel = 0,
			Parent = root,
		}, { Kit.outline(1) })
	end
	local hitmark = make("Frame", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = root })
	Kit.icon("close", 34, C.Gold, { Parent = hitmark })
	local reloadBar = make("Frame", { Size = UDim2.fromOffset(46, 7), Position = UDim2.new(0.5, 0, 1, 12), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.2, Parent = root }, { Kit.round(), Kit.outline(1.5) })
	local reloadFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, Parent = reloadBar }, { Kit.round() })
	local info = make("Frame", { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, 26), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = root }, {
		Kit.round(), Kit.pad(0, 12), Kit.outline(2.5), Kit.list(Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center),
	})
	local infoGrad = make("UIGradient", { Rotation = 90, Parent = info })
	local infoName = text("", 16, F.Title, C.Text, { LayoutOrder = 1, Parent = info })
	local pips = make("Frame", { Size = UDim2.fromOffset(0, 12), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = 2, Parent = info }, {
		Kit.list(Enum.FillDirection.Horizontal, 3, nil, Enum.VerticalAlignment.Center),
	})
	local pipList = {}
	for i = 1, 6 do
		pipList[i] = make("Frame", { Size = UDim2.fromOffset(10, 10), BackgroundColor3 = C.Danger, LayoutOrder = i, Parent = pips }, { Kit.round(), Kit.outline(1.5) })
	end
	local blocked = make("Frame", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = root })
	Kit.icon("depth", 40, C.Gold, { Rotation = 180, Parent = blocked })
	reticle = {
		Gui = gui, Root = root, Scale = scale, Ring = ring, Stroke = ringStroke, Ticks = ticks, Hit = hitmark, Blocked = blocked,
		ReloadBar = reloadBar, ReloadFill = reloadFill, Info = info, InfoGrad = infoGrad, InfoName = infoName, Pips = pipList,
	}
end

function SpearController.OnHit(target)
	reticle.Hit.Visible = true
	reticle.Hit.Rotation = -30
	reticle.Scale.Scale = 1.5
	Kit.tween(reticle.Scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.tween(reticle.Hit, 0.25, { Rotation = 0 }, Enum.EasingStyle.Back)
	task.delay(0.3, function()
		reticle.Hit.Visible = false
	end)
	if Audio then
		Audio.Play("Hit")
	end
	Dive.Shake(0.25, 0.15)
end

-- Aiming ----------------------------------------------------------------------------------------------
local function updateAim()
	local ray
	if Dive.FirstPerson then
		local vp = camera.ViewportSize
		ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)
	else
		ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	end
	local far = 500
	local wall = workspace:Raycast(ray.Origin, ray.Direction * far, worldParams())
	local wallDist = if wall then (wall.Position - ray.Origin).Magnitude else far
	aimFish = nil
	local bestDist = wallDist
	for _, target in Renderer.GetTargets() do
		local d, s = FishPath.SegmentDistance(ray.Origin, ray.Origin + ray.Direction * far, target.Head, target.Tail)
		local slack = 0.8 + s * far * 0.012 -- a little more forgiving further away
		if d <= target.Radius + slack and s * far < bestDist then
			aimFish, bestDist = target, s * far
		end
	end
	aimPoint = ray.Origin + ray.Direction * bestDist
	aimDir = ray.Direction
end

-- Where to shoot from, and the direction, leading a moving target a little.
local function shotFrom(): (Vector3?, Attachment?)
	if Dive.FirstPerson and vm and vm.Muzzle then
		return vm.Muzzle.WorldPosition, vm.Muzzle
	end
	local m = toolMuzzle(player.Character)
	if m then
		return m.WorldPosition, m
	end
	return nil, nil
end

local function leadDirection(origin: Vector3): Vector3
	local target = aimPoint
	if aimFish and aimFish.Entry and aimFish.Entry.Seg then
		local e = aimFish.Entry
		local now = workspace:GetServerTimeNow()
		local mid = (aimFish.Head + aimFish.Tail) / 2
		local travel = (mid - origin).Magnitude / Config.SpearSpeedWater
		local future = FishPath.Position(e.Seg, now + travel) - FishPath.Position(e.Seg, now)
		-- keep the point the player actually aimed at on the body, moved forward in time
		local onBody = aimPoint
		target = onBody + future
	end
	local dir = target - origin
	if dir.Magnitude < 2 then
		dir = aimDir
	end
	return dir.Unit
end

local function updateHint()
	if not UI or SpearController.HintLocked then
		return
	end
	local inWater = Dive.Underwater
	if isCarrying() then
		UI.SetHint(if inWater then "SWIM UP! Get out of the water to bank your catch!" else nil)
	elseif not gunTool then
		UI.SetHint(if UserInputService.TouchEnabled then "Tap the speargun below to hold it" else "Press 1 to hold your speargun")
	elseif not inWater and not Dive.FirstPerson then
		UI.SetHint("Jump in the water and dive down to hunt!")
	else
		UI.SetHint(nil)
	end
end

local function busy(humanoid: Humanoid): boolean
	local state = humanoid:GetState()
	return humanoid.Sit or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Dead
		or state == Enum.HumanoidStateType.Swimming
end

local function onRender(dt: number)
	updateHint()
	updateViewmodel(dt)
	setToolHidden(Dive.FirstPerson and gunTool ~= nil)
	if not gunTool then
		reticle.Gui.Enabled = false
		return
	end
	menuOpen = UI.IsPanelOpen()
	if menuOpen then
		reticle.Gui.Enabled = false
		UserInputService.MouseIconEnabled = true
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.AutoRotate = true
		end
		return
	end
	UserInputService.MouseIconEnabled = false
	updateAim()
	local C = Kit.Color
	reticle.Gui.Enabled = true
	if Dive.FirstPerson then
		local vp = camera.ViewportSize
		reticle.Root.Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2)
	else
		reticle.Root.Position = UDim2.fromOffset(mouse.X, mouse.Y + game:GetService("GuiService"):GetGuiInset().Y)
	end
	local now = os.clock()
	local progress = reloadProgress()
	reticle.ReloadBar.Visible = not loaded
	reticle.ReloadFill.Size = UDim2.fromScale(progress, 1)
	local carrying = isCarrying()
	reticle.Blocked.Visible = carrying
	reticle.Ring.Visible = not carrying
	if aimFish and aimFish.Entry and not carrying then
		local e = aimFish.Entry
		local rarity = FishData.GetRarity(e.SpeciesId)
		reticle.Stroke.Color = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.2)
		reticle.Info.Visible = true
		reticle.InfoName.Text = FishData.FullName(e.SpeciesId, e.Size, e.Mut)
		reticle.InfoGrad.Color = ColorSequence.new(rarity.Color:Lerp(Color3.new(1, 1, 1), 0.1), rarity.Color:Lerp(Color3.new(0, 0, 0), 0.25))
		for i, pip in reticle.Pips do
			pip.Visible = i <= (e.MaxHP or 1)
			pip.BackgroundColor3 = if i <= (e.HP or 1) then C.Danger else C.Ink
		end
		for _, t in reticle.Ticks do
			t.BackgroundColor3 = rarity.Color
		end
	else
		reticle.Stroke.Color = C.Text
		reticle.Info.Visible = false
		for _, t in reticle.Ticks do
			t.BackgroundColor3 = C.Text
		end
	end
	if not loaded and now >= reloadEnd then
		loaded = true
		setThirdPersonSpear(true)
		if Audio then
			Audio.Play("Reload")
		end
	end
	recoil = math.max(0, recoil - dt * 5)

	-- On land, turn to face where you're aiming so the gun points at it.
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 and not Dive.FirstPerson and not busy(humanoid) then
		humanoid.AutoRotate = false
		local flat = Vector3.new(aimPoint.X - root.Position.X, 0, aimPoint.Z - root.Position.Z)
		if flat.Magnitude > 1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	elseif humanoid then
		humanoid.AutoRotate = true
	end
end

-- Third-person arms: right arm points the gun at the target, left arm supports it.
-- Only on land; swimming keeps the normal swim animation.
local function onStepped()
	if not gunTool or menuOpen or Dive.FirstPerson then
		return
	end
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not humanoid or busy(humanoid) then
		return
	end
	local upper = char:FindFirstChild("UpperTorso")
	local rArm = char:FindFirstChild("RightUpperArm")
	local lArm = char:FindFirstChild("LeftUpperArm")
	local rs = rArm and rArm:FindFirstChild("RightShoulder")
	local ls = lArm and lArm:FindFirstChild("LeftShoulder")
	if not (upper and rs and ls) then
		return -- R6 avatars keep the default hold pose
	end
	local shoulder = upper.CFrame * rs.C0.Position
	local dir = aimPoint - shoulder
	if dir.Magnitude < 1e-3 then
		return
	end
	local localDir = upper.CFrame:VectorToObjectSpace(dir.Unit)
	local pitch = math.asin(math.clamp(localDir.Y, -1, 1))
	local kick = recoil * recoil * 0.55
	rs.Transform = CFrame.Angles(math.rad(90) + pitch + kick, 0, 0)
	local pull = 0
	if not loaded then
		pull = math.sin(reloadProgress() * math.pi)
	end
	ls.Transform = CFrame.Angles(0, math.rad(-38) - pull * 0.5, 0) * CFrame.Angles(math.rad(80) + pitch * 0.9 + kick * 0.6 - pull * 0.5, 0, 0)
	local re = char:FindFirstChild("RightLowerArm") and char.RightLowerArm:FindFirstChild("RightElbow")
	local le = char:FindFirstChild("LeftLowerArm") and char.LeftLowerArm:FindFirstChild("LeftElbow")
	if re then
		re.Transform = CFrame.Angles(math.rad(8), 0, 0)
	end
	if le then
		le.Transform = CFrame.Angles(math.rad(25) + pull * 0.9, 0, 0)
	end
end

-- Firing ------------------------------------------------------------------------------------------------
local function fire()
	if not gunTool or not gun or menuOpen then
		return
	end
	if isCarrying() then
		UI.Notify("You're carrying a catch! Swim up to bank it first.", "error")
		if Audio then
			Audio.Play("Error")
		end
		return
	end
	if not loaded then
		return
	end
	local origin, muzzle = shotFrom()
	if not origin then
		return
	end
	updateAim()
	local dir = leadDirection(origin)
	loaded = false
	reloadStart = os.clock()
	reloadEnd = reloadStart + gun.Reload
	recoil = 1
	setThirdPersonSpear(false)
	setVmSpear(false)
	Remotes.Shoot:FireServer(origin, dir)
	launch(origin, dir, gun, true, muzzle, if Dive.FirstPerson then camera.CFrame.Position else nil)
	if Audio then
		Audio.Play("Fire")
	end
	Dive.Shake(0.12, 0.1)
	-- camera punch
	local fov = camera.FieldOfView
	camera.FieldOfView = fov - 2.5
	Kit.tween(camera, 0.25, { FieldOfView = fov })
	if origin.Y < WATER then
		burst(origin, 8, Color3.fromRGB(220, 245, 255), 4)
	end
end

local function bindTool(tool: Tool)
	if not tool:GetAttribute("GunId") or tool:GetAttribute("Bound") then
		return
	end
	tool:SetAttribute("Bound", true)
	tool.Equipped:Connect(function()
		gunTool = tool
		toolHidden = false
		gun = GunData.ById[tool:GetAttribute("GunId")]
		buildViewmodel(gun)
		setThirdPersonSpear(loaded)
		setVmSpear(loaded)
	end)
	tool.Unequipped:Connect(function()
		if gunTool == tool then
			setToolHidden(false)
			gunTool, gun = nil, nil
			toolHidden = false
			destroyViewmodel()
			UserInputService.MouseIconEnabled = true
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.AutoRotate = true
			end
		end
	end)
	tool.Activated:Connect(fire)
end

local function onCharacter(char: Model)
	gunTool, gun = nil, nil
	loaded = true
	toolHidden = false
	destroyViewmodel()
	UserInputService.MouseIconEnabled = true
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			bindTool(c)
		end
	end)
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			bindTool(c)
		end
	end)
	for _, c in backpack:GetChildren() do
		if c:IsA("Tool") then
			bindTool(c)
		end
	end
end

function SpearController.HasGun(): boolean
	return gunTool ~= nil
end

function SpearController.Init(uiController, renderer, dive, audio)
	UI = uiController
	Kit = uiController.Kit
	Renderer = renderer
	Dive = dive
	Audio = audio
	buildReticle()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService.RenderStepped:Connect(onRender)
	RunService.Stepped:Connect(onStepped)
	Remotes.SpearFired.OnClientEvent:Connect(function(shooter: Player, origin: Vector3, dir: Vector3, gunId: string)
		if shooter == player then
			return
		end
		launch(origin, dir, GunData.ById[gunId], false, toolMuzzle(shooter.Character))
	end)
end

return SpearController
