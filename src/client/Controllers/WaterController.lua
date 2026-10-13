-- Animated low-poly water: a grid of flat-shaded triangles whose corners ride three
-- overlapping waves. The surface is reshaped every other frame, and not at all while you're
-- deep underwater or far away (it can't be seen then).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Poly = require(Shared.Poly)
local Zones = require(Shared.Zones)

local WaterController = {}

local HALF = Zones.List[1].Half
local CELL = 24
local LEVEL = Zones.WaterLevel + 0.08 -- wave troughs stay just above Roblox's water surface
local SLICES = 2

local folder
local verts = {} -- [i][j] = { X, Z }
local tris = {} -- { a = {i, j}, b, c, w1, w2 }
local heights = {}
local N

local function wave(x: number, z: number, t: number): number
	return 0.5 * math.sin(0.11 * x + 1.25 * t) + 0.4 * math.sin(0.09 * z - 1.05 * t) + 0.22 * math.sin(0.17 * (x + z) + 1.9 * t)
end

local function build()
	folder = Instance.new("Folder")
	folder.Name = "ClientWater"
	folder.Parent = workspace
	N = math.floor(HALF * 2 / CELL + 0.5)
	local step = HALF * 2 / N
	for i = 0, N do
		verts[i] = {}
		heights[i] = {}
		for j = 0, N do
			verts[i][j] = { -HALF + i * step, -HALF + j * step }
			heights[i][j] = 0
		end
	end
	local rng = Random.new(5)
	local base = Color3.fromRGB(46, 176, 226)
	local function add(a, b, c)
		local col = Poly.Shade(base, rng:NextNumber(-0.06, 0.1))
		local props = { Color = col, Transparency = 0.42, Reflectance = 0.05 }
		local w1, w2 = Poly.NewWedge(props), Poly.NewWedge(props)
		w1.Parent, w2.Parent = folder, folder
		table.insert(tris, { a = a, b = b, c = c, w1 = w1, w2 = w2 })
	end
	for i = 0, N - 1 do
		for j = 0, N - 1 do
			if (i + j) % 2 == 0 then
				add({ i, j }, { i + 1, j }, { i + 1, j + 1 })
				add({ i, j }, { i + 1, j + 1 }, { i, j + 1 })
			else
				add({ i, j }, { i + 1, j }, { i, j + 1 })
				add({ i + 1, j }, { i + 1, j + 1 }, { i, j + 1 })
			end
		end
	end
	-- Foam line where the water meets the sand
	for s = 0, 3 do
		local cf = CFrame.Angles(0, s * math.pi / 2, 0)
		local foam = Instance.new("Part")
		foam.Name = "Foam"
		foam.Anchored = true
		foam.CanCollide = false
		foam.CanQuery = false
		foam.CanTouch = false
		foam.CastShadow = false
		foam.Material = Enum.Material.SmoothPlastic
		foam.Color = Color3.fromRGB(240, 250, 255)
		foam.Transparency = 0.25
		foam.Size = Vector3.new(HALF * 2, 0.3, 1.6)
		foam.CFrame = cf * CFrame.new(0, LEVEL + 0.35, HALF - 0.8)
		foam.Parent = folder
	end
end

local function point(v, t)
	local x, z = verts[v[1]][v[2]][1], verts[v[1]][v[2]][2]
	return Vector3.new(x, LEVEL + heights[v[1]][v[2]], z)
end

-- Every other frame the whole surface is reshaped at once (updating it in pieces left
-- thin cracks between neighbouring triangles).
local frame = 0
local function step(force: boolean?)
	frame += 1
	if not force and frame % SLICES ~= 0 then
		return
	end
	local t = os.clock()
	for i = 0, N do
		for j = 0, N do
			local v = verts[i][j]
			-- keep the outer edge flat so it meets the shore cleanly
			local edge = i == 0 or j == 0 or i == N or j == N
			-- waves only go up (0 .. ~0.9) so the dips never sink below the real water surface
			heights[i][j] = if edge then 0 else (wave(v[1], v[2], t) + 1.12) * 0.4
		end
	end
	local parts, cframes = {}, {}
	for _, tr in tris do
		local s1, cf1, s2, cf2 = Poly.Solve(point(tr.a), point(tr.b), point(tr.c), 0.05)
		if s1 then
			tr.w1.Size = s1
			tr.w2.Size = s2
			table.insert(parts, tr.w1)
			table.insert(cframes, cf1)
			table.insert(parts, tr.w2)
			table.insert(cframes, cf2)
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function WaterController.Init()
	build()
	-- Shape every triangle once before the first frame
	step(true)
	RunService.RenderStepped:Connect(function()
		-- skip the work while the surface can't be seen (deep underwater, or far away)
		local cam = workspace.CurrentCamera.CFrame.Position
		if cam.Y < Zones.WaterLevel - 35 or Vector3.new(cam.X, 0, cam.Z).Magnitude > HALF + 500 then
			return
		end
		step(false)
	end)
end

return WaterController
