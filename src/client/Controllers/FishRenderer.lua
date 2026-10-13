-- Draws every fish in the pond (and the little ones in base aquariums) and animates them.
-- Pond fish follow the server's FishPath segments; aquarium fish wander on their own.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishData = require(Shared.FishData)
local FishPath = require(Shared.FishPath)
local Remotes = require(Shared.Remotes)
local FishModels = require(script.Parent.Parent:WaitForChild("FishModels"))

local camera = workspace.CurrentCamera

local FishRenderer = {}

local folder = Instance.new("Folder")
folder.Name = "ClientFish"
folder.Parent = workspace

local fish = {} -- [id] = entry
local tanks = {} -- [plot] = { entries }
local targets = {} -- rebuilt every frame for SpearController
local tankRng = Random.new()

local DRAW_DISTANCE = 420
local TANK_DISTANCE = 160

local function newEntry(speciesId: string, scale: number, simple: boolean?)
	local species = FishData.ById[speciesId]
	local rig = FishModels.Build(speciesId, scale, simple)
	rig.Model.Parent = folder
	return {
		Species = species,
		Rig = rig,
		Dir = Vector3.new(0, 0, -1),
		Phase = math.random() * 6,
		Swim = 1,
		Cruise = species.Speed,
		TailRate = math.clamp(2.2 / math.sqrt(rig.L), 0.35, 1.4),
	}
end

local function destroyEntry(e)
	if e.Rig then
		e.Rig.Model:Destroy()
		e.Rig = nil
	end
end

-- Pond fish ---------------------------------------------------------------------
local function addFish(state)
	if fish[state.Id] then
		return
	end
	local e = newEntry(state.Species, FishData.SizeScale(state.Species, state.Kg))
	e.Id = state.Id
	e.Seg = state.Seg
	e.HP = state.HP
	e.MaxHP = state.MaxHP
	e.Kg = state.Kg
	fish[state.Id] = e
end

local function flash(e)
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 80, 80)
	hl.OutlineColor = Color3.fromRGB(255, 255, 255)
	hl.FillTransparency = 0.2
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = e.Rig.Model
	hl.Parent = e.Rig.Model
	TweenService:Create(hl, TweenInfo.new(0.45), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	task.delay(0.5, function()
		hl:Destroy()
	end)
end

local function updateFish(id, seg, hp)
	local e = fish[id]
	if not e then
		return
	end
	e.Seg = seg
	if hp < e.HP and e.Rig then
		flash(e)
		e.HurtUntil = os.clock() + 4
	end
	e.HP = hp
end

local function removeFish(id, catcherUserId)
	local e = fish[id]
	if not e or e.Removing then
		return
	end
	if not e.Pos then
		-- never drawn (too far away): just drop it
		destroyEntry(e)
		fish[id] = nil
		return
	end
	e.Removing = true
	local catcher = catcherUserId and Players:GetPlayerByUserId(catcherUserId)
	local root = catcher and catcher.Character and catcher.Character:FindFirstChild("HumanoidRootPart")
	e.RemoveFrom = e.Pos
	e.RemoveTo = if root and e.Pos and (root.Position - e.Pos).Magnitude < 160 then root.Position else e.Pos
	e.RemoveT = 0
end

-- Aquarium fish ------------------------------------------------------------------
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
		destroyEntry(e)
	end
	tanks[plot] = {}
	local water = plot:FindFirstChild("TankWater", true)
	local list = plot:GetAttribute("TankFish")
	if not water or type(list) ~= "string" or list == "" then
		return
	end
	local box = worldBox(water, 0.6)
	for id in string.gmatch(list, "[^,]+") do
		local species = FishData.ById[id]
		if species then
			local scale = math.min(1, 2.4 / species.Look.L)
			local e = newEntry(id, scale, true)
			e.Box = box
			e.Cruise = 1.6
			local t = os.clock()
			e.Seg = FishPath.NewSegment(tankRng, box, FishPath.RandomPoint(tankRng, box, 0.8), t, e.Cruise, 0.8)
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

-- Animation -----------------------------------------------------------------------
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

local function step(dt: number)
	dt = math.min(dt, 0.1)
	local t = workspace:GetServerTimeNow()
	local camPos = camera.CFrame.Position
	local parts, cframes = {}, {}
	table.clear(targets)

	for id, e in fish do
		if e.Removing then
			-- Reeled in: glide to the catcher and fade away
			e.RemoveT += dt / 0.55
			local a = math.min(e.RemoveT, 1)
			local pos = e.RemoveFrom:Lerp(e.RemoveTo, a * a)
			e.Phase += dt * 30
			e.Root = CFrame.lookAt(pos, pos + e.Dir)
			if e.Rig then
				FishModels.Pose(e.Rig, e.Root, e.Phase, 2, parts, cframes)
				for _, it in e.Rig.Items do
					it.Part.Transparency = a
				end
			end
			if e.RemoveT >= 1 then
				destroyEntry(e)
				fish[id] = nil
			end
		elseif e.Rig then
			local pos = FishPath.Position(e.Seg, t)
			if (pos - camPos).Magnitude < DRAW_DISTANCE then
				steer(e, pos, FishPath.Velocity(e.Seg, t), dt)
				FishModels.Pose(e.Rig, e.Root, e.Phase, e.Swim, parts, cframes)
				local head, tail, radius = FishModels.Capsule(e.Rig, e.Root)
				table.insert(targets, { Id = id, Head = head, Tail = tail, Radius = radius, Entry = e })
			else
				e.Pos = pos
			end
		end
	end

	local now = os.clock()
	for plot, list in tanks do
		for _, e in list do
			if e.Rig and e.Box then
				local center = (e.Box.Min + e.Box.Max) / 2
				if (center - camPos).Magnitude < TANK_DISTANCE then
					if now >= e.NextRepath then
						e.Seg = FishPath.NewSegment(tankRng, e.Box, FishPath.Position(e.Seg, now), now, e.Cruise, 0.8)
						e.NextRepath = now + tankRng:NextNumber(3, 6)
					end
					steer(e, FishPath.Position(e.Seg, now), FishPath.Velocity(e.Seg, now), dt)
					FishModels.Pose(e.Rig, e.Root, e.Phase, e.Swim, parts, cframes)
				end
			end
		end
		if not plot.Parent then
			for _, e in list do
				destroyEntry(e)
			end
			tanks[plot] = nil
		end
	end

	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- API used by SpearController and the UI ---------------------------------------------
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

function FishRenderer.Init()
	Remotes.FishSpawned.OnClientEvent:Connect(addFish)
	Remotes.FishUpdated.OnClientEvent:Connect(updateFish)
	Remotes.FishRemoved.OnClientEvent:Connect(removeFish)
	task.spawn(function()
		for _, state in Remotes.GetFish:InvokeServer() do
			addFish(state)
		end
	end)
	for _, plot in CollectionService:GetTagged("Plot") do
		watchPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal("Plot"):Connect(watchPlot)
	RunService.RenderStepped:Connect(step)
end

return FishRenderer
