-- BuildMap v7: a low-poly spearfishing island.
--   * earth-and-rock cliffs around the island
--   * a five-tier dive pit (see ReplicatedStorage.Shared.Zones) with jagged rock walls,
--     sandy shelves, a hazy fog layer at the top of each zone and a guardian lair per zone
--   * 8 bases with big aquariums, docks whose legs reach the seabed, 4 public piers
--   * a town plaza with the Gear Shop, Fish Market and Pearl Shop
--
-- HOW TO RUN (with Rojo connected): in the Command Bar type   require(game.ServerStorage.BuildMap)()
-- The game also rebuilds an out-of-date map automatically when you press Play.
-- WARNING: wipes Terrain and replaces the "Map" folder.

local MAP_VERSION = 8

local function build()
	local CollectionService = game:GetService("CollectionService")
	local Lighting = game:GetService("Lighting")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Poly = require(Shared:WaitForChild("Poly"))
	local Zones = require(Shared:WaitForChild("Zones"))

	print("[BuildMap] Starting v" .. MAP_VERSION .. "...")

	local terrain = workspace.Terrain
	terrain:Clear()
	terrain.WaterTransparency = 1
	terrain.WaterReflectance = 0
	terrain.WaterWaveSize = 0
	terrain.WaterWaveSpeed = 0
	terrain.WaterColor = Color3.fromRGB(40, 150, 210)

	for _, name in { "Map", "Plots" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	for _, c in workspace:GetChildren() do
		if c:IsA("SpawnLocation") or c.Name == "Baseplate" then
			c:Destroy()
		end
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	map:SetAttribute("Version", MAP_VERSION)
	map.Parent = workspace
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = map
		return f
	end
	local fGround, fCliffs, fPit = folder("Ground"), folder("Cliffs"), folder("Pit")
	local fBases, fPiers, fTown = folder("Bases"), folder("PublicPiers"), folder("Town")
	local fNature, fDecor, fLairs = folder("Nature"), folder("Underwater"), folder("Lairs")

	---------------------------------------------------------------------------------------------
	-- Palette (bright, flat-shaded)
	local rgb = Color3.fromRGB
	local GRASS = { rgb(110, 196, 92), rgb(98, 184, 84), rgb(122, 204, 100), rgb(104, 190, 88) }
	local SAND = rgb(240, 220, 168)
	local SAND_D = rgb(222, 198, 146)
	local DIRT = rgb(150, 104, 70)
	local DIRT_D = rgb(118, 82, 56)
	local ROCK = rgb(134, 136, 146)
	local STONE = rgb(196, 192, 184)
	local STONE_D = rgb(150, 146, 140)
	local PAVE1, PAVE2 = rgb(214, 206, 190), rgb(196, 188, 172)
	local WOOD1, WOOD2, WOOD3 = rgb(176, 124, 78), rgb(160, 110, 66), rgb(190, 138, 90)
	local WOOD_D = rgb(104, 72, 46)
	local HEDGE, HEDGE_D = rgb(80, 160, 76), rgb(64, 138, 64)
	local CREAM = rgb(246, 236, 212)
	local ROOF, ROOF_D = rgb(220, 90, 70), rgb(176, 66, 52)
	local GOLD = rgb(250, 200, 70)
	local LAMP = rgb(255, 196, 110)

	-- Layout (studs). Each side uses a local frame: x along the side, +z from the pond out to that side.
	local ISLAND = 432 -- cliff foot
	local POND = Zones.List[1].Half -- water edge (180)
	local SHORE = POND + 16 -- sand edge
	local BASE_X, BASE_Z, BASE = 120, 310, 80
	local DOCK_FROM, DOCK_TO, PLAT_D = SHORE, 170, 12
	local DECK_Y = 0.9 -- plank centre, deck top 1.2
	local SHELF_Y = Zones.List[1].Bottom -- seabed under the docks

	---------------------------------------------------------------------------------------------
	-- Helpers
	local FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

	-- o: { class, shape, material, transparency, deco (no collide/query), noQuery, noShadow }
	local function mk(name, size, cf, color, parent, o)
		o = o or {}
		local p = Instance.new(o.class or "Part")
		p.Name = name
		if o.shape then
			p.Shape = o.shape
		end
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.Color = color
		p.Material = o.material or Enum.Material.SmoothPlastic
		for _, f in FACES do
			p[f] = Enum.SurfaceType.Smooth
		end
		if o.transparency then
			p.Transparency = o.transparency
		end
		if o.deco then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
		if o.noQuery then
			p.CanQuery = false
		end
		if o.noShadow then
			p.CastShadow = false
		end
		p.Parent = parent
		return p
	end

	local function cyl(name, d, h, cf, color, parent, o)
		o = o or {}
		o.shape = Enum.PartType.Cylinder
		return mk(name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.rad(90)), color, parent, o)
	end

	local function light(part, range, color, brightness)
		local pl = Instance.new("PointLight")
		pl.Range = range
		pl.Brightness = brightness or 1.2
		pl.Color = color
		pl.Shadows = false
		pl.Parent = part
	end

	local function tri(a, b, c, color, parent, o)
		o = o or {}
		Poly.Triangle(a, b, c, { Color = color, Parent = parent, Material = o.material, Transparency = o.transparency, Query = o.query, Shadow = o.shadow })
	end
	local function quad(a, b, c, d, color, parent, o)
		tri(a, b, c, color, parent, o)
		tri(a, c, d, color, parent, o)
	end

	local function lantern(cf, parent)
		mk("LanternBase", Vector3.new(1.6, 0.4, 1.6), cf * CFrame.new(0, 0.2, 0), WOOD_D, parent, { noQuery = true })
		local glow = mk("LanternGlow", Vector3.new(1, 1.4, 1), cf * CFrame.new(0, 1.1, 0), LAMP, parent, { material = Enum.Material.Neon, deco = true })
		for _, c in { { -0.65, -0.65 }, { 0.65, -0.65 }, { -0.65, 0.65 }, { 0.65, 0.65 } } do
			mk("LanternFrame", Vector3.new(0.3, 1.4, 0.3), cf * CFrame.new(c[1], 1.1, c[2]), WOOD_D, parent, { deco = true })
		end
		mk("LanternCap", Vector3.new(1.8, 0.4, 1.8), cf * CFrame.new(0, 2.0, 0), WOOD_D, parent, { deco = true })
		mk("LanternTop", Vector3.new(0.8, 0.4, 0.8), cf * CFrame.new(0, 2.4, 0), WOOD_D, parent, { deco = true })
		light(glow, 22, Color3.fromRGB(255, 200, 130), 1)
	end

	local function lampPost(cf, parent, h)
		mk("LampFoot", Vector3.new(1.6, 0.6, 1.6), cf * CFrame.new(0, 0.3, 0), STONE_D, parent, { noQuery = true })
		cyl("LampPost", 0.7, h - 0.6, cf * CFrame.new(0, 0.6 + (h - 0.6) / 2, 0), WOOD_D, parent, { noQuery = true })
		lantern(cf * CFrame.new(0, h, 0), parent)
	end

	local SIGN_FONT = Font.fromEnum(Enum.Font.FredokaOne)
	local function signText(part, face, text, color, strokeColor)
		local g = Instance.new("SurfaceGui")
		g.Name = "SignGui"
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0.3
		g.Parent = part
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.FontFace = SIGN_FONT
		l.Text = text
		l.TextScaled = true
		l.TextColor3 = color or Color3.new(1, 1, 1)
		l.Parent = g
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.07, 0)
		pad.PaddingRight = UDim.new(0.07, 0)
		pad.PaddingTop = UDim.new(0.14, 0)
		pad.PaddingBottom = UDim.new(0.12, 0)
		pad.Parent = l
		local s = Instance.new("UIStroke")
		s.Color = strokeColor or Color3.fromRGB(40, 26, 18)
		s.Thickness = 3
		s.Parent = l
		return l
	end

	local function board(name, w, h, cf, parent, text, twoSided)
		mk(name .. "Frame", Vector3.new(w + 0.6, h + 0.6, 0.3), cf, WOOD_D, parent, { deco = true })
		local face = mk(name, Vector3.new(w, h, if twoSided then 0.5 else 0.4), cf * CFrame.new(0, 0, if twoSided then 0 else -0.1), WOOD1, parent, { deco = true })
		if text then
			signText(face, Enum.NormalId.Front, text)
			if twoSided then
				signText(face, Enum.NormalId.Back, text)
			end
		end
		return face
	end

	-- Four slabs forming a square ring between half-sizes a and b.
	local function ring(name, a, b, top, bottom, color, parent, o)
		local h, y, m, t = top - bottom, (top + bottom) / 2, (a + b) / 2, b - a
		mk(name .. "_N", Vector3.new(2 * b, h, t), CFrame.new(0, y, m), color, parent, o)
		mk(name .. "_S", Vector3.new(2 * b, h, t), CFrame.new(0, y, -m), color, parent, o)
		mk(name .. "_E", Vector3.new(t, h, 2 * a), CFrame.new(m, y, 0), color, parent, o)
		mk(name .. "_W", Vector3.new(t, h, 2 * a), CFrame.new(-m, y, 0), color, parent, o)
	end

	local function sideCF(s)
		return CFrame.Angles(0, s * math.pi / 2, 0)
	end

	local function path(cf, x, width, zFrom, zTo, parent)
		local len = zFrom - zTo
		local n = math.max(1, math.floor(len / 6 + 0.5))
		local step = len / n
		for i = 0, n - 1 do
			local z = zFrom - step * (i + 0.5)
			mk("PathStone", Vector3.new(width, 0.3, step - 0.5), cf * CFrame.new(x, 0.02, z), (i % 2 == 0) and PAVE1 or PAVE2, parent)
		end
	end

	-- Low-poly trees
	local function palm(cf, parent, rng)
		local h = rng:NextNumber(14, 20)
		local lean = rng:NextNumber(0.1, 0.3)
		local pts = {}
		for i = 0, 4 do
			local t = i / 4
			pts[i] = cf * Vector3.new(math.sin(t * 1.4) * lean * h * 0.6, t * h, 0)
		end
		for i = 0, 3 do
			local r0, r1 = 0.9 - i * 0.12, 0.8 - i * 0.12
			local base = CFrame.lookAt(pts[i], pts[i + 1]) * CFrame.Angles(-math.pi / 2, 0, 0)
			Poly.Frustum(base, r0, r1, (pts[i + 1] - pts[i]).Magnitude, 4, if i % 2 == 0 then WOOD2 else WOOD1, { Parent = parent })
		end
		local top = pts[4]
		for k = 0, 6 do
			local a = k / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local mid = top + dir * 4.5 + Vector3.new(0, 1.2, 0)
			local tip = top + dir * 8.5 + Vector3.new(0, -2.2, 0)
			local leaf = if k % 2 == 0 then rgb(70, 170, 70) else rgb(90, 190, 80)
			tri(top, mid + side * 1.6, mid - side * 1.6, leaf, parent)
			tri(mid + side * 1.6, tip, mid - side * 1.6, Poly.Shade(leaf, -0.1), parent)
		end
		for k = 0, 2 do
			local a = k * 2.1
			mk("Coconut", Vector3.new(0.9, 0.9, 0.9), CFrame.new(top + Vector3.new(math.cos(a) * 0.6, -0.7, math.sin(a) * 0.6)), rgb(120, 86, 50), parent, { shape = Enum.PartType.Ball, deco = true })
		end
	end
	local function roundTree(cf, parent, rng)
		local s = rng:NextNumber(0.9, 1.3)
		Poly.Frustum(cf, 1.3 * s, 0.9 * s, 7 * s, 4, WOOD2, { Parent = parent })
		local g = rng:NextInteger(-12, 12)
		Poly.Blob(cf * CFrame.new(0, 10.5 * s, 0), Vector3.new(11, 8, 11) * s, rgb(84 + g, 170 + g, 76), rng, { Parent = parent })
		Poly.Blob(cf * CFrame.new(2 * s, 14 * s, -1 * s), Vector3.new(6, 5, 6) * s, rgb(100 + g, 186 + g, 88), rng, { Parent = parent })
	end
	local function pine(cf, parent, rng)
		local s = rng:NextNumber(0.9, 1.4)
		Poly.Frustum(cf, 0.9 * s, 0.6 * s, 4 * s, 4, WOOD_D, { Parent = parent })
		for i, w in { 6, 4.6, 3.2 } do
			Poly.Cone(cf * CFrame.new(0, (2 + i * 3.4) * s, 0), w * s, 6 * s, 6, if i % 2 == 0 then rgb(52, 130, 80) else rgb(60, 144, 88), { Parent = parent }, rng)
		end
	end

	local failed = 0
	local function section(name, fn)
		local ok, err = pcall(fn)
		if ok then
			print("[BuildMap] OK: " .. name)
		else
			failed += 1
			warn("[BuildMap] FAILED in " .. name .. ": " .. tostring(err))
		end
	end

	-- Base slots: 2 per side, numbered in order around the pond
	local slots = {}
	for s = 0, 3 do
		for _, x in { -BASE_X, BASE_X } do
			local p = sideCF(s) * Vector3.new(x, 0, BASE_Z)
			table.insert(slots, { side = s, x = x, ang = math.atan2(p.X, p.Z) })
		end
	end
	table.sort(slots, function(a, b)
		return a.ang < b.ang
	end)

	---------------------------------------------------------------------------------------------
	section("Ground", function()
		-- Patchwork grass tiles (flat-shaded low-poly look)
		local TILE = 36
		local rng = Random.new(11)
		for ix = -12, 11 do
			for iz = -12, 11 do
				local cx, cz = (ix + 0.5) * TILE, (iz + 0.5) * TILE
				if math.abs(cx) - TILE / 2 >= SHORE - 0.01 or math.abs(cz) - TILE / 2 >= SHORE - 0.01 then
					mk("Grass", Vector3.new(TILE, 4, TILE), CFrame.new(cx, -2, cz), GRASS[rng:NextInteger(1, #GRASS)], fGround)
				end
			end
		end
		-- Fill between the tile grid and the sand
		ring("GrassFill", SHORE, SHORE + TILE, -0.05, -4, GRASS[2], fGround)
		ring("Sand", POND, SHORE, 0, -4, SAND, fGround)
		ring("SandLip", POND, POND + 3, 0.15, -0.5, SAND_D, fGround)
	end)

	section("Cliffs", function()
		local rng = Random.new(17)
		for s = 0, 3 do
			local cf = sideCF(s)
			local seg = 30
			local n = math.ceil((ISLAND * 2 + 80) / seg)
			local heights = {}
			for i = 0, n do
				heights[i] = rng:NextNumber(30, 58)
			end
			for i = 0, n - 1 do
				local x0 = -ISLAND - 40 + i * seg
				local x1 = x0 + seg
				local h0, h1 = heights[i], heights[i + 1]
				local foot0, foot1 = cf * Vector3.new(x0, 0, ISLAND), cf * Vector3.new(x1, 0, ISLAND)
				local mid0 = cf * Vector3.new(x0, h0 * 0.5, ISLAND + 8 + rng:NextNumber(-2, 2))
				local mid1 = cf * Vector3.new(x1, h1 * 0.5, ISLAND + 8 + rng:NextNumber(-2, 2))
				local top0, top1 = cf * Vector3.new(x0, h0, ISLAND + 20), cf * Vector3.new(x1, h1, ISLAND + 20)
				local back0, back1 = cf * Vector3.new(x0, h0 * 0.95, ISLAND + 46), cf * Vector3.new(x1, h1 * 0.95, ISLAND + 46)
				quad(foot0, foot1, mid1, mid0, Poly.Shade(DIRT, rng:NextNumber(-0.08, 0.08)), fCliffs)
				quad(mid0, mid1, top1, top0, Poly.Shade(ROCK, rng:NextNumber(-0.1, 0.06)), fCliffs)
				quad(top0, top1, back1, back0, GRASS[(i % #GRASS) + 1], fCliffs)
				if rng:NextNumber() < 0.35 then
					Poly.Rock(cf * CFrame.new(x0 + rng:NextNumber(4, seg - 4), 2, ISLAND - 3), Vector3.new(8, 6, 6), ROCK, rng, { Parent = fCliffs })
				end
			end
			-- Invisible wall so nobody climbs out
			mk("Boundary", Vector3.new(ISLAND * 2 + 100, 120, 4), cf * CFrame.new(0, 60, ISLAND + 2), ROCK, fCliffs, { transparency = 1, noShadow = true })
		end
	end)

	section("Dive pit", function()
		local rng = Random.new(23)
		local OUTER = ISLAND + 40
		for k, z in Zones.List do
			local top = if k == 1 then -4 else z.Top
			-- Solid rock around this zone's water
			ring("PitWall" .. k, z.Half, OUTER, top, z.Bottom, z.Wall, fPit)
			-- Water
			local wTop = if k == 1 then Zones.WaterLevel else z.Top
			terrain:FillBlock(CFrame.new(0, (wTop + z.Bottom) / 2, 0), Vector3.new(2 * z.Half, wTop - z.Bottom, 2 * z.Half), Enum.Material.Water)
			-- Jagged rock facade on the inside of the wall
			local rows = math.max(2, math.floor((top - z.Bottom) / 30 + 0.5))
			for s = 0, 3 do
				local cf = sideCF(s)
				local cols = math.max(2, math.floor(z.Half * 2 / 26 + 0.5))
				local grid = {}
				for c = 0, cols do
					grid[c] = {}
					for r = 0, rows do
						local x = -z.Half + c * (z.Half * 2 / cols)
						local y = top - r * ((top - z.Bottom) / rows)
						local edge = c == 0 or c == cols or r == 0
						local inset = if edge then 0.3 else rng:NextNumber(0.6, 3.2)
						grid[c][r] = cf * Vector3.new(x, y, z.Half - inset)
					end
				end
				for c = 0, cols - 1 do
					for r = 0, rows - 1 do
						quad(grid[c][r], grid[c + 1][r], grid[c + 1][r + 1], grid[c][r + 1], Poly.Shade(z.Wall, rng:NextNumber(-0.12, 0.1)), fPit)
					end
				end
			end
			-- Seabed: the shelf on this zone's floor (or the very bottom)
			if k == #Zones.List then
				mk("RiftFloor", Vector3.new(z.Half * 2, 6, z.Half * 2), CFrame.new(0, z.Bottom - 3, 0), z.Floor, fPit)
			end
			local inner = z.ShelfInner
			for s = 0, 3 do
				local cf = sideCF(s)
				local cols = math.max(2, math.floor(z.Half * 2 / 24 + 0.5))
				for c = 0, cols - 1 do
					local x0 = -z.Half + c * (z.Half * 2 / cols)
					local x1 = x0 + z.Half * 2 / cols
					local function p(x, zz)
						return cf * Vector3.new(x, z.Bottom + rng:NextNumber(0.1, 1.6), zz)
					end
					if k < #Zones.List then
						local a, b = p(x0, z.Half - 0.5), p(x1, z.Half - 0.5)
						local c1, d = p(math.clamp(x1, -inner, inner), inner), p(math.clamp(x0, -inner, inner), inner)
						quad(a, b, c1, d, Poly.Shade(z.Floor, rng:NextNumber(-0.1, 0.08)), fPit)
					end
				end
			end
			-- Hazy layer where this zone begins (a thermocline you can see from above and below)
			if k > 1 then
				mk("FogLayer" .. k, Vector3.new(z.Half * 2 - 1, 0.4, z.Half * 2 - 1), CFrame.new(0, z.Top - 1.5, 0), z.Fog, fPit,
					{ deco = true, transparency = 0.82, noShadow = true })
				mk("FogLayer" .. k .. "b", Vector3.new(z.Half * 2 - 1, 0.4, z.Half * 2 - 1), CFrame.new(0, z.Top - 5, 0), z.FogDeep, fPit,
					{ deco = true, transparency = 0.86, noShadow = true })
			end
		end
	end)

	section("Seabed decor", function()
		local rng = Random.new(31)
		local function shelfPoint(z, margin)
			local t = rng:NextNumber(z.ShelfInner + margin, z.Half - margin)
			local s = rng:NextNumber(-z.Half + margin, z.Half - margin)
			if rng:NextInteger(0, 1) == 0 then
				return s, if rng:NextInteger(0, 1) == 0 then t else -t
			end
			return if rng:NextInteger(0, 1) == 0 then t else -t, s
		end
		local Z = Zones.List
		-- Sunlit Shallows: kelp, starfish, coral, anemones and pale rocks on sand
		for _ = 1, 84 do
			local x, zz = shelfPoint(Z[1], 3)
			local base = Vector3.new(x, Z[1].Bottom + 0.5, zz)
			local h = rng:NextNumber(14, 34)
			local green = rgb(70 + rng:NextInteger(-10, 20), 160 + rng:NextInteger(-20, 30), 70)
			for b = 0, 2 do
				local a = b * 2.1 + rng:NextNumber(0, 1)
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				local tip = base + Vector3.new(0, h * rng:NextNumber(0.6, 1), 0) + dir * rng:NextNumber(1, 4)
				tri(base + dir * 0.8, base - dir * 0.8, tip, Poly.Shade(green, b * 0.06), fDecor)
			end
		end
		for _ = 1, 20 do
			local x, zz = shelfPoint(Z[1], 3)
			local c = Vector3.new(x, Z[1].Bottom + 1.1, zz)
			local col = ({ rgb(255, 120, 90), rgb(255, 180, 60), rgb(240, 90, 160) })[rng:NextInteger(1, 3)]
			for p = 0, 4 do
				local a0 = p / 5 * math.pi * 2
				local arm = c + Vector3.new(math.cos(a0), 0.05, math.sin(a0)) * 1.8
				tri(c, c + Vector3.new(math.cos(a0 - 0.35), 0, math.sin(a0 - 0.35)) * 0.6, arm, col, fDecor)
				tri(c, arm, c + Vector3.new(math.cos(a0 + 0.35), 0, math.sin(a0 + 0.35)) * 0.6, Poly.Shade(col, -0.12), fDecor)
			end
		end
		for _ = 1, 16 do
			local x, zz = shelfPoint(Z[1], 4)
			Poly.Rock(CFrame.new(x, Z[1].Bottom + 1.5, zz), Vector3.new(rng:NextNumber(4, 9), rng:NextNumber(3, 6), rng:NextNumber(4, 9)), rgb(170, 160, 140), rng, { Parent = fDecor })
		end
		local bright = { rgb(255, 120, 150), rgb(255, 190, 70), rgb(120, 230, 210), rgb(190, 130, 255), rgb(255, 150, 90) }
		for _ = 1, 28 do
			local x, zz = shelfPoint(Z[1], 4)
			local col = bright[rng:NextInteger(1, #bright)]
			local base = CFrame.new(x, Z[1].Bottom, zz)
			for b = 0, 3 do
				local a = b * 1.6 + rng:NextNumber(0, 0.8)
				local lean = CFrame.Angles(math.cos(a) * 0.35, 0, math.sin(a) * 0.35)
				Poly.Cone(base * CFrame.new(math.cos(a) * 1.1, 0, math.sin(a) * 1.1) * lean, rng:NextNumber(0.5, 0.8), rng:NextNumber(2.5, 6), 4, Poly.Shade(col, b * 0.05), { Parent = fDecor }, rng)
			end
		end
		-- anemones: a ring of short tentacles on a little disc
		for _ = 1, 16 do
			local x, zz = shelfPoint(Z[1], 4)
			local c = Vector3.new(x, Z[1].Bottom + 0.6, zz)
			local col = ({ rgb(255, 120, 200), rgb(140, 255, 160), rgb(255, 220, 120) })[rng:NextInteger(1, 3)]
			for t = 0, 7 do
				local a = t / 8 * math.pi * 2
				local d = Vector3.new(math.cos(a), 0, math.sin(a))
				tri(c + d * 0.9 + Vector3.new(0, 0, 0.25), c + d * 0.9 - Vector3.new(0, 0, 0.25), c + d * 1.7 + Vector3.new(0, rng:NextNumber(1.6, 2.6), 0), Poly.Shade(col, (t % 2) * 0.08), fDecor)
			end
			Poly.Cone(CFrame.new(c - Vector3.new(0, 0.6, 0)), 1.2, 0.8, 6, Poly.Shade(col, -0.25), { Parent = fDecor }, rng)
		end
		-- Coral Reef: coral heads, branching coral and sea fans
		local corals = { rgb(255, 110, 140), rgb(255, 170, 70), rgb(170, 110, 255), rgb(80, 220, 210), rgb(255, 220, 90) }
		for _ = 1, 22 do
			local x, zz = shelfPoint(Z[2], 4)
			local col = corals[rng:NextInteger(1, #corals)]
			local base = Vector3.new(x, Z[2].Bottom, zz)
			local a = rng:NextNumber(0, math.pi * 2)
			local side = Vector3.new(math.cos(a), 0, math.sin(a))
			local h = rng:NextNumber(5, 10)
			for f = -2, 2 do
				local tipA = base + side * (f * h * 0.22) + Vector3.new(0, h * (1 - math.abs(f) * 0.12), 0)
				local tipB = base + side * ((f + 1) * h * 0.22) + Vector3.new(0, h * (1 - math.abs(f + 1) * 0.12), 0)
				if f < 2 then
					tri(base, tipA, tipB, Poly.Shade(col, (f % 2) * 0.08), fDecor)
				end
			end
		end
		for _ = 1, 56 do
			local x, zz = shelfPoint(Z[2], 4)
			local col = corals[rng:NextInteger(1, #corals)]
			local base = CFrame.new(x, Z[2].Bottom, zz)
			if rng:NextNumber() < 0.5 then
				local s = rng:NextNumber(3, 7)
				Poly.Blob(base * CFrame.new(0, s * 0.4, 0), Vector3.new(s, s * 0.8, s), col, rng, { Parent = fDecor })
			else
				for b = 0, 2 do
					local a = b * 2.1
					Poly.Cone(base * CFrame.new(math.cos(a) * 1.2, 0, math.sin(a) * 1.2) * CFrame.Angles(math.cos(a) * 0.3, 0, math.sin(a) * 0.3), 0.7, rng:NextNumber(3, 8), 4, col, { Parent = fDecor }, rng)
				end
			end
		end
		-- Twilight Trench: dark spires and glowing crystals
		for _ = 1, 22 do
			local x, zz = shelfPoint(Z[3], 4)
			Poly.Cone(CFrame.new(x, Z[3].Bottom, zz), rng:NextNumber(2, 4), rng:NextNumber(8, 22), 5, rgb(70, 74, 100), { Parent = fDecor }, rng)
		end
		for _ = 1, 26 do
			local x, zz = shelfPoint(Z[3], 3)
			local cf = CFrame.new(x, Z[3].Bottom, zz) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
			Poly.Cone(cf, 0.9, rng:NextNumber(2, 6), 4, rgb(110, 150, 255), { Parent = fDecor, Material = Enum.Material.Neon }, rng)
		end
		-- The Abyss: crystal clusters and a whale skeleton
		for _ = 1, 18 do
			local x, zz = shelfPoint(Z[4], 4)
			local base = CFrame.new(x, Z[4].Bottom, zz)
			for c = 0, 2 do
				Poly.Cone(base * CFrame.new(c - 1, 0, (c % 2) * 1.2) * CFrame.Angles((c - 1) * 0.3, 0, 0.2), 1.1, rng:NextNumber(3, 8), 4, rgb(90, 220, 255), { Parent = fDecor, Material = Enum.Material.Neon }, rng)
			end
		end
		do
			local base = CFrame.new(-Z[4].Half + 14, Z[4].Bottom + 1, 0) * CFrame.Angles(0, 0.4, 0)
			for r = 0, 6 do
				local z = r * 4 - 12
				for _, sx in { -1, 1 } do
					tri(base * Vector3.new(0, 0.5, z), base * Vector3.new(0, 0.5, z + 0.8), base * Vector3.new(sx * 5, 6 - math.abs(r - 3) * 0.6, z + 0.4), rgb(235, 230, 215), fDecor)
				end
			end
		end
		-- Rock outcrops on every zone's walls so they aren't flat
		for k, z in ipairs(Z) do
			local count = if k == #Z then 8 else 14
			for _ = 1, count do
				local along = rng:NextNumber(-z.Half + 10, z.Half - 10)
				local y = rng:NextNumber(z.Bottom + 8, z.Top - 6)
				local side = rng:NextInteger(1, 4)
				local inset = z.Half - 2.5
				local p = if side == 1 then Vector3.new(inset, y, along)
					elseif side == 2 then Vector3.new(-inset, y, along)
					elseif side == 3 then Vector3.new(along, y, inset)
					else Vector3.new(along, y, -inset)
				local size = Vector3.new(rng:NextNumber(12, 24), rng:NextNumber(8, 16), rng:NextNumber(12, 24))
				Poly.Rock(CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), size, Poly.Shade(z.Wall, rng:NextNumber(-0.08, 0.1)), rng, { Parent = fDecor })
			end
		end
		-- Leviathan's Rift: ruined pillars and purple crystals
		local rift = Z[5]
		for p = 0, 7 do
			local a = p / 8 * math.pi * 2
			local cf = CFrame.new(math.cos(a) * 52, rift.Bottom, math.sin(a) * 52)
			local h = rng:NextNumber(10, 26)
			Poly.Frustum(cf, 3, 2.6, h, 6, rgb(90, 80, 110), { Parent = fDecor })
			mk("PillarCap", Vector3.new(7, 1.5, 7), cf * CFrame.new(0, h + 0.75, 0), rgb(110, 100, 130), fDecor)
		end
		for _ = 1, 24 do
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(20, 70)
			Poly.Cone(CFrame.new(math.cos(a) * r, rift.Bottom, math.sin(a) * r), 1.3, rng:NextNumber(4, 12), 4, rgb(200, 90, 255), { Parent = fDecor, Material = Enum.Material.Neon }, rng)
		end
	end)

	section("Guardian lairs", function()
		local rng = Random.new(41)
		for k, z in Zones.List do
			local lair = Instance.new("Model")
			lair.Name = "Lair" .. k
			lair:SetAttribute("Zone", z.Name)
			lair.Parent = fLairs
			local floor = Vector3.new(z.Lair.X, z.Bottom, z.Lair.Z)
			local r = if k == #Zones.List then 26 else 10
			for i = 0, 6 do
				local a = i / 7 * math.pi * 2
				Poly.Rock(CFrame.new(floor + Vector3.new(math.cos(a) * r, 2, math.sin(a) * r)), Vector3.new(6, rng:NextNumber(3, 6), 6), Poly.Shade(z.Wall, 0.05), rng, { Parent = lair })
			end
			local glow = Color3.fromHSV((0.12 + k * 0.12) % 1, 0.6, 1)
			for i = 0, 5 do
				local a = i / 6 * math.pi * 2
				Poly.Cone(CFrame.new(floor + Vector3.new(math.cos(a) * 3, 0, math.sin(a) * 3)), 0.9, rng:NextNumber(2, 4), 4, glow, { Parent = lair, Material = Enum.Material.Neon }, rng)
			end
			local marker = mk("LairCenter", Vector3.new(2, 1, 2), CFrame.new(floor + Vector3.new(0, 0.5, 0)), glow, lair, { material = Enum.Material.Neon, deco = true })
			light(marker, 40, glow, 2)
		end
	end)

	---------------------------------------------------------------------------------------------
	-- Docks: walkway from the shore out to a platform over the shallows' shelf.
	-- The legs go all the way down to the seabed.
	local function buildDock(cf, x, walkW, platW, parent)
		local i = 0
		local function planks(width, zFrom, zTo)
			local z = zFrom
			while z - 2 >= zTo - 0.01 do
				i += 1
				mk("Plank", Vector3.new(width, 0.6, 1.85), cf * CFrame.new(x, DECK_Y, z - 1), ({ WOOD1, WOOD2, WOOD3 })[i % 3 + 1], parent)
				z -= 2
			end
		end
		planks(walkW, DOCK_FROM, DOCK_TO)
		planks(platW, DOCK_TO, DOCK_TO - PLAT_D)
		local walkLen = DOCK_FROM - DOCK_TO
		for _, side in { -1, 1 } do
			mk("Stringer", Vector3.new(0.8, 0.8, walkLen), cf * CFrame.new(x + side * (walkW / 2 - 1), 0.2, (DOCK_FROM + DOCK_TO) / 2), WOOD_D, parent)
		end
		local zf, zb = DOCK_TO - PLAT_D + 0.6, DOCK_TO - 0.6
		local xl, xr = x - platW / 2 + 0.6, x + platW / 2 - 0.6
		local legs = { { xl, zf }, { xr, zf }, { xl, zb }, { xr, zb }, { x - walkW / 2 + 0.7, POND - 3 }, { x + walkW / 2 - 0.7, POND - 3 } }
		for _, p in legs do
			local foot = cf * CFrame.new(p[1], SHELF_Y, p[2])
			mk("Leg", Vector3.new(1.2, 2.6 - SHELF_Y, 1.2), foot * CFrame.new(0, (2.6 - SHELF_Y) / 2, 0) * CFrame.Angles(0, math.rad(45), 0), WOOD_D, parent, { noQuery = true })
		end
		mk("Brace", Vector3.new(platW - 1, 0.6, 0.6), cf * CFrame.new(x, -0.4, zf), WOOD_D, parent)
		mk("Brace", Vector3.new(platW - 1, 0.6, 0.6), cf * CFrame.new(x, -0.4, zb), WOOD_D, parent)
		local railY = 2.3
		local function rail(ax, az, bx, bz)
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			mk("Rail", Vector3.new(0.4, 0.4, len - 1.2), cf * CFrame.lookAt(Vector3.new((ax + bx) / 2, railY, (az + bz) / 2), Vector3.new(bx, railY, bz)), WOOD_D, parent, { noQuery = true })
		end
		rail(xl, zf, x - 1.8, zf)
		rail(x + 1.8, zf, xr, zf)
		rail(xl, zf, xl, zb)
		rail(xr, zf, xr, zb)
		local ladder = mk("Ladder", Vector3.new(2, 12, 2), cf * CFrame.new(x, -4.8, DOCK_TO - PLAT_D - 1), WOOD_D, parent, { class = "TrussPart", noQuery = true })
		ladder.Material = Enum.Material.Wood
		lantern(cf * CFrame.new(xl, 2.6, zf), parent)
	end

	section("Bases", function()
		local H = BASE / 2
		for idx, sl in slots do
			local scf = sideCF(sl.side)
			local cf = scf * CFrame.new(sl.x, 0, BASE_Z) -- local -Z faces the pond

			local plot = Instance.new("Model")
			plot.Name = "Base" .. idx
			plot:SetAttribute("BaseIndex", idx)
			plot.Parent = fBases
			CollectionService:AddTag(plot, "Plot")

			local floor = mk("Floor", Vector3.new(BASE, 0.6, BASE), cf * CFrame.new(0, 0.3, 0), STONE, plot)
			plot.PrimaryPart = floor
			for r = 0, 9 do
				mk("Deck", Vector3.new(BASE - 8, 0.2, (BASE - 8) / 10 - 0.2), cf * CFrame.new(0, 0.7, -H + 4 + (r + 0.5) * (BASE - 8) / 10), if r % 2 == 0 then WOOD1 else WOOD3, plot)
			end

			-- Hedge walls with pitched tops, open at the front
			local function hedge(len, at, alongX)
				local rot = if alongX then CFrame.new() else CFrame.Angles(0, math.rad(90), 0)
				local base = cf * at * rot
				mk("Hedge", Vector3.new(len, 2.6, 2.2), base * CFrame.new(0, 1.9, 0), HEDGE_D, plot)
				mk("HedgeTop", Vector3.new(len, 1, 1.1), base * CFrame.new(0, 3.7, -0.55), HEDGE, plot, { class = "WedgePart" })
				mk("HedgeTop", Vector3.new(len, 1, 1.1), base * CFrame.new(0, 3.7, 0.55) * CFrame.Angles(0, math.pi, 0), HEDGE, plot, { class = "WedgePart" })
			end
			hedge(BASE - 6, CFrame.new(0, 0, H - 1.5), true)
			hedge(BASE - 6, CFrame.new(-H + 1.5, 0, 0), false)
			hedge(BASE - 6, CFrame.new(H - 1.5, 0, 0), false)
			local frontLen = H - 3 - 7.5
			hedge(frontLen, CFrame.new(-(7.5 + frontLen / 2), 0, -H + 1.5), true)
			hedge(frontLen, CFrame.new(7.5 + frontLen / 2, 0, -H + 1.5), true)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					mk("Pillar", Vector3.new(3, 5, 3), cf * CFrame.new(sx * (H - 1.5), 3.1, sz * (H - 1.5)), STONE, plot)
					mk("PillarCap", Vector3.new(3.6, 0.6, 3.6), cf * CFrame.new(sx * (H - 1.5), 5.9, sz * (H - 1.5)), STONE_D, plot)
				end
				lantern(cf * CFrame.new(sx * (H - 1.5), 6.2, -H + 1.5), plot)
			end
			-- Gate with the owner's sign
			for _, sx in { -1, 1 } do
				mk("GatePillar", Vector3.new(3, 9, 3), cf * CFrame.new(sx * 6, 5.1, -H + 1.5), STONE, plot)
				mk("GateCap", Vector3.new(3.6, 0.6, 3.6), cf * CFrame.new(sx * 6, 9.9, -H + 1.5), STONE_D, plot)
				mk("SignChain", Vector3.new(0.2, 1.2, 0.2), cf * CFrame.new(sx * 3.2, 9.6, -H + 1.5), rgb(70, 70, 76), plot, { deco = true })
			end
			mk("GateBeam", Vector3.new(15.6, 0.8, 0.8), cf * CFrame.new(0, 10.6, -H + 1.5), WOOD_D, plot)
			local signCF = cf * CFrame.new(0, 7.6, -H + 1.5)
			mk("SignFrame", Vector3.new(8.8, 3.4, 0.3), signCF, WOOD_D, plot, { deco = true })
			local sign = mk("Sign", Vector3.new(8.2, 2.8, 0.5), signCF, WOOD1, plot, { deco = true })
			signText(sign, Enum.NormalId.Front, "BASE " .. idx)
			signText(sign, Enum.NormalId.Back, "BASE " .. idx)

			-- Big aquarium: your best catches swim in here
			local T = CFrame.new(0, 0, 12)
			local TW, TH, TD = 34, 14, 18
			mk("TankStand", Vector3.new(TW + 2, 2.4, TD + 2), cf * T * CFrame.new(0, 1.8, 0), WOOD2, plot)
			mk("TankStandTrim", Vector3.new(TW + 2.6, 0.5, TD + 2.6), cf * T * CFrame.new(0, 3.05, 0), WOOD_D, plot)
			local baseY = 3.3
			mk("TankGlass", Vector3.new(TW, TH, TD), cf * T * CFrame.new(0, baseY + TH / 2, 0), rgb(200, 235, 255), plot, { material = Enum.Material.Glass, transparency = 0.8 })
			mk("TankSand", Vector3.new(TW - 0.6, 0.8, TD - 0.6), cf * T * CFrame.new(0, baseY + 0.4, 0), SAND, plot, { deco = true })
			local water = mk("TankWater", Vector3.new(TW - 0.6, TH - 1.6, TD - 0.6), cf * T * CFrame.new(0, baseY + 0.8 + (TH - 1.6) / 2, 0), rgb(70, 180, 240), plot, { deco = true, transparency = 0.6, noShadow = true })
			water.Name = "TankWater"
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					mk("TankEdge", Vector3.new(0.6, TH, 0.6), cf * T * CFrame.new(sx * TW / 2, baseY + TH / 2, sz * TD / 2), WOOD_D, plot)
				end
				mk("TankRim", Vector3.new(TW + 0.6, 0.6, 0.6), cf * T * CFrame.new(0, baseY + TH, sx * TD / 2), WOOD_D, plot)
				mk("TankRim", Vector3.new(0.6, 0.6, TD + 0.6), cf * T * CFrame.new(sx * TW / 2, baseY + TH, 0), WOOD_D, plot)
			end
			local strip = mk("TankLight", Vector3.new(TW - 4, 0.2, 1.2), cf * T * CFrame.new(0, baseY + TH - 0.3, 0), rgb(210, 240, 255), plot, { material = Enum.Material.Neon, deco = true })
			light(strip, 22, rgb(150, 220, 255), 1)
			local rng = Random.new(idx)
			for d = 1, 5 do
				local px = rng:NextNumber(-TW / 2 + 3, TW / 2 - 3)
				local pz = rng:NextNumber(-TD / 2 + 3, TD / 2 - 3)
				if d <= 2 then
					Poly.Rock(cf * T * CFrame.new(px, baseY + 1.6, pz), Vector3.new(3, 2, 3), rgb(150, 150, 160), rng, { Parent = plot })
				else
					Poly.Cone(cf * T * CFrame.new(px, baseY + 0.8, pz), 0.8, rng:NextNumber(3, 6), 4, ({ rgb(255, 120, 150), rgb(90, 220, 200), rgb(255, 190, 80) })[d - 2], { Parent = plot }, rng)
				end
			end

			-- Spawn pad, bench and spear rack
			mk("Spawn", Vector3.new(8, 0.2, 8), cf * CFrame.new(0, 0.9, -18), rgb(250, 210, 110), plot, { deco = true })
			local Bn = cf * CFrame.new(22, 0.6, -22)
			mk("BenchSeat", Vector3.new(6, 0.5, 2), Bn * CFrame.new(0, 1.7, 0), WOOD1, plot)
			mk("BenchBack", Vector3.new(6, 2, 0.4), Bn * CFrame.new(0, 3, 1.2), WOOD1, plot)
			for _, bx in { -2.5, 2.5 } do
				mk("BenchLeg", Vector3.new(0.5, 1.45, 1.6), Bn * CFrame.new(bx, 0.72, 0), WOOD_D, plot)
			end
			local R = cf * CFrame.new(-22, 0.6, -22)
			for _, rx in { -3, 3 } do
				mk("RackPost", Vector3.new(0.6, 4, 0.6), R * CFrame.new(rx, 2, 0), WOOD_D, plot)
			end
			mk("RackBar", Vector3.new(7, 0.5, 0.5), R * CFrame.new(0, 3.7, 0), WOOD_D, plot)
			for k = 1, 3 do
				local rcf = R * CFrame.new(-3 + k * 1.5, 2.95, -0.9) * CFrame.Angles(math.rad(14), 0, 0)
				cyl("RackSpear", 0.22, 6, rcf, rgb(196, 202, 212), plot, { deco = true, material = Enum.Material.Metal })
				mk("RackSpearTip", Vector3.new(0.4, 0.7, 0.4), rcf * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, math.rad(45), 0), rgb(160, 166, 176), plot, { deco = true, material = Enum.Material.Metal })
			end

			path(scf, sl.x, 6, BASE_Z - H, DOCK_FROM, plot)
			buildDock(scf, sl.x, 7, 15, plot)
		end
	end)

	section("Public piers", function()
		for s = 0, 3 do
			local m = Instance.new("Model")
			m.Name = "PublicPier" .. (s + 1)
			m.Parent = fPiers
			local scf = sideCF(s)
			buildDock(scf, 0, 10, 20, m)
			mk("SignPost", Vector3.new(0.6, 5, 0.6), scf * CFrame.new(7, 2.5, DOCK_FROM + 1), WOOD_D, m)
			board("PierSign", 6, 1.6, scf * CFrame.new(7, 4.4, DOCK_FROM + 0.6), m, "PUBLIC PIER", true)
		end
	end)

	section("Town", function()
		local TZ = 80 -- the town sits between the two south bases
		local function at(x, y, z)
			return CFrame.new(x, y, z + TZ)
		end
		mk("Plaza", Vector3.new(36, 0.3, 56), at(0, 0.05, 208), PAVE1, fTown)
		for _, sx in { -1, 1 } do
			mk("PlazaTrim", Vector3.new(1, 0.4, 56), at(sx * 18.5, 0.1, 208), STONE_D, fTown)
		end
		for _, z in { 179.5, 236.5 } do
			mk("PlazaTrim", Vector3.new(38, 0.4, 1), at(0, 0.1, z), STONE_D, fTown)
		end
		mk("PlazaInlay", Vector3.new(16, 0.4, 16), at(0, 0.1, 214) * CFrame.Angles(0, math.rad(45), 0), PAVE2, fTown)
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Size = Vector3.new(10, 0.4, 10)
		spawn.CFrame = at(0, 0.3, 214)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Color = GOLD
		spawn.Material = Enum.Material.SmoothPlastic
		for _, f in FACES do
			spawn[f] = Enum.SurfaceType.Smooth
		end
		spawn.Parent = fTown
		path(CFrame.new(0, 0, TZ), 0, 8, 179, DOCK_FROM - TZ, fTown)
		path(CFrame.new(0, 0, TZ), 0, 6, 257, 237, fTown)

		-- Entrance arch
		for _, sx in { -1, 1 } do
			mk("ArchBase", Vector3.new(4, 1, 4), at(sx * 10, 0.5, 182), STONE_D, fTown)
			Poly.Frustum(at(sx * 10, 1, 182), 1.9, 1.5, 13, 6, STONE, { Parent = fTown })
			mk("ArchCap", Vector3.new(4, 1, 4), at(sx * 10, 14.5, 182), STONE_D, fTown)
			lampPost(at(sx * 14.5, 0, 182), fTown, 7)
		end
		local beam = mk("ArchBeam", Vector3.new(26, 3.4, 3), at(0, 16.6, 182), rgb(40, 120, 190), fTown)
		signText(beam, Enum.NormalId.Front, "SPEARFISHING COVE", GOLD)
		signText(beam, Enum.NormalId.Back, "SPEARFISHING COVE", GOLD)

		for _, sx in { -1, 1 } do
			local Bn = at(sx * 14, 0, 200) * CFrame.Angles(0, sx * math.rad(90), 0)
			mk("BenchSeat", Vector3.new(6, 0.5, 2), Bn * CFrame.new(0, 1.9, 0), WOOD1, fTown)
			mk("BenchBack", Vector3.new(6, 2, 0.4), Bn * CFrame.new(0, 3.2, 1.2), WOOD1, fTown)
			for _, bx in { -2.5, 2.5 } do
				mk("BenchLeg", Vector3.new(0.5, 1.5, 1.6), Bn * CFrame.new(bx, 0.9, 0), WOOD_D, fTown)
			end
			local P = at(sx * 13, 0, 231)
			mk("Planter", Vector3.new(5, 1.6, 5), P * CFrame.new(0, 0.8, 0), STONE_D, fTown)
			Poly.Blob(P * CFrame.new(0, 3, 0), Vector3.new(4, 3, 4), HEDGE, Random.new(sx + 5), { Parent = fTown })
		end

		-- GEAR SHOP
		local S = at(0, 0, 266)
		mk("ShopFoundation", Vector3.new(27, 1, 19), S * CFrame.new(0, 0.5, 0), STONE_D, fTown)
		mk("ShopWalls", Vector3.new(26, 12, 18), S * CFrame.new(0, 7, 0), CREAM, fTown)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				mk("Timber", Vector3.new(1, 12, 1), S * CFrame.new(sx * 12.75, 7, sz * 8.75), WOOD_D, fTown)
			end
			mk("Timber", Vector3.new(0.8, 10.4, 0.4), S * CFrame.new(sx * 6.5, 7, -9.2), WOOD_D, fTown)
			mk("Timber", Vector3.new(9.9, 0.8, 0.3), S * CFrame.new(sx * 8.05, 7, -9.15), WOOD_D, fTown)
		end
		mk("Timber", Vector3.new(25.5, 0.8, 0.3), S * CFrame.new(0, 12.6, -9.15), WOOD_D, fTown)
		mk("Roof", Vector3.new(28, 6, 10.5), S * CFrame.new(0, 16, -5.25), ROOF, fTown, { class = "WedgePart" })
		mk("Roof", Vector3.new(28, 6, 10.5), S * CFrame.new(0, 16, 5.25) * CFrame.Angles(0, math.pi, 0), ROOF_D, fTown, { class = "WedgePart" })
		mk("RoofRidge", Vector3.new(28.4, 0.8, 1.4), S * CFrame.new(0, 19.2, 0), ROOF_D, fTown)
		mk("Chimney", Vector3.new(2.4, 7, 2.4), S * CFrame.new(8, 18.5, 4), STONE_D, fTown)
		local door = mk("ShopDoor", Vector3.new(5, 8, 0.4), S * CFrame.new(0, 5, -9.2), WOOD2, fTown)
		CollectionService:AddTag(door, "GearShop")
		for _, sx in { -1, 1 } do
			mk("DoorFrame", Vector3.new(0.6, 8.6, 0.5), S * CFrame.new(sx * 2.8, 5.3, -9.25), WOOD_D, fTown)
			local W = S * CFrame.new(sx * 9.5, 0, 0)
			mk("Window", Vector3.new(4, 3.6, 0.2), W * CFrame.new(0, 9.6, -9.15), rgb(190, 230, 250), fTown, { material = Enum.Material.Glass, transparency = 0.3 })
			mk("FlowerBox", Vector3.new(4.6, 0.8, 1), W * CFrame.new(0, 7.8, -9.8), WOOD1, fTown)
		end
		board("ShopSign", 8.4, 1.8, S * CFrame.new(0, 11.0, -9.15), fTown, "GEAR SHOP")
		for _, sx in { -1, 1 } do
			lampPost(at(sx * 5, 0, 247), fTown, 6)
		end

		-- FISH MARKET stall (faces the plaza)
		local M = at(-38, 0, 212) * CFrame.Angles(0, math.rad(-90), 0)
		mk("StallFloor", Vector3.new(14, 0.4, 10), M * CFrame.new(0, 0.2, 0), WOOD2, fTown)
		for _, sx in { -1, 1 } do
			mk("StallPost", Vector3.new(0.8, 8.2, 0.8), M * CFrame.new(sx * 6.6, 4.5, -4.6), WOOD_D, fTown)
			mk("StallPost", Vector3.new(0.8, 10.1, 0.8), M * CFrame.new(sx * 6.6, 5.45, 4.6), WOOD_D, fTown)
		end
		local counter = mk("MarketCounter", Vector3.new(12, 3.4, 1.6), M * CFrame.new(0, 2.1, -3.6), WOOD1, fTown)
		CollectionService:AddTag(counter, "Merchant")
		mk("CounterTop", Vector3.new(12.2, 0.4, 2.2), M * CFrame.new(0, 4.0, -3.6), WOOD_D, fTown)
		mk("IceTray", Vector3.new(11, 0.3, 1.6), M * CFrame.new(0, 4.35, -3.6), rgb(225, 242, 255), fTown, { material = Enum.Material.Ice })
		for k = 0, 8 do
			mk("Canopy", Vector3.new(1.65, 0.3, 11), M * CFrame.new(-6.6 + k * 1.65, 9.8, 0) * CFrame.Angles(math.rad(-12), 0, 0), if k % 2 == 0 then rgb(60, 150, 230) else rgb(250, 250, 250), fTown)
		end
		board("MarketSign", 8, 2, M * CFrame.new(0, 11.6, -3.4), fTown, "FISH MARKET")
		for _, sx in { -1, 1 } do
			mk("SignPost", Vector3.new(0.4, 1.8, 0.4), M * CFrame.new(sx * 3.5, 9.9, -3.2), WOOD_D, fTown, { deco = true })
		end

		-- PEARL SHOP kiosk (opens the Robux store)
		local K = at(38, 0, 212) * CFrame.Angles(0, math.rad(90), 0)
		mk("KioskBase", Vector3.new(10, 1, 8), K * CFrame.new(0, 0.5, 0), STONE_D, fTown)
		mk("KioskCounter", Vector3.new(9, 3.4, 2), K * CFrame.new(0, 2.7, -2.5), rgb(250, 120, 170), fTown)
		local kioskTop = mk("KioskTop", Vector3.new(9.4, 0.4, 2.4), K * CFrame.new(0, 4.6, -2.5), rgb(255, 230, 120), fTown)
		CollectionService:AddTag(kioskTop, "PearlShop")
		for _, sx in { -1, 1 } do
			mk("KioskPost", Vector3.new(0.6, 8, 0.6), K * CFrame.new(sx * 4.4, 5, -3.2), rgb(255, 255, 255), fTown)
		end
		mk("KioskRoof", Vector3.new(10.4, 1, 4), K * CFrame.new(0, 9.5, -2.4), rgb(250, 120, 170), fTown)
		local pearl = mk("Pearl", Vector3.new(2.4, 2.4, 2.4), K * CFrame.new(0, 11.4, -2.4), rgb(250, 240, 255), fTown, { shape = Enum.PartType.Ball, material = Enum.Material.Neon, deco = true })
		light(pearl, 18, rgb(255, 200, 240), 1.5)
		board("KioskSign", 7, 1.6, K * CFrame.new(0, 7.6, -4.3), fTown, "PEARL SHOP")
	end)

	section("Trees and rocks", function()
		local rng = Random.new(21)
		local placed = {}
		local function toSide(x, z, s)
			local p = CFrame.Angles(0, -s * math.pi / 2, 0) * Vector3.new(x, 0, z)
			return p.X, p.Z
		end
		local function free(x, z, r)
			if math.abs(x) > ISLAND - 8 - r or math.abs(z) > ISLAND - 8 - r then
				return false
			end
			if math.abs(x) < SHORE + 6 + r and math.abs(z) < SHORE + 6 + r then
				return false
			end
			for s = 0, 3 do
				local lx, lz = toSide(x, z, s)
				for _, bx in { -BASE_X, BASE_X } do
					if math.abs(lx - bx) < BASE / 2 + 5 + r and lz > BASE_Z - BASE / 2 - 5 - r and lz < BASE_Z + BASE / 2 + 5 + r then
						return false
					end
					if math.abs(lx - bx) < 5 + r and lz > SHORE - 2 and lz < BASE_Z then
						return false
					end
				end
				if math.abs(lx) < 8 + r and lz > SHORE - 2 and lz < BASE_Z - 40 then
					return false
				end
				if s == 0 and math.abs(lx) < 60 + r and lz > SHORE then
					return false
				end
			end
			for _, p in placed do
				if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < (r + p[3]) ^ 2 then
					return false
				end
			end
			return true
		end
		local function scatter(count, r, nearShore, builder)
			local n, tries = 0, 0
			while n < count and tries < count * 80 do
				tries += 1
				local x, z
				if nearShore then
					local edge = rng:NextNumber(SHORE + 8, SHORE + 26)
					local along = rng:NextNumber(-ISLAND + 20, ISLAND - 20)
					if rng:NextInteger(0, 1) == 0 then
						x, z = along, if rng:NextInteger(0, 1) == 0 then edge else -edge
					else
						x, z = if rng:NextInteger(0, 1) == 0 then edge else -edge, along
					end
				else
					x, z = rng:NextNumber(-ISLAND, ISLAND), rng:NextNumber(-ISLAND, ISLAND)
				end
				if free(x, z, r) then
					n += 1
					table.insert(placed, { x, z, r })
					builder(CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				end
			end
		end
		scatter(18, 6, true, function(cf)
			palm(cf, fNature, rng)
		end)
		scatter(18, 7, false, function(cf)
			roundTree(cf, fNature, rng)
		end)
		scatter(14, 6, false, function(cf)
			pine(cf, fNature, rng)
		end)
		scatter(24, 4, false, function(cf)
			Poly.Rock(cf * CFrame.new(0, 1.2, 0), Vector3.new(rng:NextNumber(4, 8), rng:NextNumber(2.5, 5), rng:NextNumber(4, 8)), ROCK, rng, { Parent = fNature })
		end)
		scatter(18, 3, false, function(cf)
			Poly.Blob(cf * CFrame.new(0, 1.4, 0), Vector3.new(4.5, 2.8, 4.5), HEDGE, rng, { Parent = fNature })
		end)
		local petals = { rgb(255, 120, 150), rgb(255, 220, 80), rgb(250, 250, 250), rgb(170, 120, 255) }
		scatter(18, 3, false, function(cf)
			local col = petals[rng:NextInteger(1, #petals)]
			for k = 1, 4 do
				local a = k * 1.57
				local F = cf * CFrame.new(math.cos(a) * 1.6, 0, math.sin(a) * 1.6)
				mk("Stem", Vector3.new(0.3, 1.6, 0.3), F * CFrame.new(0, 0.8, 0), rgb(70, 150, 70), fNature, { deco = true })
				mk("Bloom", Vector3.new(1, 0.6, 1), F * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, math.rad(45), 0), col, fNature, { deco = true })
			end
		end)
	end)

	section("Lighting", function()
		Lighting.ClockTime = 13.5
		Lighting.Brightness = 2.6
		Lighting.Ambient = Color3.fromRGB(120, 130, 150)
		Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 165)
		Lighting.EnvironmentDiffuseScale = 0.6
		Lighting.EnvironmentSpecularScale = 0.4
		local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
		atm.Density = 0.25
		atm.Haze = 0.6
		atm.Glare = 0.2
		atm.Color = Color3.fromRGB(200, 225, 245)
		atm.Decay = Color3.fromRGB(120, 170, 220)
		atm.Parent = Lighting
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
		bloom.Intensity = 0.25
		bloom.Size = 24
		bloom.Threshold = 1.3
		bloom.Parent = Lighting
		local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.18
		cc.Contrast = 0.08
		cc.Parent = Lighting
	end)

	if failed == 0 then
		print("[BuildMap] Done! Low-poly island v" .. MAP_VERSION .. " with 5 dive zones and 8 bases.")
	else
		warn("[BuildMap] Finished with " .. failed .. " problem(s). Send a screenshot of the orange lines above.")
	end
end

-- Callable like a function: require(game.ServerStorage.BuildMap)()
return setmetatable({ Version = MAP_VERSION }, {
	__call = function()
		build()
	end,
})
