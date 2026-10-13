-- BuildMap_v4.lua
-- Stud-brick island, castle walls, deep pond, 8 bases with matching docks, 4 public piers,
-- rod shop + fish market. Everything is tagged so the game scripts find it automatically.
--
-- HOW TO RUN: View > Command Bar, paste this whole file in, press Enter.
-- WARNING: terrain:Clear() wipes terrain, and the old "Map" folder is replaced.

local CollectionService = game:GetService("CollectionService")

local terrain = workspace.Terrain
terrain:Clear()
terrain.WaterTransparency = 1
terrain.WaterReflectance = 0
terrain.WaterWaveSize = 0
terrain.WaterColor = Color3.fromRGB(40, 120, 200)

for _, name in ipairs({ "Map", "Plots" }) do
	local old = workspace:FindFirstChild(name)
	if old then old:Destroy() end
end
-- Old default baseplate / spawns would fight with ours
for _, c in ipairs(workspace:GetChildren()) do
	if c:IsA("SpawnLocation") or c.Name == "Baseplate" then c:Destroy() end
end

local map = Instance.new("Folder")
map.Name = "Map"
map.Parent = workspace

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or map
	return f
end
local fGround, fWalls, fWater = folder("Ground"), folder("Walls"), folder("PolyWater")
local fBases, fDocks, fDecor, fUnder = folder("Bases"), folder("PublicDocks"), folder("Decor"), folder("Underwater")
local fTown = folder("Town")

-- Palette
local GRASS1 = Color3.fromRGB(75, 151, 75)
local GRASS2 = Color3.fromRGB(88, 165, 85)
local SAND   = Color3.fromRGB(215, 197, 154)
local PATH   = Color3.fromRGB(190, 170, 130)
local WALL   = Color3.fromRGB(163, 162, 165)
local WALLD  = Color3.fromRGB(125, 124, 130)
local WOOD   = Color3.fromRGB(150, 110, 70)
local WOODD  = Color3.fromRGB(105, 75, 48)
local PLATE  = Color3.fromRGB(184, 172, 150)
local SMOOTH = Enum.SurfaceType.Smooth

-- Settings (studs)
local HALF = 300
local BASE_X, BASE_Z, BASE_SIZE = 85, 215, 60
local DOCK_Z, DOCK_LEN = 140, 90
local WALL_H, WALL_T = 36, 8

local tiers = {
	{ top = 0,    bottom = -50,  half = 120 },
	{ top = -50,  bottom = -150, half = 100 },
	{ top = -150, bottom = -250, half = 80  },
	{ top = -250, bottom = -300, half = 60  },
}

-- Helpers ---------------------------------------------------------------
local function mk(name, size, cf, color, material, topSurface, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.Plastic
	p.TopSurface = topSurface or Enum.SurfaceType.Studs
	p.BottomSurface = SMOOTH
	p.Parent = parent or map
	return p
end

local function deco(p) -- non-solid decoration that mouse clicks pass through
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

local function ring(name, a, b, top, bottom, color, parent)
	local h, y, m, t = top - bottom, (top + bottom) / 2, (a + b) / 2, b - a
	mk(name .. "_N", Vector3.new(2 * b, h, t), CFrame.new(0, y, m), color, nil, nil, parent)
	mk(name .. "_S", Vector3.new(2 * b, h, t), CFrame.new(0, y, -m), color, nil, nil, parent)
	mk(name .. "_E", Vector3.new(t, h, 2 * a), CFrame.new(m, y, 0), color, nil, nil, parent)
	mk(name .. "_W", Vector3.new(t, h, 2 * a), CFrame.new(-m, y, 0), color, nil, nil, parent)
end

local function billboard(adornee, text, offsetY, w, h, maxDist, color)
	local g = Instance.new("BillboardGui")
	g.Adornee = adornee
	g.Size = UDim2.fromOffset(w or 140, h or 40)
	g.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	g.MaxDistance = maxDist or 200
	g.Parent = adornee
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.Parent = g
	return g
end

local function light(part, range, color, brightness)
	local pl = Instance.new("PointLight")
	pl.Range = range
	pl.Brightness = brightness or 1.5
	pl.Color = color
	pl.Shadows = false
	pl.Parent = part
end

local function lamp(cf, parent, height)
	height = height or 7
	mk("LampPost", Vector3.new(0.8, height, 0.8), cf * CFrame.new(0, height / 2, 0), WOODD, nil, SMOOTH, parent)
	mk("LampCap", Vector3.new(2.6, 0.6, 2.6), cf * CFrame.new(0, height + 2.3, 0), WOODD, nil, SMOOTH, parent)
	local b = mk("Lamp", Vector3.new(1.8, 1.8, 1.8), cf * CFrame.new(0, height + 1, 0),
		Color3.fromRGB(255, 225, 150), Enum.Material.Neon, SMOOTH, parent)
	light(b, 28, Color3.fromRGB(255, 225, 170))
	return b
end

local function crate(cf, parent, s)
	s = s or 3
	local c = mk("Crate", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), WOOD, Enum.Material.WoodPlanks, SMOOTH, parent)
	return c
end

local function barrel(cf, parent)
	local b = Instance.new("Part")
	b.Name = "Barrel"
	b.Shape = Enum.PartType.Cylinder
	b.Size = Vector3.new(3.4, 2.6, 2.6)
	b.CFrame = cf * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.rad(90))
	b.Anchored = true
	b.Color = WOODD
	b.Material = Enum.Material.WoodPlanks
	b.Parent = parent
	return b
end

local function striped(name, width, depth, cf, parent, c1, c2)
	local n = math.max(2, math.floor(width / 4))
	local w = width / n
	for k = 0, n - 1 do
		mk(name, Vector3.new(w, 0.8, depth), cf * CFrame.new(-width / 2 + w * (k + 0.5), 0, 0) * CFrame.Angles(math.rad(-12), 0, 0),
			(k % 2 == 0) and c1 or c2, nil, SMOOTH, parent)
	end
end

-- Layout slots: 8 bases (2 per side), numbered in order around the pond.
local slots = {}
for s = 0, 3 do
	local yaw = s * math.pi / 2
	for _, x in ipairs({ -BASE_X, BASE_X }) do
		local p = CFrame.Angles(0, yaw, 0) * Vector3.new(x, 0, BASE_Z)
		table.insert(slots, { yaw = yaw, x = x, ang = math.atan2(p.X, p.Z), pos = p })
	end
end
table.sort(slots, function(a, b) return a.ang < b.ang end)

-- Keep-clear areas for decoration
local avoid = { { 0, 235, 30 }, { 0, 262, 50 } }
for _, sl in ipairs(slots) do
	table.insert(avoid, { sl.pos.X, sl.pos.Z, 50 })
end
local function clear(x, z)
	if math.abs(x) < 175 and math.abs(z) < 175 then return false end
	if math.abs(x) < 10 or math.abs(z) < 10 then return false end -- keep main paths open
	for _, a in ipairs(avoid) do
		if (x - a[1]) ^ 2 + (z - a[2]) ^ 2 < a[3] ^ 2 then return false end
	end
	return true
end

-- GROUND ----------------------------------------------------------------
ring("Shore", 120, 150, 0, -50, SAND, fGround)
ring("GroundBase", 150, HALF, -4, -50, GRASS1, fGround)
local TILE = 25
for ix = -12, 11 do
	for iz = -12, 11 do
		local cx, cz = (ix + 0.5) * TILE, (iz + 0.5) * TILE
		if not (math.abs(cx) < 150 and math.abs(cz) < 150) then
			local c = ((ix + iz) % 2 == 0) and GRASS1 or GRASS2
			mk("Tile", Vector3.new(TILE, 4, TILE), CFrame.new(cx, -2, cz), c, nil, nil, fGround)
		end
	end
end

-- Paths from the shore out to the walls on every side (the spawn path is the south one)
for s = 0, 3 do
	local cf = CFrame.Angles(0, s * math.pi / 2, 0)
	local p = mk("Path", Vector3.new(10, 0.2, HALF - 150 - WALL_T / 2), cf * CFrame.new(0, 0.1, (150 + HALF - WALL_T / 2) / 2),
		PATH, nil, SMOOTH, fGround)
	p.Material = Enum.Material.Slate
end

-- POND ------------------------------------------------------------------
ring("Step2", 100, HALF, -50, -150, Color3.fromRGB(80, 118, 140), fGround)
ring("Step3", 80, HALF, -150, -250, Color3.fromRGB(50, 85, 118), fGround)
ring("Step4", 60, HALF, -250, -300, Color3.fromRGB(28, 55, 95), fGround)
mk("PondFloor", Vector3.new(2 * HALF, 4, 2 * HALF), CFrame.new(0, -302, 0), Color3.fromRGB(15, 32, 70), nil, nil, fGround)

for i, t in ipairs(tiers) do
	local top = (i == 1) and -1 or t.top
	terrain:FillBlock(CFrame.new(0, (top + t.bottom) / 2, 0),
		Vector3.new(2 * t.half, top - t.bottom, 2 * t.half), Enum.Material.Water)
end

-- Low-poly water surface. These are what players click to cast.
local CELL = 20
local rng = Random.new(7)
for ix = -5, 6 do
	for iz = -5, 6 do
		local cx, cz = (ix - 0.5) * CELL, (iz - 0.5) * CELL
		local yaw = math.rad(90 * rng:NextInteger(0, 1))
		for k = 0, 1 do
			local shade = rng:NextInteger(0, 28)
			local w = Instance.new("WedgePart")
			w.Name = "WaterTri"
			w.Size = Vector3.new(0.4, CELL, CELL)
			w.CFrame = CFrame.new(cx, -0.6, cz)
				* CFrame.Angles(0, yaw + math.rad(180 * k), 0)
				* CFrame.Angles(0, 0, math.rad(90))
			w.Anchored = true
			w.CanCollide = false
			w.CastShadow = false
			w.Material = Enum.Material.SmoothPlastic
			w.Color = Color3.fromRGB(35 + shade, 135 + shade, 215 + shade // 2)
			w.Transparency = 0.45
			w.TopSurface = SMOOTH
			w.BottomSurface = SMOOTH
			w.Parent = fWater
			CollectionService:AddTag(w, "FishingWater")
		end
	end
end

-- Depth markers (1 stud = 2m)
for y, z in pairs({ [-50] = 110, [-150] = 90, [-250] = 70 }) do
	local m = deco(mk("DepthMarker_" .. math.abs(y), Vector3.new(4, 0.2, 4),
		CFrame.new(0, y + 0.2, z), Color3.new(1, 1, 1), Enum.Material.Neon, SMOOTH, fUnder))
	billboard(m, math.abs(y) * 2 .. "m", 3, 90, 30, 120)
end

-- Underwater decoration
local urng = Random.new(5)
local function ledgePoint(a, b)
	local t = urng:NextNumber(a + 3, b - 3)
	local s = urng:NextNumber(-b + 3, b - 3)
	if urng:NextInteger(0, 1) == 0 then s = -s end
	if urng:NextInteger(0, 1) == 0 then
		return s, (urng:NextInteger(0, 1) == 0) and t or -t
	end
	return (urng:NextInteger(0, 1) == 0) and t or -t, s
end
for _, l in ipairs({ { -50, 100, 120 }, { -150, 80, 100 }, { -250, 60, 80 } }) do
	for _ = 1, 16 do
		local x, z = ledgePoint(l[2], l[3])
		local h = urng:NextNumber(5, 13)
		deco(mk("Seaweed", Vector3.new(1.2, h, 1.2), CFrame.new(x, l[1] + h / 2, z) * CFrame.Angles(0, 0, urng:NextNumber(-0.15, 0.15)),
			Color3.fromRGB(40, 140 + urng:NextInteger(-20, 20), 80), nil, SMOOTH, fUnder))
	end
	for _ = 1, 5 do
		local x, z = ledgePoint(l[2], l[3])
		local s = urng:NextNumber(3, 6)
		mk("Rock", Vector3.new(s, s * 0.7, s), CFrame.new(x, l[1] + s * 0.35, z) * CFrame.Angles(0, urng:NextNumber(0, 3), 0),
			Color3.fromRGB(90, 100, 110), nil, SMOOTH, fUnder)
	end
	for _ = 1, 3 do -- coral clumps
		local x, z = ledgePoint(l[2], l[3])
		local c = Color3.fromHSV(urng:NextNumber(0.9, 1.05) % 1, 0.6, 1)
		for k = 1, 3 do
			deco(mk("Coral", Vector3.new(1.4, 2 + k, 1.4), CFrame.new(x + k - 2, l[1] + (2 + k) / 2, z + (k % 2)) * CFrame.Angles(0, 0, (k - 2) * 0.3),
				c, nil, SMOOTH, fUnder))
		end
	end
end
for _ = 1, 16 do
	local x, z = urng:NextNumber(-52, 52), urng:NextNumber(-52, 52)
	local h = urng:NextNumber(6, 16)
	deco(mk("Seaweed", Vector3.new(1.2, h, 1.2), CFrame.new(x, -300 + h / 2, z), Color3.fromRGB(40, 150, 90), nil, SMOOTH, fUnder))
end
local crystal = mk("AbyssCrystal", Vector3.new(6, 12, 6), CFrame.new(0, -294, 0) * CFrame.Angles(0, math.rad(45), 0),
	Color3.fromRGB(80, 200, 255), Enum.Material.Neon, SMOOTH, fUnder)
light(crystal, 70, Color3.fromRGB(100, 210, 255), 3)
for _, o in ipairs({ { 18, 14 }, { -20, 10 }, { 12, -22 }, { -14, -18 } }) do
	local c = mk("Crystal", Vector3.new(3, 6, 3), CFrame.new(o[1], -297, o[2]) * CFrame.Angles(0, 0.7, 0.2),
		Color3.fromRGB(120, 220, 255), Enum.Material.Neon, SMOOTH, fUnder)
	light(c, 25, Color3.fromRGB(100, 210, 255), 2)
end
-- Sunken shipwreck on the second ledge
do
	local cf = CFrame.new(-88, -150, 30) * CFrame.Angles(0, math.rad(20), math.rad(12))
	mk("WreckHull", Vector3.new(10, 6, 30), cf * CFrame.new(0, 3, 0), WOODD, Enum.Material.WoodPlanks, SMOOTH, fUnder)
	mk("WreckDeck", Vector3.new(9, 1, 26), cf * CFrame.new(0, 6.5, 0), WOOD, Enum.Material.WoodPlanks, SMOOTH, fUnder)
	mk("WreckMast", Vector3.new(1.2, 18, 1.2), cf * CFrame.new(0, 14, 3) * CFrame.Angles(0.4, 0, 0), WOODD, nil, SMOOTH, fUnder)
	local chest = mk("TreasureChest", Vector3.new(4, 3, 3), cf * CFrame.new(0, 8.5, -8), Color3.fromRGB(200, 150, 50), nil, SMOOTH, fUnder)
	light(chest, 16, Color3.fromRGB(255, 210, 90), 2)
end

-- Buoys in the pond corners
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local b = Instance.new("Part")
		b.Name = "Buoy"
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(4, 4, 4)
		b.Position = Vector3.new(sx * 105, -0.2, sz * 105)
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.Color = Color3.fromRGB(230, 60, 60)
		b.Material = Enum.Material.SmoothPlastic
		b.Parent = fDecor
		deco(mk("BuoyTop", Vector3.new(0.8, 3, 0.8), CFrame.new(sx * 105, 2.5, sz * 105), Color3.new(1, 1, 1), nil, SMOOTH, fDecor))
		local tip = deco(mk("BuoyLight", Vector3.new(1, 1, 1), CFrame.new(sx * 105, 4.3, sz * 105), Color3.fromRGB(255, 80, 80), Enum.Material.Neon, SMOOTH, fDecor))
		light(tip, 14, Color3.fromRGB(255, 90, 90), 1)
	end
end

-- CASTLE WALLS ----------------------------------------------------------
mk("Wall_N", Vector3.new(2 * HALF + WALL_T, WALL_H, WALL_T), CFrame.new(0, WALL_H / 2, HALF), WALL, nil, nil, fWalls)
mk("Wall_S", Vector3.new(2 * HALF + WALL_T, WALL_H, WALL_T), CFrame.new(0, WALL_H / 2, -HALF), WALL, nil, nil, fWalls)
mk("Wall_E", Vector3.new(WALL_T, WALL_H, 2 * HALF), CFrame.new(HALF, WALL_H / 2, 0), WALL, nil, nil, fWalls)
mk("Wall_W", Vector3.new(WALL_T, WALL_H, 2 * HALF), CFrame.new(-HALF, WALL_H / 2, 0), WALL, nil, nil, fWalls)
mk("Trim_N", Vector3.new(2 * HALF + WALL_T + 2, 5, WALL_T + 2), CFrame.new(0, 2.5, HALF), WALLD, nil, SMOOTH, fWalls)
mk("Trim_S", Vector3.new(2 * HALF + WALL_T + 2, 5, WALL_T + 2), CFrame.new(0, 2.5, -HALF), WALLD, nil, SMOOTH, fWalls)
mk("Trim_E", Vector3.new(WALL_T + 2, 5, 2 * HALF), CFrame.new(HALF, 2.5, 0), WALLD, nil, SMOOTH, fWalls)
mk("Trim_W", Vector3.new(WALL_T + 2, 5, 2 * HALF), CFrame.new(-HALF, 2.5, 0), WALLD, nil, SMOOTH, fWalls)
mk("WallCap_N", Vector3.new(2 * HALF + WALL_T + 2, 2, WALL_T + 2), CFrame.new(0, WALL_H - 1, HALF), WALLD, nil, SMOOTH, fWalls)
mk("WallCap_S", Vector3.new(2 * HALF + WALL_T + 2, 2, WALL_T + 2), CFrame.new(0, WALL_H - 1, -HALF), WALLD, nil, SMOOTH, fWalls)
mk("WallCap_E", Vector3.new(WALL_T + 2, 2, 2 * HALF), CFrame.new(HALF, WALL_H - 1, 0), WALLD, nil, SMOOTH, fWalls)
mk("WallCap_W", Vector3.new(WALL_T + 2, 2, 2 * HALF), CFrame.new(-HALF, WALL_H - 1, 0), WALLD, nil, SMOOTH, fWalls)
for k = 0, 49 do
	local v = -294 + 12 * k
	mk("Merlon", Vector3.new(6, 6, WALL_T), CFrame.new(v, WALL_H + 3, HALF), WALL, nil, nil, fWalls)
	mk("Merlon", Vector3.new(6, 6, WALL_T), CFrame.new(v, WALL_H + 3, -HALF), WALL, nil, nil, fWalls)
	mk("Merlon", Vector3.new(WALL_T, 6, 6), CFrame.new(HALF, WALL_H + 3, v), WALL, nil, nil, fWalls)
	mk("Merlon", Vector3.new(WALL_T, 6, 6), CFrame.new(-HALF, WALL_H + 3, v), WALL, nil, nil, fWalls)
end
-- Wall torches every 60 studs on the inner face
for s = 0, 3 do
	local cf = CFrame.Angles(0, s * math.pi / 2, 0)
	for v = -240, 240, 60 do
		local t = deco(mk("WallTorch", Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(v, 14, HALF - WALL_T / 2 - 1),
			Color3.fromRGB(255, 150, 40), Enum.Material.Neon, SMOOTH, fWalls))
		light(t, 22, Color3.fromRGB(255, 170, 90), 1.2)
		deco(mk("TorchHolder", Vector3.new(0.6, 2.5, 0.6), cf * CFrame.new(v, 12.4, HALF - WALL_T / 2 - 0.8), WOODD, nil, SMOOTH, fWalls))
	end
end
local flagColors = { Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 120, 220), Color3.fromRGB(240, 200, 60), Color3.fromRGB(70, 180, 90) }
local fi = 0
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		fi += 1
		local th = WALL_H + 16
		mk("Tower", Vector3.new(30, th, 30), CFrame.new(sx * HALF, th / 2, sz * HALF), WALL, nil, nil, fWalls)
		mk("TowerBand", Vector3.new(34, 4, 34), CFrame.new(sx * HALF, th - 6, sz * HALF), WALLD, nil, SMOOTH, fWalls)
		for _, ox in ipairs({ -12, 0, 12 }) do
			for _, oz in ipairs({ -12, 0, 12 }) do
				if ox ~= 0 or oz ~= 0 then
					if math.abs(ox) == 12 or math.abs(oz) == 12 then
						mk("TowerMerlon", Vector3.new(6, 6, 6), CFrame.new(sx * HALF + ox, th + 3, sz * HALF + oz), WALL, nil, nil, fWalls)
					end
				end
			end
		end
		local torch = mk("Torch", Vector3.new(4, 4, 4), CFrame.new(sx * HALF, th + 2, sz * HALF),
			Color3.fromRGB(255, 160, 40), Enum.Material.Neon, SMOOTH, fWalls)
		light(torch, 70, Color3.fromRGB(255, 190, 110))
		mk("FlagPole", Vector3.new(1, 18, 1), CFrame.new(sx * HALF, th + 13, sz * HALF), WOODD, nil, SMOOTH, fWalls)
		mk("Flag", Vector3.new(9, 5, 0.5), CFrame.new(sx * HALF + 5, th + 19, sz * HALF), flagColors[fi], nil, SMOOTH, fWalls)
	end
end

-- DOCKS -----------------------------------------------------------------
-- Builds a dock along local Z. The deck part is named "Dock" so the game can find it.
local function buildDock(cf, width, parent)
	local deck = mk("Dock", Vector3.new(width, 1, DOCK_LEN), cf, WOOD, Enum.Material.WoodPlanks, SMOOTH, parent)
	for _, side in ipairs({ -1, 1 }) do
		mk("Rail", Vector3.new(0.6, 0.6, DOCK_LEN - 8), cf * CFrame.new(side * (width / 2 - 0.3), 3, 4), WOODD, nil, SMOOTH, parent)
		for z = -DOCK_LEN / 2 + 6, DOCK_LEN / 2 - 4, 10 do
			mk("RailPost", Vector3.new(0.6, 2.5, 0.6), cf * CFrame.new(side * (width / 2 - 0.3), 1.75, z), WOODD, nil, SMOOTH, parent)
		end
		for z = -DOCK_LEN / 2 + 6, DOCK_LEN / 2 - 4, 20 do
			mk("Pylon", Vector3.new(1.4, 14, 1.4), cf * CFrame.new(side * (width / 2 - 0.7), -5.5, z), WOODD, nil, SMOOTH, parent)
		end
	end
	-- T-shaped platform at the far end so several people can fish
	mk("DockEnd", Vector3.new(width + 10, 1, 10), cf * CFrame.new(0, 0, -DOCK_LEN / 2 - 4), WOOD, Enum.Material.WoodPlanks, SMOOTH, parent)
	for _, side in ipairs({ -1, 1 }) do
		mk("Pylon", Vector3.new(1.4, 14, 1.4), cf * CFrame.new(side * (width / 2 + 4), -5.5, -DOCK_LEN / 2 - 4), WOODD, nil, SMOOTH, parent)
	end
	lamp(cf * CFrame.new(width / 2 + 4, 0.5, -DOCK_LEN / 2 - 7), parent, 5)
	lamp(cf * CFrame.new(-width / 2 - 4, 0.5, -DOCK_LEN / 2 - 7), parent, 5)
	barrel(cf * CFrame.new(-width / 2 + 1.8, 0.5, DOCK_LEN / 2 - 8), parent)
	crate(cf * CFrame.new(width / 2 - 2, 0.5, DOCK_LEN / 2 - 12), parent, 2.5)
	return deck
end

-- BASES (each one is a Plot model with its own dock) --------------------
for i, sl in ipairs(slots) do
	local sideCF = CFrame.Angles(0, sl.yaw, 0)
	local cf = sideCF * CFrame.new(sl.x, 0.5, BASE_Z) -- local -Z faces the pond

	local plot = Instance.new("Model")
	plot.Name = "Base" .. i
	plot:SetAttribute("BaseIndex", i)
	plot.Parent = fBases
	CollectionService:AddTag(plot, "Plot")

	local floor = mk("Floor", Vector3.new(BASE_SIZE, 1, BASE_SIZE), cf, PLATE, nil, nil, plot)
	plot.PrimaryPart = floor

	local half = BASE_SIZE / 2
	-- Fences with a gap in the front (pond side) for the dock
	mk("FenceBack", Vector3.new(BASE_SIZE, 1, 0.8), cf * CFrame.new(0, 3, half - 0.4), WOOD, nil, SMOOTH, plot)
	mk("FenceBackLow", Vector3.new(BASE_SIZE, 1, 0.8), cf * CFrame.new(0, 1.5, half - 0.4), WOOD, nil, SMOOTH, plot)
	for _, sx in ipairs({ -1, 1 }) do
		mk("FenceSide", Vector3.new(0.8, 1, BASE_SIZE), cf * CFrame.new(sx * (half - 0.4), 3, 0), WOOD, nil, SMOOTH, plot)
		mk("FenceSideLow", Vector3.new(0.8, 1, BASE_SIZE), cf * CFrame.new(sx * (half - 0.4), 1.5, 0), WOOD, nil, SMOOTH, plot)
		mk("FenceFront", Vector3.new(half - 6, 1, 0.8), cf * CFrame.new(sx * (half + 6) / 2, 3, -half + 0.4), WOOD, nil, SMOOTH, plot)
		mk("FenceFrontLow", Vector3.new(half - 6, 1, 0.8), cf * CFrame.new(sx * (half + 6) / 2, 1.5, -half + 0.4), WOOD, nil, SMOOTH, plot)
	end
	for _, px in ipairs({ -half, -half / 2, 0, half / 2, half }) do
		for _, pz in ipairs({ -half, half }) do
			if not (pz == -half and math.abs(px) < 6) then
				mk("FencePost", Vector3.new(1.4, 4.5, 1.4), cf * CFrame.new(px * 0.985, 2.25, pz * 0.985), WOODD, nil, nil, plot)
			end
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, pz in ipairs({ -half / 2, 0, half / 2 }) do
			mk("FencePost", Vector3.new(1.4, 4.5, 1.4), cf * CFrame.new(sx * half * 0.985, 2.25, pz), WOODD, nil, nil, plot)
		end
	end
	-- Gate arch at the front gap
	for _, sx in ipairs({ -1, 1 }) do
		mk("GatePost", Vector3.new(1.6, 9, 1.6), cf * CFrame.new(sx * 6, 4.5, -half + 0.4), WOODD, nil, nil, plot)
	end
	local gateSign = mk("GateSign", Vector3.new(14, 2.4, 0.6), cf * CFrame.new(0, 8.6, -half + 0.4), WOOD, nil, SMOOTH, plot)
	gateSign.Name = "GateSign"

	-- Fish tank: your bag of fish swims around in here
	mk("TankBase", Vector3.new(16, 1, 16), cf * CFrame.new(0, 1, 6), WOODD, nil, nil, plot)
	local tank = mk("TankGlass", Vector3.new(14, 7, 14), cf * CFrame.new(0, 5, 6),
		Color3.fromRGB(190, 225, 245), Enum.Material.Glass, SMOOTH, plot)
	tank.Transparency = 0.7
	local tw = mk("TankWater", Vector3.new(13, 5, 13), cf * CFrame.new(0, 4, 6),
		Color3.fromRGB(60, 160, 230), Enum.Material.SmoothPlastic, SMOOTH, plot)
	tw.Transparency = 0.5
	tw.CanCollide = false
	tw.CanQuery = false
	mk("TankSand", Vector3.new(13, 0.6, 13), cf * CFrame.new(0, 1.8, 6), SAND, nil, SMOOTH, plot)
	local tankLight = deco(mk("TankLight", Vector3.new(10, 0.3, 1), cf * CFrame.new(0, 8.6, 6), Color3.fromRGB(200, 240, 255), Enum.Material.Neon, SMOOTH, plot))
	light(tankLight, 14, Color3.fromRGB(150, 220, 255), 1)

	-- Spawn pad (owner spawns here)
	local spawnPad = mk("Spawn", Vector3.new(8, 0.4, 8), cf * CFrame.new(0, 0.7, -14),
		Color3.fromRGB(240, 200, 60), Enum.Material.Neon, SMOOTH, plot)
	spawnPad.CanCollide = false

	-- Some base props
	crate(cf * CFrame.new(-half + 4, 0.5, half - 4), plot, 3)
	crate(cf * CFrame.new(-half + 4, 3.5, half - 4) * CFrame.Angles(0, 0.4, 0), plot, 2.4)
	barrel(cf * CFrame.new(-half + 8, 0.5, half - 4), plot)
	barrel(cf * CFrame.new(half - 4, 0.5, half - 4), plot)
	lamp(cf * CFrame.new(-8, 0.5, -half + 3), plot, 6)
	lamp(cf * CFrame.new(8, 0.5, -half + 3), plot, 6)
	-- Bench facing the pond
	mk("BenchSeat", Vector3.new(8, 0.6, 2.4), cf * CFrame.new(half - 10, 2, -half + 10), WOOD, nil, SMOOTH, plot)
	mk("BenchBack", Vector3.new(8, 2.4, 0.5), cf * CFrame.new(half - 10, 3.2, -half + 11), WOOD, nil, SMOOTH, plot)
	for _, bx in ipairs({ -3.4, 3.4 }) do
		mk("BenchLeg", Vector3.new(0.6, 1.5, 2), cf * CFrame.new(half - 10 + bx, 1.2, -half + 10), WOODD, nil, SMOOTH, plot)
	end

	-- This base's private dock, in line with it
	buildDock(sideCF * CFrame.new(sl.x, 1.5, DOCK_Z), 10, plot)
end

-- Public piers in the middle of each side
for s = 0, 3 do
	local m = Instance.new("Model")
	m.Name = "PublicDock" .. (s + 1)
	m.Parent = fDocks
	local deck = buildDock(CFrame.Angles(0, s * math.pi / 2, 0) * CFrame.new(0, 1.5, DOCK_Z), 12, m)
	billboard(deck, "Public Pier", 5, 130, 34, 160)
end

-- TOWN (spawn, shop, market) --------------------------------------------
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Size = Vector3.new(14, 1, 14)
spawn.Position = Vector3.new(0, 0.5, 235)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Color = Color3.fromRGB(240, 200, 60)
spawn.Material = Enum.Material.Slate
spawn.Parent = fTown
for _, sx in ipairs({ -9, 9 }) do
	mk("ArchPillar", Vector3.new(3, 14, 3), CFrame.new(sx, 7, 222), WALL, nil, nil, fTown)
	mk("ArchPillarCap", Vector3.new(4, 1, 4), CFrame.new(sx, 14.5, 222), WALLD, nil, SMOOTH, fTown)
end
local beam = mk("ArchBeam", Vector3.new(21, 3, 3), CFrame.new(0, 15.5, 222), WALL, nil, nil, fTown)
billboard(beam, "Castle Fishing", 4, 220, 50, 250, Color3.fromRGB(255, 220, 90))

-- Rod shop
local SZ = 275
mk("ShopBody", Vector3.new(34, 18, 22), CFrame.new(0, 9, SZ), Color3.fromRGB(205, 95, 85), nil, nil, fTown)
mk("ShopRoof", Vector3.new(38, 3, 26), CFrame.new(0, 19.5, SZ), Color3.fromRGB(110, 60, 55), nil, nil, fTown)
mk("ShopRoofTop", Vector3.new(30, 3, 18), CFrame.new(0, 22.5, SZ), Color3.fromRGB(110, 60, 55), nil, SMOOTH, fTown)
local door = mk("ShopDoor", Vector3.new(8, 12, 0.6), CFrame.new(0, 6, SZ - 11.2), WOODD, nil, SMOOTH, fTown)
CollectionService:AddTag(door, "RodShop")
for _, wx in ipairs({ -11, 11 }) do
	local win = mk("ShopWindow", Vector3.new(7, 6, 0.6), CFrame.new(wx, 10, SZ - 11.2),
		Color3.fromRGB(190, 225, 245), Enum.Material.Glass, SMOOTH, fTown)
	win.Transparency = 0.4
end
striped("Awning", 36, 6, CFrame.new(0, 14.5, SZ - 14), fTown, Color3.fromRGB(230, 70, 70), Color3.fromRGB(245, 245, 245))
local sign = mk("ShopSign", Vector3.new(20, 5, 1), CFrame.new(0, 24.5, SZ - 9), WOODD, nil, SMOOTH, fTown)
billboard(sign, "Rod Shop", 5, 180, 50, 250)
-- Display rods leaning by the door
for k, c in ipairs({ Color3.fromRGB(120, 80, 40), Color3.fromRGB(255, 200, 50), Color3.fromRGB(150, 80, 255) }) do
	mk("DisplayRod", Vector3.new(0.4, 8, 0.4), CFrame.new(5 + k * 1.2, 4, SZ - 12) * CFrame.Angles(math.rad(-10), 0, 0), c, nil, SMOOTH, fTown)
end

-- Fish market stall (sell your fish here)
do
	local MX, MZ = -36, 250
	local base = CFrame.new(MX, 0, MZ)
	local counter = mk("MarketCounter", Vector3.new(16, 4, 5), base * CFrame.new(0, 2, -3), WOOD, Enum.Material.WoodPlanks, SMOOTH, fTown)
	CollectionService:AddTag(counter, "Merchant")
	mk("CounterTop", Vector3.new(17, 0.5, 6), base * CFrame.new(0, 4.25, -3), WOODD, nil, SMOOTH, fTown)
	local ice = mk("IceBed", Vector3.new(14, 0.6, 4), base * CFrame.new(0, 4.7, -3), Color3.fromRGB(220, 240, 255), Enum.Material.Ice, SMOOTH, fTown)
	ice.CanQuery = false
	for k = -2, 2 do
		local c = ({ Color3.fromRGB(200, 200, 200), Color3.fromRGB(90, 220, 110), Color3.fromRGB(70, 150, 255), Color3.fromRGB(255, 140, 90), Color3.fromRGB(180, 90, 255) })[k + 3]
		deco(mk("DisplayFish", Vector3.new(2.2, 0.6, 0.9), base * CFrame.new(k * 2.6, 5.3, -3) * CFrame.Angles(0, 0.3 * k, 0), c, nil, SMOOTH, fTown))
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			mk("StallPost", Vector3.new(0.8, 11, 0.8), base * CFrame.new(sx * 8, 5.5, sz * 4 - 1), WOODD, nil, SMOOTH, fTown)
		end
	end
	striped("StallRoof", 18, 11, base * CFrame.new(0, 11.4, -1), fTown, Color3.fromRGB(60, 140, 220), Color3.fromRGB(245, 245, 245))
	local msign = mk("MarketSign", Vector3.new(12, 3, 0.6), base * CFrame.new(0, 13.5, -6.5), WOODD, nil, SMOOTH, fTown)
	billboard(msign, "Fish Market", 4, 170, 46, 220, Color3.fromRGB(140, 210, 255))
	barrel(base * CFrame.new(-10, 0, -6), fTown)
	barrel(base * CFrame.new(10, 0, -6), fTown)
	crate(base * CFrame.new(11, 0, 2), fTown, 3)
end

-- Notice board on the other side of spawn
do
	local base = CFrame.new(36, 0, 250) * CFrame.Angles(0, math.rad(180), 0)
	for _, sx in ipairs({ -1, 1 }) do
		mk("BoardPost", Vector3.new(1, 10, 1), base * CFrame.new(sx * 6, 5, 0), WOODD, nil, SMOOTH, fTown)
	end
	local board = mk("NoticeBoard", Vector3.new(12, 7, 0.6), base * CFrame.new(0, 6, 0), WOOD, nil, SMOOTH, fTown)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.CanvasSize = Vector2.new(480, 280)
	sg.Parent = board
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(235, 220, 180)
	t.TextColor3 = Color3.fromRGB(70, 50, 30)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = "HOW TO FISH\n1. Equip your rod\n2. Click the water\n3. Wait for the !\n4. Hold click to reel\nSell at the Fish Market!"
	t.Parent = sg
end

-- Lamp posts at the pond corners and along the shore
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		lamp(CFrame.new(sx * 135, 0, sz * 135), fDecor, 9)
	end
end
for s = 0, 3 do
	local cf = CFrame.Angles(0, s * math.pi / 2, 0)
	for _, x in ipairs({ -45, 45 }) do
		lamp(cf * CFrame.new(x, 0, 140), fDecor, 6)
	end
end

-- TREES, BUSHES, FLOWERS, ROCKS -------------------------------------------
local trng = Random.new(21)
local trees, tries = 0, 0
while trees < 50 and tries < 900 do
	tries += 1
	local x, z = trng:NextNumber(-278, 278), trng:NextNumber(-278, 278)
	if clear(x, z) then
		trees += 1
		local s = trng:NextNumber(0.8, 1.3)
		local g = trng:NextInteger(-12, 12)
		mk("Trunk", Vector3.new(3 * s, 10 * s, 3 * s), CFrame.new(x, 5 * s, z), WOODD, nil, SMOOTH, fDecor)
		mk("Leaves", Vector3.new(13 * s, 9 * s, 13 * s), CFrame.new(x, 14 * s, z), Color3.fromRGB(46 + g, 120 + g, 56), nil, nil, fDecor)
		mk("LeavesTop", Vector3.new(8 * s, 7 * s, 8 * s), CFrame.new(x, 21 * s, z), Color3.fromRGB(56 + g, 140 + g, 66), nil, nil, fDecor)
		table.insert(avoid, { x, z, 10 })
	end
end
local bushes, btries = 0, 0
while bushes < 40 and btries < 900 do
	btries += 1
	local x, z = trng:NextNumber(-285, 285), trng:NextNumber(-285, 285)
	if clear(x, z) then
		bushes += 1
		local s = trng:NextNumber(2.5, 4.5)
		mk("Bush", Vector3.new(s * 1.3, s, s * 1.3), CFrame.new(x, s / 2, z) * CFrame.Angles(0, trng:NextNumber(0, 3), 0),
			Color3.fromRGB(60, 135 + trng:NextInteger(-15, 15), 60), nil, nil, fDecor)
		table.insert(avoid, { x, z, 4 })
	end
end
local petals = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 110, 255) }
local flowers, ftries = 0, 0
while flowers < 110 and ftries < 1800 do
	ftries += 1
	local x, z = trng:NextNumber(-285, 285), trng:NextNumber(-285, 285)
	if clear(x, z) then
		flowers += 1
		deco(mk("Stem", Vector3.new(0.5, 2, 0.5), CFrame.new(x, 1, z), Color3.fromRGB(40, 120, 50), nil, SMOOTH, fDecor))
		deco(mk("Flower", Vector3.new(1.8, 1.2, 1.8), CFrame.new(x, 2.4, z), petals[trng:NextInteger(1, #petals)], nil, SMOOTH, fDecor))
	end
end
local rocks, rtries = 0, 0
while rocks < 22 and rtries < 600 do
	rtries += 1
	local x, z = trng:NextNumber(-282, 282), trng:NextNumber(-282, 282)
	if clear(x, z) then
		rocks += 1
		local s = trng:NextNumber(3, 7)
		mk("Rock", Vector3.new(s, s * 0.7, s * 1.2), CFrame.new(x, s * 0.35, z) * CFrame.Angles(0, trng:NextNumber(0, 3), 0),
			Color3.fromRGB(120, 120, 125), nil, nil, fDecor)
	end
end

-- LIGHTING --------------------------------------------------------------
local L = game:GetService("Lighting")
L.ClockTime = 14.5
L.Brightness = 2.5
L.Ambient = Color3.fromRGB(105, 115, 135)
L.OutdoorAmbient = Color3.fromRGB(125, 135, 150)
L.EnvironmentDiffuseScale = 0.5
L.EnvironmentSpecularScale = 0.5
local atm = L:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
atm.Density = 0.22
atm.Haze = 0.8
atm.Color = Color3.fromRGB(190, 215, 240)
atm.Decay = Color3.fromRGB(110, 150, 200)
atm.Parent = L
local bloom = L:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
bloom.Intensity = 0.35
bloom.Size = 24
bloom.Threshold = 1
bloom.Parent = L
local cc = L:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
cc.Saturation = 0.12
cc.Contrast = 0.06
cc.Parent = L
local rays = L:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
rays.Intensity = 0.04
rays.Spread = 0.6
rays.Parent = L

print("Map v4 built: 8 bases with private docks, 4 public piers, rod shop, fish market.")
