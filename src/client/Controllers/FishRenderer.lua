-- Draws the creatures in the pit, the catches divers are carrying, and the fish in base
-- aquariums. Pit creatures follow the server's FishPath segments, so every client sees the
-- same thing without streaming positions. Models are built only near the camera.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureModels = require(Shared.CreatureModels)
local FishData = require(Shared.FishData)
local FishPath = require(Shared.FishPath)
local Remotes = require(Shared.Remotes)

local camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local FishRenderer = {}

local folder = Instance.new("Folder")
folder.Name = "ClientFish"
folder.Parent = workspace

local fish = {} -- [id] = entry
local tanks = {} -- [plot] = { entries }
local carried = {} -- [player] = entry
local targets = {} -- rebuilt every frame for SpearController
local tankRng = Random.new()

local BUILD_DISTANCE = 190 -- build a model when the camera gets this close
local DROP_DISTANCE = 240 -- and destroy it again past this
local TANK_DISTANCE = 150
local BUILDS_PER_FRAME = 3

local function sizeScale(sizeName)
	local s = FishData.SizeByName[sizeName or "Normal"]
	return if s then s.Scale else 1
end

local function decorate(rig, mutation)
	-- Sparkles / glow for mutated creatures
	local mut = mutation and FishData.MutationByName[mutation]
	if not mut then
		return
	end
	local anchor
	for _, g in rig.Groups do
		anchor = g.Parts[1]
		if anchor then
			break
		end
	end
	if not anchor then
		return
	end
	local color = mut.Glow or mut.Color or Color3.new(1, 1, 1)
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Rate = 6
	p.Lifetime = NumberRange.new(0.6, 1.1)
	p.Speed = NumberRange.new(0.5, 1.5)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Size = NumberSequence.new(math.clamp(rig.L * 0.12, 0.25, 1.2), 0)
	p.LightEmission = 1
	p.Color = if mut.Rainbow then ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 120, 255)),
	}) else ColorSequence.new(color)
	p.Parent = anchor
	if mut.Glow or mut.Material == "Neon" then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = math.clamp(rig.L * 2, 6, 24)
		light.Brightness = 1.5
		light.Parent = anchor
	end
end

local function newEntry(speciesId: string, opts)
	local species = FishData.ById[speciesId]
	return {
		SpeciesId = speciesId,
		Species = species,
		Opts = opts,
		Rig = nil,
		Dir = Vector3.new(0, 0, -1),
		Phase = math.random() * 6,
		Swim = 1,
		Cruise = species.Speed,
		TailRate = math.clamp(2.2 / math.sqrt(species.Look.L * (opts.Scale or 1)), 0.35, 1.4),
	}
end

local function buildRig(e)
	local rig = CreatureModels.Build(e.SpeciesId, e.Opts)
	decorate(rig, e.Opts.Mutation)
	rig.Model.Parent = folder
	e.Rig = rig
end

local function destroyRig(e)
	if e.Rig then
		e.Rig.Model:Destroy()
		e.Rig = nil
	end
end

local function eachPart(rig, fn)
	for _, g in rig.Groups do
		for _, p in g.Parts do
			fn(p)
		end
	end
end

-- Pit creatures ---------------------------------------------------------------------------
local function addFish(state)
	if fish[state.Id] then
		return
	end
	local e = newEntry(state.Species, { Scale = sizeScale(state.Size), Mutation = state.Mut })
	e.Id = state.Id
	e.Seg = state.Seg
	e.HP = state.HP
	e.MaxHP = state.MaxHP
	e.Kg = state.Kg
	e.Size = state.Size
	e.Mut = state.Mut
	fish[state.Id] = e
end

local function flash(e)
	if not e.Rig then
		return
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 255, 255)
	hl.OutlineColor = Color3.fromRGB(255, 70, 70)
	hl.FillTransparency = 0
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = e.Rig.Model
	hl.Parent = e.Rig.Model
	TweenService:Create(hl, TweenInfo.new(0.4), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	task.delay(0.45, function()
		hl:Destroy()
	end)
end

-- A little health bar over creatures that take more than one hit.
local function showHealth(e, hp)
	if not e.Rig then
		return
	end
	local body = e.Rig.Groups.body or e.Rig.Groups.seg0
	local anchor = body and body.Parts[1]
	if not anchor then
		return
	end
	local bb = e.HealthGui
	if not bb or not bb.Parent then
		bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(84, 16)
		bb.StudsOffsetWorldSpace = Vector3.new(0, e.Rig.L * 0.3 + 1.5, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.MaxDistance = 140
		bb.Adornee = anchor
		local back = Instance.new("Frame")
		back.Size = UDim2.fromScale(1, 1)
		back.BackgroundColor3 = Color3.fromRGB(22, 26, 48)
		back.Parent = bb
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = back
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = back
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = Color3.fromRGB(255, 80, 70)
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = back
		local c2 = Instance.new("UICorner")
		c2.CornerRadius = UDim.new(1, 0)
		c2.Parent = fill
		bb.Parent = anchor
		e.HealthGui = bb
		e.HealthFill = fill
	end
	TweenService:Create(e.HealthFill, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromScale(math.max(hp, 0) / math.max(e.MaxHP or 1, 1), 1) }):Play()
	local token = os.clock()
	e.HealthToken = token
	task.delay(4, function()
		if e.HealthToken == token and bb.Parent then
			bb:Destroy()
		end
	end)
end

local function updateFish(id, seg, hp)
	local e = fish[id]
	if not e then
		return
	end
	e.Seg = seg
	if hp < e.HP then
		flash(e)
		showHealth(e, hp)
		e.HurtUntil = os.clock() + 4
	end
	e.HP = hp
end

local function removeFish(id, catcherUserId)
	local e = fish[id]
	if not e or e.Removing then
		return
	end
	if not e.Rig or not e.Pos then
		destroyRig(e)
		fish[id] = nil
		return
	end
	flash(e)
	e.Removing = true
	local catcher = catcherUserId and Players:GetPlayerByUserId(catcherUserId)
	e.Catcher = catcher
	e.RemoveFrom = e.Pos
	e.RemoveT = 0
end

-- Carried catches -------------------------------------------------------------------------
local CARRY_LENGTH = 4.5 -- carried creatures are shrunk to about this length

local function setCarried(player: Player)
	local old = carried[player]
	if old then
		destroyRig(old)
		carried[player] = nil
	end
	local value = player:GetAttribute("Carrying")
	if type(value) ~= "string" or value == "" then
		return
	end
	local id, size, mut = string.match(value, "^([^|]+)|([^|]*)|(.*)$")
	local species = id and FishData.ById[id]
	if not species then
		return
	end
	local scale = math.min(sizeScale(size), CARRY_LENGTH / species.Look.L)
	local e = newEntry(id, { Scale = scale, Mutation = if mut ~= "" then mut else nil, Simple = true })
	e.Player = player
	buildRig(e)
	e.Born = os.clock()
	carried[player] = e
end

local function watchPlayer(player: Player)
	setCarried(player)
	player:GetAttributeChangedSignal("Carrying"):Connect(function()
		setCarried(player)
	end)
end

-- Aquarium fish ---------------------------------------------------------------------------
local function worldBox(part: BasePart, inset: number)
	local cf, s = part.CFrame, part.Size / 2
	local ext = Vector3.new(
		math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z,
		math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z,
		math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
	)
	local i = Vector3.one * inset
	return { Min = cf.Position - ext + i, Max = cf.Position + ext - i }
end

local function refreshTank(plot: Instance)
	for _, e in tanks[plot] or {} do
		destroyRig(e)
	end
	tanks[plot] = {}
	local water = plot:FindFirstChild("TankWater", true)
	local list = plot:GetAttribute("TankFish")
	if not water or type(list) ~= "string" or list == "" then
		return
	end
	local box = worldBox(water, 1)
	local maxLen = math.min(box.Max.Y - box.Min.Y, box.Max.Z - box.Min.Z, box.Max.X - box.Min.X) * 0.55
	for entry in string.gmatch(list, "[^,]+") do
		local id, size, mut = string.match(entry, "^([^|]+)|?([^|]*)|?(.*)$")
		local species = id and FishData.ById[id]
		if species then
			local scale = math.min(sizeScale(if size ~= "" then size else "Normal") * 1.2, maxLen / species.Look.L)
			local e = newEntry(id, { Scale = scale, Mutation = if mut and mut ~= "" then mut else nil, Simple = true })
			local len = species.Look.L * scale
			e.Box = box
			e.Margin = math.max(0.8, len * 0.55)
			e.Cruise = math.clamp(len * 0.6, 1.2, 3.5)
			local t = os.clock()
			e.Seg = FishPath.NewSegment(tankRng, box, FishPath.RandomPoint(tankRng, box, e.Margin), t, e.Cruise, e.Margin)
			e.NextRepath = t + tankRng:NextNumber(3, 6)
			table.insert(tanks[plot], e)
		end
	end
end

local function watchPlot(plot: Instance)
	refreshTank(plot)
	plot:GetAttributeChangedSignal("TankFish"):Connect(function()
		refreshTank(plot)
	end)
end

-- Animation -------------------------------------------------------------------------------
local function steer(e, pos: Vector3, vel: Vector3, dt: number)
	local speed = vel.Magnitude
	local want = if speed > 0.15 then vel / speed else e.Dir
	want = Vector3.new(want.X, math.clamp(want.Y, -0.45, 0.45), want.Z)
	if want.Magnitude < 1e-3 then
		want = e.Dir
	end
	local dir = e.Dir:Lerp(want.Unit, math.min(1, dt * 4))
	if dir.Magnitude > 1e-3 then
		e.Dir = dir.Unit
	end
	e.Swim = math.clamp(speed / math.max(e.Cruise, 0.1), 0.3, 2)
	e.Phase += dt * (4 + 6 * e.Swim) * e.TailRate
	e.Pos = pos
	e.Root = CFrame.lookAt(pos, pos + e.Dir)
end

local builds = 0
local function want(e, dist)
	if e.Rig then
		if dist > DROP_DISTANCE then
			destroyRig(e)
		end
	elseif dist < BUILD_DISTANCE and builds < BUILDS_PER_FRAME then
		builds += 1
		buildRig(e)
	end
	return e.Rig ~= nil
end

local parts, cframes = {}, {}

local function step(dt: number)
	dt = math.min(dt, 0.1)
	builds = 0
	local t = workspace:GetServerTimeNow()
	local camPos = camera.CFrame.Position
	table.clear(parts)
	table.clear(cframes)
	table.clear(targets)

	for id, e in fish do
		if e.Removing then
			-- Speared: whips over to the diver and shrinks into their grip
			e.RemoveT += dt / 0.35
			local a = math.min(e.RemoveT, 1)
			local root = e.Catcher and e.Catcher.Character and e.Catcher.Character:FindFirstChild("HumanoidRootPart")
			local to = if root and (root.Position - e.RemoveFrom).Magnitude < 150 then root.Position else e.RemoveFrom
			local pos = e.RemoveFrom:Lerp(to, a * a)
			e.Phase += dt * 40
			e.Root = CFrame.lookAt(pos, pos + e.Dir) * CFrame.Angles(0, 0, math.sin(e.Phase) * 0.6)
			if e.Rig then
				CreatureModels.Pose(e.Rig, e.Root, e.Phase, 2, parts, cframes)
				local fade = math.clamp((a - 0.5) * 2, 0, 1)
				eachPart(e.Rig, function(p)
					p.LocalTransparencyModifier = fade
				end)
			end
			if e.RemoveT >= 1 then
				destroyRig(e)
				fish[id] = nil
			end
		else
			local pos = FishPath.Position(e.Seg, t)
			local dist = (pos - camPos).Magnitude
			if want(e, dist) then
				steer(e, pos, FishPath.Velocity(e.Seg, t), dt)
				CreatureModels.Pose(e.Rig, e.Root, e.Phase, e.Swim, parts, cframes)
				local head, tail, radius = CreatureModels.Capsule(e.Rig, e.Root)
				table.insert(targets, { Id = id, Head = head, Tail = tail, Radius = radius, Entry = e })
			else
				e.Pos = pos
			end
		end
	end

	-- Catches being carried: held over the diver's back, thrashing
	for player, e in carried do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not player.Parent then
			destroyRig(e)
			carried[player] = nil
		elseif root and e.Rig then
			e.Phase += dt * 22
			local pop = math.min(1, (os.clock() - e.Born) / 0.25)
			local cf = root.CFrame * CFrame.new(0, 1.4 + 1.2 * pop, 1.6) * CFrame.Angles(0, math.pi / 2, 0)
				* CFrame.Angles(math.sin(e.Phase * 0.5) * 0.25, 0, math.sin(e.Phase * 0.35) * 0.3)
			CreatureModels.Pose(e.Rig, cf, e.Phase, 2, parts, cframes)
			-- don't draw your own catch over your face in first person
			local hide = if player == localPlayer and (camera.CFrame.Position - root.Position).Magnitude < 2.5 then 0.65 else 0
			if e.Hidden ~= hide then
				e.Hidden = hide
				eachPart(e.Rig, function(p)
					p.LocalTransparencyModifier = hide
				end)
			end
		end
	end

	local now = os.clock()
	for plot, list in tanks do
		if not plot.Parent then
			for _, e in list do
				destroyRig(e)
			end
			tanks[plot] = nil
			continue
		end
		for _, e in list do
			local center = (e.Box.Min + e.Box.Max) / 2
			local dist = (center - camPos).Magnitude
			if e.Rig and dist > TANK_DISTANCE + 40 then
				destroyRig(e)
			elseif not e.Rig and dist < TANK_DISTANCE and builds < BUILDS_PER_FRAME then
				builds += 1
				buildRig(e)
			end
			if e.Rig then
				if now >= e.NextRepath then
					e.Seg = FishPath.NewSegment(tankRng, e.Box, FishPath.Position(e.Seg, now), now, e.Cruise, e.Margin)
					e.NextRepath = now + tankRng:NextNumber(3, 6)
				end
				steer(e, FishPath.Position(e.Seg, now), FishPath.Velocity(e.Seg, now), dt)
				CreatureModels.Pose(e.Rig, e.Root, e.Phase, e.Swim, parts, cframes)
			end
		end
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- API used by the SpearController and UI ---------------------------------------------------
function FishRenderer.GetTargets()
	return targets
end

function FishRenderer.GetRoot(id: number): CFrame?
	local e = fish[id]
	return e and e.Root
end

function FishRenderer.Get(id: number)
	return fish[id]
end

-- The pit creature nearest to a point (for the tutorial / hints)
function FishRenderer.Nearest(p: Vector3)
	local best, bestD = nil, math.huge
	local t = workspace:GetServerTimeNow()
	for _, e in fish do
		if not e.Removing then
			local d = (FishPath.Position(e.Seg, t) - p).Magnitude
			if d < bestD then
				best, bestD = e, d
			end
		end
	end
	return best, bestD
end

function FishRenderer.Init()
	Remotes.FishSpawned.OnClientEvent:Connect(addFish)
	Remotes.FishUpdated.OnClientEvent:Connect(updateFish)
	Remotes.FishRemoved.OnClientEvent:Connect(removeFish)
	task.spawn(function()
		for _, state in Remotes.GetFish:InvokeServer() do
			addFish(state)
		end
	end)
	for _, plot in CollectionService:GetTagged(Config.PlotTag) do
		watchPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal(Config.PlotTag):Connect(watchPlot)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(p)
		local e = carried[p]
		if e then
			destroyRig(e)
			carried[p] = nil
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return FishRenderer
