-- Speargun: aiming, the character's aim pose and recoil, firing, the spear's flight
-- (with a line back to the gun), hit detection against fish, and the reticle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local FishPath = require(Shared.FishPath)
local GunData = require(Shared.GunData)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local SpearController = {}

local UI, Kit, Renderer
local gunTool: Tool? = nil
local gun = nil
local loaded = true
local reloadStart, reloadEnd = 0, 0
local aimPoint = Vector3.zero
local aimFish = nil
local recoil = 0
local reticle = {}

local spearFolder = Instance.new("Folder")
spearFolder.Name = "ClientSpears"
spearFolder.Parent = workspace

local STEEL = Color3.fromRGB(205, 210, 220)

-- Helpers ---------------------------------------------------------------------
local function worldParams()
	local ignore = { spearFolder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	local fishFolder = workspace:FindFirstChild("ClientFish")
	if fishFolder then
		table.insert(ignore, fishFolder)
	end
	local map = workspace:FindFirstChild("Map")
	local water = map and map:FindFirstChild("PolyWater")
	if water then
		table.insert(ignore, water)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

local function muzzleOf(char: Model?): Attachment?
	local tool = char and char:FindFirstChildOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	return handle and handle:FindFirstChild("Muzzle")
end

local function setLoadedVisual(visible: boolean)
	if not gunTool then
		return
	end
	for _, p in gunTool:GetDescendants() do
		if p:IsA("BasePart") and string.sub(p.Name, 1, 5) == "Spear" then
			p.LocalTransparencyModifier = if visible then 0 else 1
		end
	end
end

local function splash(pos: Vector3, amount: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = pos
	holder.Parent = spearFolder
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(205, 238, 255))
	e.LightEmission = 0.3
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.05) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Speed = NumberRange.new(5, 10)
	e.SpreadAngle = Vector2.new(50, 50)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Rate = 0
	e.Parent = holder
	e:Emit(amount)
	task.delay(1, function()
		holder:Destroy()
	end)
end

-- The flying spear: shaft + four-blade tip, pointing down -Z.
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
	-- The spear's CFrame is its tip; everything sits behind it (+Z).
	local shaft = piece("Part", Vector3.new(5.3, 0.1, 0.1), CFrame.new(0, 0, 3.2) * CFrame.Angles(0, math.rad(90), 0), Enum.PartType.Cylinder)
	local tz = 0.275
	piece("WedgePart", Vector3.new(0.04, 0.16, 0.55), CFrame.new(0, 0.08, tz))
	piece("WedgePart", Vector3.new(0.04, 0.16, 0.55), CFrame.new(0, -0.08, tz) * CFrame.Angles(0, 0, math.pi))
	piece("WedgePart", Vector3.new(0.04, 0.16, 0.55), CFrame.new(0.08, 0, tz) * CFrame.Angles(0, 0, math.rad(-90)))
	piece("WedgePart", Vector3.new(0.04, 0.16, 0.55), CFrame.new(-0.08, 0, tz) * CFrame.Angles(0, 0, math.rad(90)))
	local tail = Instance.new("Attachment")
	tail.Position = Vector3.new(-2.65, 0, 0) -- the shaft cylinder runs along its X axis; -X is the back end
	tail.Parent = shaft
	return pieces, tail
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
local function launch(origin: Vector3, dir: Vector3, gunInfo, mine: boolean, muzzle: Attachment?)
	local pieces, tail = buildSpear(gunInfo)
	local line
	if muzzle then
		line = Instance.new("Beam")
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
	local range = gunInfo and gunInfo.Range or 50
	local state, stuckId, stuckOffset, timer = "flying", nil, nil, 0
	local spearCF = CFrame.lookAt(origin, origin + dir)
	local retractFrom

	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		if state == "flying" then
			local speed = if pos.Y < Config.WaterLevel then Config.SpearSpeedWater else Config.SpearSpeed
			local stepLen = math.min(speed * dt, range - traveled)
			local nextPos = pos + dir * stepLen
			if pos.Y >= Config.WaterLevel and nextPos.Y < Config.WaterLevel then
				local a = (pos.Y - Config.WaterLevel) / math.max(pos.Y - nextPos.Y, 1e-3)
				splash(pos:Lerp(nextPos, a), 10)
			end
			local wall = workspace:Raycast(pos, nextPos - pos, params)
			local wallDist = if wall then (wall.Position - pos).Magnitude else math.huge
			local best, bestDist = nil, wallDist
			for _, target in Renderer.GetTargets() do
				local d, s = FishPath.SegmentDistance(pos, nextPos, target.Head, target.Tail)
				if d <= target.Radius + 0.35 and s * stepLen < bestDist then
					best, bestDist = target, s * stepLen
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
				if mine then
					Remotes.SpearHit:FireServer(best.Id, workspace:GetServerTimeNow())
					SpearController.OnHit(best)
				end
			elseif wall then
				spearCF = CFrame.lookAt(wall.Position, wall.Position + dir) * CFrame.new(0, 0, -0.4)
				state, timer = "stuck", 0
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
			if timer > 0.7 then
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

-- Reticle -----------------------------------------------------------------------------
local function buildReticle()
	local C, F, make, text = Kit.Color, Kit.Font, Kit.make, Kit.text
	local gui = make("ScreenGui", { Name = "Reticle", IgnoreGuiInset = true, DisplayOrder = 10, ResetOnSpawn = false, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	local root = make("Frame", { Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = gui })
	local ring = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root }, { Kit.round() })
	local ringStroke = make("UIStroke", { Color = C.Text, Thickness = 2, Transparency = 0.15, Parent = ring })
	make("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Text, Parent = root }, { Kit.round() })
	for i = 0, 3 do
		local horizontal = i % 2 == 0
		local sign = if i < 2 then -1 else 1
		make("Frame", {
			Size = if horizontal then UDim2.fromOffset(8, 2) else UDim2.fromOffset(2, 8),
			Position = UDim2.new(0.5, if horizontal then sign * 30 else 0, 0.5, if horizontal then 0 else sign * 30),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.Text,
			BorderSizePixel = 0,
			Parent = root,
		})
	end
	local hitmark = make("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = root })
	Kit.icon("close", 30, C.Gold, { Parent = hitmark })
	local reloadBar = make("Frame", { Size = UDim2.fromOffset(40, 4), Position = UDim2.new(0.5, 0, 1, 10), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.3, Parent = root }, { Kit.round() })
	local reloadFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, Parent = reloadBar }, { Kit.round() })
	local info = make("Frame", { Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, 22), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.2, Visible = false, Parent = root }, {
		Kit.round(), Kit.pad(0, 10), Kit.list(Enum.FillDirection.Horizontal, 6, nil, Enum.VerticalAlignment.Center),
	})
	local infoName = text("", 13, F.Black, C.Text, { LayoutOrder = 1, Parent = info })
	local infoHP = text("", 12, F.Black, C.Danger, { LayoutOrder = 2, Parent = info })
	reticle = { Gui = gui, Root = root, Stroke = ringStroke, Hit = hitmark, ReloadBar = reloadBar, ReloadFill = reloadFill, Info = info, InfoName = infoName, InfoHP = infoHP }
end

function SpearController.OnHit(target)
	reticle.Hit.Visible = true
	reticle.Hit.Rotation = 0
	Kit.tween(reticle.Hit, 0.25, { Rotation = 90 })
	task.delay(0.25, function()
		reticle.Hit.Visible = false
	end)
end

-- Aiming and pose -------------------------------------------------------------------------
local function updateAim()
	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local far = 500
	local wall = workspace:Raycast(ray.Origin, ray.Direction * far, worldParams())
	local wallDist = if wall then (wall.Position - ray.Origin).Magnitude else far
	aimFish = nil
	local bestDist = wallDist
	for _, target in Renderer.GetTargets() do
		local d, s = FishPath.SegmentDistance(ray.Origin, ray.Origin + ray.Direction * far, target.Head, target.Tail)
		if d <= target.Radius + 0.8 and s * far < bestDist then
			aimFish, bestDist = target, s * far
		end
	end
	aimPoint = ray.Origin + ray.Direction * bestDist
end

local function updateHint()
	if not UI then
		return
	end
	if not gunTool then
		UI.SetHint("Press 1 to hold your speargun")
	elseif camera.CFrame.Position.Y > Config.WaterLevel then
		UI.SetHint("Dive into the pond and click a fish to fire")
	else
		UI.SetHint(nil)
	end
end

local menuOpen = false

local function busy(humanoid: Humanoid): boolean
	local state = humanoid:GetState()
	return humanoid.Sit or state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Dead
end

local function onRender(dt: number)
	if not gunTool then
		reticle.Gui.Enabled = false
		updateHint()
		return
	end
	-- With a menu open, give the normal cursor back and pause aiming.
	menuOpen = UI.IsPanelOpen()
	UserInputService.MouseIconEnabled = menuOpen
	if menuOpen then
		reticle.Gui.Enabled = false
		return
	end
	updateAim()
	updateHint()
	local C = Kit.Color
	reticle.Gui.Enabled = true
	reticle.Root.Position = UDim2.fromOffset(mouse.X, mouse.Y + GuiService:GetGuiInset().Y)
	local now = os.clock()
	local progress = if loaded then 1 else math.clamp((now - reloadStart) / math.max(reloadEnd - reloadStart, 0.01), 0, 1)
	reticle.ReloadBar.Visible = not loaded
	reticle.ReloadFill.Size = UDim2.fromScale(progress, 1)
	if aimFish and aimFish.Entry then
		local e = aimFish.Entry
		local rarity = FishData.GetRarity(e.Species.Id)
		reticle.Stroke.Color = rarity.Color
		reticle.Info.Visible = true
		reticle.InfoName.Text = e.Species.Id
		reticle.InfoName.TextColor3 = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.35)
		reticle.InfoHP.Text = string.rep("●", math.max(e.HP or 1, 0)) .. string.rep("○", math.max((e.MaxHP or 1) - (e.HP or 1), 0))
	else
		reticle.Stroke.Color = C.Text
		reticle.Info.Visible = false
	end
	if not loaded and now >= reloadEnd then
		loaded = true
		setLoadedVisual(true)
	end
	recoil = math.max(0, recoil - dt * 6)

	-- Face where you're aiming (like shift-lock) so the gun points at the target.
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 and not busy(humanoid) then
		local flat = Vector3.new(aimPoint.X - root.Position.X, 0, aimPoint.Z - root.Position.Z)
		if flat.Magnitude > 1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end
end

-- Arms: right arm points the gun at the target, left arm supports it (or pulls the
-- bands back while reloading), with a kick on every shot. Runs after animations.
local function onStepped()
	if not gunTool or menuOpen then
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
		local p = math.clamp((os.clock() - reloadStart) / math.max(reloadEnd - reloadStart, 0.01), 0, 1)
		pull = math.sin(p * math.pi)
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

-- Firing -------------------------------------------------------------------------------------
local function fire()
	if not gunTool or not gun or not loaded then
		return
	end
	local muzzle = muzzleOf(player.Character)
	if not muzzle then
		return
	end
	local origin = muzzle.WorldPosition
	local dir = aimPoint - origin
	if dir.Magnitude < 2 then
		dir = camera.CFrame.LookVector
	end
	dir = dir.Unit
	loaded = false
	reloadStart = os.clock()
	reloadEnd = reloadStart + gun.Reload
	recoil = 1
	setLoadedVisual(false)
	Remotes.Shoot:FireServer(origin, dir)
	launch(origin, dir, gun, true, muzzle)
	-- small camera punch
	local fov = camera.FieldOfView
	camera.FieldOfView = fov - 3
	Kit.tween(camera, 0.25, { FieldOfView = fov })
end

local function bindTool(tool: Tool)
	if not tool:GetAttribute("GunId") or tool:GetAttribute("Bound") then
		return
	end
	tool:SetAttribute("Bound", true)
	tool.Equipped:Connect(function()
		gunTool = tool
		gun = GunData.ById[tool:GetAttribute("GunId")]
		UserInputService.MouseIconEnabled = false
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.AutoRotate = false
		end
		setLoadedVisual(loaded)
	end)
	tool.Unequipped:Connect(function()
		if gunTool == tool then
			gunTool, gun = nil, nil
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

function SpearController.Init(uiController, renderer)
	UI = uiController
	Kit = uiController.Kit
	Renderer = renderer
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
		launch(origin, dir, GunData.ById[gunId], false, muzzleOf(shooter.Character))
	end)
	Remotes.CatchResult.OnClientEvent:Connect(function(success, info)
		if success then
			UI.ShowCatch(info)
		end
	end)
end

return SpearController
