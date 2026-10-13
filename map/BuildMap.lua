-- BuildMap v5
-- Stud-brick castle island with a deep fishing pond.
--   * 8 numbered bases (hedged gardens with a fish tank) each with a private plank dock
--   * 4 public piers, a town plaza with the Rod Shop and Fish Market
--   * every structural brick has studs on all sides
--
-- HOW TO RUN: insert BuildMap.rbxm into Workspace, then type this in the Command Bar and press Enter:
--     require(workspace.BuildMap)()
-- WARNING: wipes Terrain and replaces the "Map" folder.

return function()
	local CollectionService = game:GetService("CollectionService")
	local Lighting = game:GetService("Lighting")

	print("[BuildMap] Starting...")

	local terrain = workspace.Terrain
	terrain:Clear()
	terrain.WaterTransparency = 1
	terrain.WaterReflectance = 0
	terrain.WaterWaveSize = 0
	terrain.WaterWaveSpeed = 0
	terrain.WaterColor = Color3.fromRGB(40, 120, 200)

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
	map.Parent = workspace
	local function folder(name)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = map
		return f
	end
	local fGround, fWalls, fWater = folder("Ground"), folder("Walls"), folder("PolyWater")
	local fBases, fPiers, fTown = folder("Bases"), folder("PublicPiers"), folder("Town")
	local fNature, fUnder = folder("Nature"), folder("Underwater")

	---------------------------------------------------------------------------
	-- Palette
	local GRASS1 = Color3.fromRGB(91, 170, 82)
	local GRASS2 = Color3.fromRGB(83, 160, 76)
	local SAND = Color3.fromRGB(226, 206, 160)
	local STONE = Color3.fromRGB(163, 162, 165)
	local STONE_D = Color3.fromRGB(124, 123, 130)
	local STONE_L = Color3.fromRGB(205, 201, 192)
	local PAVE1 = Color3.fromRGB(184, 178, 166)
	local PAVE2 = Color3.fromRGB(166, 160, 150)
	local WOOD1 = Color3.fromRGB(163, 118, 74)
	local WOOD2 = Color3.fromRGB(150, 106, 64)
	local WOOD3 = Color3.fromRGB(174, 129, 84)
	local WOOD_D = Color3.fromRGB(98, 68, 44)
	local HEDGE = Color3.fromRGB(70, 142, 72)
	local HEDGE_D = Color3.fromRGB(56, 120, 60)
	local CREAM = Color3.fromRGB(239, 229, 205)
	local ROOF = Color3.fromRGB(184, 68, 60)
	local ROOF_D = Color3.fromRGB(140, 48, 44)
	local GOLD = Color3.fromRGB(240, 196, 72)
	local LAMP = Color3.fromRGB(255, 214, 140)

	-- Layout (studs). Each side of the island uses the same local frame:
	-- x runs along the side, +z points from the pond out toward that side's wall.
	local HALF = 300 -- wall line
	local WALL_T, WALL_H = 8, 36
	local POND, SHORE = 120, 150 -- water edge, sand edge
	local BASE_X, BASE_Z, BASE = 80, 222, 50
	local DOCK_FROM, DOCK_TO, PLAT_D = 146, 108, 12
	local DECK_Y = 0.9 -- plank centre; deck top is 1.2

	---------------------------------------------------------------------------
	-- Helpers
	local FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

	-- o: { class, shape, material, smooth, transparency, deco (no collide/query), noQuery, noShadow }
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
		local studded = not (o.smooth or o.material)
		p.Material = o.material or (o.smooth and Enum.Material.SmoothPlastic) or Enum.Material.Plastic
		local surface = if studded then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth
		for _, f in FACES do
			p[f] = surface
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

	-- Upright cylinder centred on cf
	local function cyl(name, d, h, cf, color, parent, o)
		o = o or {}
		o.shape = Enum.PartType.Cylinder
		local p = mk(name, Vector3.new(h, d, d), cf * CFrame.Angles(0, 0, math.rad(90)), color, parent, o)
		for _, f in FACES do
			p[f] = Enum.SurfaceType.Smooth
		end
		return p
	end

	local function light(part, range, color, brightness)
		local pl = Instance.new("PointLight")
		pl.Range = range
		pl.Brightness = brightness or 1.2
		pl.Color = color
		pl.Shadows = false
		pl.Parent = part
	end

	-- Small lantern standing on the point cf
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

	-- Text on one face of a part
	local SIGN_FONT = Font.fromEnum(Enum.Font.LuckiestGuy)
	local function signText(part, face, text, color, strokeColor)
		local g = Instance.new("SurfaceGui")
		g.Name = "SignGui"
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 40
		g.LightInfluence = 0.4
		g.Parent = part
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.FontFace = SIGN_FONT
		l.Text = text
		l.TextScaled = true
		l.TextColor3 = color or Color3.fromRGB(255, 236, 190)
		l.Parent = g
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.07, 0)
		pad.PaddingRight = UDim.new(0.07, 0)
		pad.PaddingTop = UDim.new(0.16, 0)
		pad.PaddingBottom = UDim.new(0.12, 0)
		pad.Parent = l
		local s = Instance.new("UIStroke")
		s.Color = strokeColor or Color3.fromRGB(60, 38, 22)
		s.Thickness = 2.5
		s.Parent = l
		return l
	end

	-- Framed wooden board facing -Z of cf. Returns the face part.
	local function board(name, w, h, cf, parent, text, twoSided)
		mk(name .. "Frame", Vector3.new(w + 0.6, h + 0.6, 0.3), cf, WOOD_D, parent, { deco = true })
		local face = mk(name, Vector3.new(w, h, twoSided and 0.5 or 0.4), cf * CFrame.new(0, 0, twoSided and 0 or -0.1), WOOD1, parent, { deco = true })
		if text then
			signText(face, Enum.NormalId.Front, text)
			if twoSided then
				signText(face, Enum.NormalId.Back, text)
			end
		end
		return face
	end

	local function ring(name, a, b, top, bottom, color, parent)
		local h, y, m, t = top - bottom, (top + bottom) / 2, (a + b) / 2, b - a
		mk(name .. "_N", Vector3.new(2 * b, h, t), CFrame.new(0, y, m), color, parent)
		mk(name .. "_S", Vector3.new(2 * b, h, t), CFrame.new(0, y, -m), color, parent)
		mk(name .. "_E", Vector3.new(t, h, 2 * a), CFrame.new(m, y, 0), color, parent)
		mk(name .. "_W", Vector3.new(t, h, 2 * a), CFrame.new(-m, y, 0), color, parent)
	end

	local function sideCF(s)
		return CFrame.Angles(0, s * math.pi / 2, 0)
	end

	-- Stone path from zFrom down to zTo (local side frame), centred on x
	local function path(cf, x, width, zFrom, zTo, parent)
		local len = zFrom - zTo
		local n = math.max(1, math.floor(len / 6 + 0.5))
		local step = len / n
		for i = 0, n - 1 do
			local z = zFrom - step * (i + 0.5)
			mk("PathStone", Vector3.new(width, 0.3, step - 0.4), cf * CFrame.new(x, 0, z), (i % 2 == 0) and PAVE1 or PAVE2, parent)
		end
	end

	-- Runs one part of the build and reports which part fails.
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

	---------------------------------------------------------------------------
	section("Ground", function()
		ring("GroundBase", SHORE, HALF, -4, -50, GRASS1, fGround)
		ring("Shore", POND, SHORE, 0, -50, SAND, fGround)
		local TILE = 25
		for ix = -12, 11 do
			for iz = -12, 11 do
				local cx, cz = (ix + 0.5) * TILE, (iz + 0.5) * TILE
				if not (math.abs(cx) < SHORE and math.abs(cz) < SHORE) then
					mk("Grass", Vector3.new(TILE, 4, TILE), CFrame.new(cx, -2, cz), ((ix + iz) % 2 == 0) and GRASS1 or GRASS2, fGround)
				end
			end
		end
		-- Pond terraces
		ring("Ledge1", 100, HALF, -50, -150, Color3.fromRGB(80, 118, 140), fGround)
		ring("Ledge2", 80, HALF, -150, -250, Color3.fromRGB(50, 85, 118), fGround)
		ring("Ledge3", 60, HALF, -250, -300, Color3.fromRGB(28, 55, 95), fGround)
		mk("PondFloor", Vector3.new(2 * HALF, 4, 2 * HALF), CFrame.new(0, -302, 0), Color3.fromRGB(15, 32, 70), fGround)
	end)

	section("Pond water", function()
		local tiers = {
			{ top = -1, bottom = -50, half = 120 },
			{ top = -50, bottom = -150, half = 100 },
			{ top = -150, bottom = -250, half = 80 },
			{ top = -250, bottom = -300, half = 60 },
		}
		for _, t in tiers do
			terrain:FillBlock(CFrame.new(0, (t.top + t.bottom) / 2, 0), Vector3.new(2 * t.half, t.top - t.bottom, 2 * t.half), Enum.Material.Water)
		end
		-- Low-poly surface. These are what players click to cast.
		local CELL = 20
		local rng = Random.new(7)
		for ix = -5, 6 do
			for iz = -5, 6 do
				local cx, cz = (ix - 0.5) * CELL, (iz - 0.5) * CELL
				local yaw = math.rad(90 * rng:NextInteger(0, 1))
				for k = 0, 1 do
					local shade = rng:NextInteger(0, 24)
					local w = mk("WaterTri", Vector3.new(0.4, CELL, CELL),
						CFrame.new(cx, -0.6, cz) * CFrame.Angles(0, yaw + math.rad(180 * k), 0) * CFrame.Angles(0, 0, math.rad(90)),
						Color3.fromRGB(40 + shade, 140 + shade, 218 + shade // 3), fWater,
						{ class = "WedgePart", smooth = true, transparency = 0.4, noShadow = true })
					w.CanCollide = false
					CollectionService:AddTag(w, "FishingWater")
				end
			end
		end
		-- Marker buoys at the pond corners
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local at = CFrame.new(sx * 110, 0, sz * 110)
				mk("Buoy", Vector3.new(3.2, 3.2, 3.2), at * CFrame.new(0, -0.6, 0), Color3.fromRGB(225, 60, 60), fWater, { shape = Enum.PartType.Ball, smooth = true, deco = true })
				cyl("BuoyMast", 0.5, 3, at * CFrame.new(0, 2.2, 0), Color3.fromRGB(245, 245, 245), fWater, { deco = true })
				local tip = mk("BuoyLight", Vector3.new(0.9, 0.9, 0.9), at * CFrame.new(0, 4, 0), Color3.fromRGB(255, 90, 90), fWater, { shape = Enum.PartType.Ball, material = Enum.Material.Neon, deco = true })
				light(tip, 14, Color3.fromRGB(255, 90, 90), 1)
			end
		end
	end)

	section("Underwater", function()
		local urng = Random.new(5)
		local function ledgePoint(a, b)
			local t = urng:NextNumber(a + 3, b - 3)
			local s = urng:NextNumber(-b + 3, b - 3)
			if urng:NextInteger(0, 1) == 0 then
				return s, (urng:NextInteger(0, 1) == 0) and t or -t
			end
			return (urng:NextInteger(0, 1) == 0) and t or -t, s
		end
		for _, l in { { -50, 100, 120 }, { -150, 80, 100 }, { -250, 60, 80 } } do
			for _ = 1, 8 do
				local x, z = ledgePoint(l[2], l[3])
				local h = urng:NextNumber(5, 12)
				mk("Seaweed", Vector3.new(1.2, h, 1.2), CFrame.new(x, l[1] + h / 2, z), Color3.fromRGB(40, 140 + urng:NextInteger(-20, 20), 80), fUnder, { deco = true })
			end
			for _ = 1, 3 do
				local x, z = ledgePoint(l[2], l[3])
				local s = urng:NextNumber(3, 6)
				mk("Rock", Vector3.new(s, s * 0.7, s), CFrame.new(x, l[1] + s * 0.35, z) * CFrame.Angles(0, urng:NextNumber(0, 3), 0), Color3.fromRGB(90, 100, 110), fUnder)
			end
			for _ = 1, 2 do
				local x, z = ledgePoint(l[2], l[3])
				local c = Color3.fromHSV(urng:NextNumber(0.92, 1.04) % 1, 0.55, 1)
				for k = 1, 3 do
					mk("Coral", Vector3.new(1.4, 2 + k, 1.4), CFrame.new(x + (k - 2) * 1.6, l[1] + (2 + k) / 2, z), c, fUnder, { deco = true })
				end
			end
		end
		for k = 1, 10 do
			local h = urng:NextNumber(6, 14)
			local a, r = k * 0.63, urng:NextNumber(26, 50) -- stay clear of the crystals in the middle
			mk("Seaweed", Vector3.new(1.2, h, 1.2), CFrame.new(math.cos(a) * r, -300 + h / 2, math.sin(a) * r), Color3.fromRGB(40, 150, 90), fUnder, { deco = true })
		end
		local crystal = mk("AbyssCrystal", Vector3.new(6, 12, 6), CFrame.new(0, -294, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(80, 200, 255), fUnder, { material = Enum.Material.Neon })
		light(crystal, 70, Color3.fromRGB(100, 210, 255), 3)
		for _, o in { { 18, 14 }, { -20, 10 }, { 12, -22 }, { -14, -18 } } do
			local c = mk("Crystal", Vector3.new(3, 6, 3), CFrame.new(o[1], -297, o[2]) * CFrame.Angles(0, 0.7, 0.2), Color3.fromRGB(120, 220, 255), fUnder, { material = Enum.Material.Neon })
			light(c, 25, Color3.fromRGB(100, 210, 255), 2)
		end
		-- Sunken ship on the second ledge
		local cf = CFrame.new(-88, -150, 30) * CFrame.Angles(0, math.rad(20), math.rad(12))
		mk("WreckHull", Vector3.new(10, 6, 30), cf * CFrame.new(0, 3, 0), WOOD_D, fUnder)
		mk("WreckDeck", Vector3.new(9, 1, 26), cf * CFrame.new(0, 6.5, 0), WOOD2, fUnder)
		mk("WreckMast", Vector3.new(1.2, 18, 1.2), cf * CFrame.new(0, 15, 3) * CFrame.Angles(0.4, 0, 0), WOOD_D, fUnder)
		local chest = mk("TreasureChest", Vector3.new(4, 3, 3), cf * CFrame.new(0, 8.5, -8), Color3.fromRGB(200, 150, 50), fUnder)
		light(chest, 16, Color3.fromRGB(255, 210, 90), 2)
	end)

	section("Castle walls", function()
		for s = 0, 3 do
			local cf = sideCF(s)
			local len = (s % 2 == 0) and (2 * HALF + WALL_T) or (2 * HALF - WALL_T)
			mk("Wall", Vector3.new(len, WALL_H, WALL_T), cf * CFrame.new(0, WALL_H / 2, HALF), STONE, fWalls)
			mk("WallPlinth", Vector3.new(len, 4, WALL_T + 2), cf * CFrame.new(0, 2, HALF), STONE_D, fWalls)
			mk("WallWalk", Vector3.new(len, 1, WALL_T + 2), cf * CFrame.new(0, WALL_H + 0.5, HALF), STONE_D, fWalls)
			for v = -276, 276, 12 do
				mk("Merlon", Vector3.new(6, 5, WALL_T), cf * CFrame.new(v, WALL_H + 3.5, HALF), STONE, fWalls)
			end
			-- Heraldic banners on the inner face
			for _, v in { -190, 190 } do
				local inner = HALF - WALL_T / 2
				mk("BannerPole", Vector3.new(7, 0.5, 0.5), cf * CFrame.new(v, 31.25, inner - 0.6), WOOD_D, fWalls, { deco = true })
				mk("Banner", Vector3.new(6, 15, 0.3), cf * CFrame.new(v, 23.5, inner - 0.4), ({ Color3.fromRGB(196, 52, 52), Color3.fromRGB(52, 98, 196), Color3.fromRGB(214, 168, 40), Color3.fromRGB(52, 150, 76) })[s + 1], fWalls, { deco = true })
				mk("BannerTrim", Vector3.new(6, 0.8, 0.4), cf * CFrame.new(v, 16.4, inner - 0.45), GOLD, fWalls, { deco = true })
				mk("BannerEmblem", Vector3.new(2.2, 2.2, 0.4), cf * CFrame.new(v, 24.5, inner - 0.45) * CFrame.Angles(0, 0, math.rad(45)), GOLD, fWalls, { deco = true })
			end
		end
		local flagColors = { Color3.fromRGB(196, 52, 52), Color3.fromRGB(52, 98, 196), Color3.fromRGB(214, 168, 40), Color3.fromRGB(52, 150, 76) }
		local i = 0
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				i += 1
				local base = CFrame.new(sx * HALF, 0, sz * HALF)
				local TH = WALL_H + 16
				mk("Tower", Vector3.new(30, TH, 30), base * CFrame.new(0, TH / 2, 0), STONE, fWalls)
				mk("TowerPlinth", Vector3.new(34, 5, 34), base * CFrame.new(0, 2.5, 0), STONE_D, fWalls)
				mk("TowerBand", Vector3.new(32, 2, 32), base * CFrame.new(0, 40, 0), STONE_D, fWalls)
				mk("TowerCrown", Vector3.new(34, 2, 34), base * CFrame.new(0, TH + 1, 0), STONE_D, fWalls)
				for _, o in { { -15, -15 }, { 0, -15 }, { 15, -15 }, { -15, 0 }, { 15, 0 }, { -15, 15 }, { 0, 15 }, { 15, 15 } } do
					mk("TowerMerlon", Vector3.new(4, 4, 4), base * CFrame.new(o[1], TH + 4, o[2]), STONE, fWalls)
				end
				-- Arrow slits on the two faces that look into the castle
				for _, y in { 22, 33 } do
					mk("ArrowSlit", Vector3.new(0.4, 5, 1.2), base * CFrame.new(-sx * 15.05, y, -sz * 10), Color3.fromRGB(40, 40, 46), fWalls, { deco = true })
					mk("ArrowSlit", Vector3.new(1.2, 5, 0.4), base * CFrame.new(-sx * 10, y, -sz * 15.05), Color3.fromRGB(40, 40, 46), fWalls, { deco = true })
				end
				-- Brazier
				mk("Brazier", Vector3.new(5, 1.6, 5), base * CFrame.new(0, TH + 2.8, 0), STONE_D, fWalls)
				local fire = mk("BrazierFire", Vector3.new(3, 2, 3), base * CFrame.new(0, TH + 4.6, 0), Color3.fromRGB(255, 130, 40), fWalls, { material = Enum.Material.Neon, deco = true })
				mk("BrazierFlame", Vector3.new(1.6, 2.6, 1.6), base * CFrame.new(0, TH + 4.9, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 210, 90), fWalls, { material = Enum.Material.Neon, deco = true })
				light(fire, 60, Color3.fromRGB(255, 170, 90), 1.5)
				mk("FlagPole", Vector3.new(1, 16, 1), base * CFrame.new(-sx * 9, TH + 10, -sz * 9), WOOD_D, fWalls)
				mk("Flag", Vector3.new(8, 5, 0.4), base * CFrame.new(-sx * 9 + 4.5, TH + 15, -sz * 9), flagColors[i], fWalls, { deco = true })
			end
		end
	end)

	---------------------------------------------------------------------------
	-- Docks: walkway from the shore out to a square fishing platform.
	-- Parts named "Dock" and "DockEnd" are invisible zones the game uses.
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
			-- Hidden pylons under the walkway
			cyl("Pylon", 1.1, 14, cf * CFrame.new(x + side * (walkW / 2 - 1), -6.6, 116), WOOD_D, parent)
		end
		-- Platform corner posts stick up and carry the rail
		local zf, zb = DOCK_TO - PLAT_D + 0.6, DOCK_TO - 0.6
		local xl, xr = x - platW / 2 + 0.6, x + platW / 2 - 0.6
		for _, p in { { xl, zf }, { xr, zf }, { xl, zb }, { xr, zb } } do
			cyl("Post", 1.2, 16.4, cf * CFrame.new(p[1], -5.6, p[2]), WOOD_D, parent, { noQuery = true })
		end
		local railY = 2.3
		local function rail(ax, az, bx, bz)
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			mk("Rail", Vector3.new(0.4, 0.4, len - 1.2), cf * CFrame.lookAt(Vector3.new((ax + bx) / 2, railY, (az + bz) / 2), Vector3.new(bx, railY, bz)), WOOD_D, parent, { noQuery = true })
		end
		rail(xl, zf, xr, zf)
		rail(xl, zf, xl, zb)
		rail(xr, zf, xr, zb)
		lantern(cf * CFrame.new(xl, 2.6, zf), parent)

		local zone = mk("Dock", Vector3.new(walkW, 1, walkLen), cf * CFrame.new(x, DECK_Y, (DOCK_FROM + DOCK_TO) / 2), WOOD1, parent, { deco = true, transparency = 1 })
		zone.CastShadow = false
		local zoneEnd = mk("DockEnd", Vector3.new(platW, 1, PLAT_D), cf * CFrame.new(x, DECK_Y, DOCK_TO - PLAT_D / 2), WOOD1, parent, { deco = true, transparency = 1 })
		zoneEnd.CastShadow = false
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

			local floor = mk("Floor", Vector3.new(BASE, 0.6, BASE), cf * CFrame.new(0, 0.3, 0), STONE_L, plot)
			plot.PrimaryPart = floor

			-- Hedge garden walls with stone pillars
			local function hedge(len, at, alongX)
				local size = if alongX then Vector3.new(len, 2.4, 2) else Vector3.new(2, 2.4, len)
				local top = if alongX then Vector3.new(len, 0.6, 2.4) else Vector3.new(2.4, 0.6, len)
				mk("Hedge", size, cf * at * CFrame.new(0, 1.8, 0), HEDGE_D, plot)
				mk("HedgeTop", top, cf * at * CFrame.new(0, 3.3, 0), HEDGE, plot)
			end
			hedge(44, CFrame.new(0, 0, H - 1.5), true)
			hedge(44, CFrame.new(-H + 1.5, 0, 0), false)
			hedge(44, CFrame.new(H - 1.5, 0, 0), false)
			hedge(14.5, CFrame.new(-14.75, 0, -H + 1.5), true)
			hedge(14.5, CFrame.new(14.75, 0, -H + 1.5), true)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					mk("Pillar", Vector3.new(3, 4.4, 3), cf * CFrame.new(sx * (H - 1.5), 2.8, sz * (H - 1.5)), STONE, plot)
					mk("PillarCap", Vector3.new(3.6, 0.6, 3.6), cf * CFrame.new(sx * (H - 1.5), 5.3, sz * (H - 1.5)), STONE_D, plot)
				end
				lantern(cf * CFrame.new(sx * (H - 1.5), 5.6, -H + 1.5), plot)
			end

			-- Gate with a hanging name sign (PlotService writes the owner on it)
			for _, sx in { -1, 1 } do
				mk("GatePillar", Vector3.new(3, 8, 3), cf * CFrame.new(sx * 6, 4.6, -H + 1.5), STONE, plot)
				mk("GateCap", Vector3.new(3.6, 0.6, 3.6), cf * CFrame.new(sx * 6, 8.9, -H + 1.5), STONE_D, plot)
				mk("SignChain", Vector3.new(0.2, 1.2, 0.2), cf * CFrame.new(sx * 3.2, 8.6, -H + 1.5), Color3.fromRGB(70, 70, 76), plot, { deco = true, smooth = true })
			end
			mk("GateBeam", Vector3.new(15.6, 0.8, 0.8), cf * CFrame.new(0, 9.6, -H + 1.5), WOOD_D, plot)
			local signCF = cf * CFrame.new(0, 6.6, -H + 1.5)
			mk("SignFrame", Vector3.new(8.8, 3.4, 0.3), signCF, WOOD_D, plot, { deco = true })
			local sign = mk("Sign", Vector3.new(8.2, 2.8, 0.5), signCF, WOOD1, plot, { deco = true })
			signText(sign, Enum.NormalId.Front, "BASE " .. idx)
			signText(sign, Enum.NormalId.Back, "BASE " .. idx)

			-- Aquarium: the fish you're carrying swim in here
			local T = CFrame.new(0, 0, 8)
			mk("TankStand", Vector3.new(16, 2, 10), cf * T * CFrame.new(0, 1.6, 0), WOOD2, plot)
			mk("TankStandTrim", Vector3.new(16.4, 0.4, 10.4), cf * T * CFrame.new(0, 2.4, 0), WOOD_D, plot)
			mk("TankGlass", Vector3.new(15, 7, 9), cf * T * CFrame.new(0, 6.1, 0), Color3.fromRGB(200, 232, 250), plot, { material = Enum.Material.Glass, transparency = 0.75 })
			mk("TankSand", Vector3.new(14.4, 0.6, 8.4), cf * T * CFrame.new(0, 2.9, 0), SAND, plot, { deco = true })
			local water = mk("TankWater", Vector3.new(14.4, 5.4, 8.4), cf * T * CFrame.new(0, 5.9, 0), Color3.fromRGB(70, 170, 235), plot, { smooth = true, deco = true, transparency = 0.55, noShadow = true })
			water.Name = "TankWater"
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					mk("TankEdge", Vector3.new(0.5, 7, 0.5), cf * T * CFrame.new(sx * 7.5, 6.1, sz * 4.5), WOOD_D, plot)
				end
				mk("TankRim", Vector3.new(15.5, 0.5, 0.5), cf * T * CFrame.new(0, 9.6, sx * 4.5), WOOD_D, plot)
				mk("TankRim", Vector3.new(0.5, 0.5, 9.5), cf * T * CFrame.new(sx * 7.5, 9.6, 0), WOOD_D, plot)
			end
			mk("TankLid", Vector3.new(15.6, 0.4, 9.6), cf * T * CFrame.new(0, 10.05, 0), WOOD2, plot)
			local strip = mk("TankLight", Vector3.new(10, 0.2, 1), cf * T * CFrame.new(0, 9.4, 0), Color3.fromRGB(210, 240, 255), plot, { material = Enum.Material.Neon, deco = true })
			light(strip, 12, Color3.fromRGB(150, 220, 255), 0.8)
			mk("TankRock", Vector3.new(2.6, 1.6, 2), cf * T * CFrame.new(-4, 4, 1.5) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(120, 124, 130), plot, { deco = true })
			mk("TankPlant", Vector3.new(0.5, 3.4, 0.5), cf * T * CFrame.new(4.5, 4.9, -1.5), Color3.fromRGB(60, 170, 90), plot, { deco = true })
			mk("TankPlant", Vector3.new(0.5, 2.4, 0.5), cf * T * CFrame.new(5.4, 4.4, 0.6), Color3.fromRGB(80, 190, 100), plot, { deco = true })

			-- Spawn pad
			mk("Spawn", Vector3.new(7, 0.2, 7), cf * CFrame.new(0, 0.7, -12), Color3.fromRGB(240, 205, 100), plot, { deco = true })

			-- Bench facing the pond
			local B = cf * CFrame.new(15, 0, -15)
			mk("BenchSeat", Vector3.new(6, 0.5, 2), B * CFrame.new(0, 2.3, 0), WOOD1, plot)
			mk("BenchBack", Vector3.new(6, 2, 0.4), B * CFrame.new(0, 3.6, 1.2), WOOD1, plot)
			for _, bx in { -2.5, 2.5 } do
				mk("BenchLeg", Vector3.new(0.5, 1.45, 1.6), B * CFrame.new(bx, 1.325, 0), WOOD_D, plot)
			end

			-- Rod rack
			local R = cf * CFrame.new(-15, 0, -15)
			for _, rx in { -3, 3 } do
				mk("RackPost", Vector3.new(0.6, 4, 0.6), R * CFrame.new(rx, 2.6, 0), WOOD_D, plot)
			end
			mk("RackBar", Vector3.new(7, 0.5, 0.5), R * CFrame.new(0, 4.3, 0), WOOD_D, plot)
			for k, c in { WOOD1, GOLD, Color3.fromRGB(140, 80, 220) } do
				local rcf = R * CFrame.new(-3 + k * 1.5, 3.55, -0.9) * CFrame.Angles(math.rad(14), 0, 0)
				cyl("RackRod", 0.3, 6, rcf, c, plot, { deco = true })
				cyl("RackGrip", 0.45, 1, rcf * CFrame.new(0, -2.3, 0), WOOD_D, plot, { deco = true })
			end

			-- Path from the gate to this base's dock, then the dock itself
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
		-- Plaza
		mk("Plaza", Vector3.new(36, 0.3, 56), CFrame.new(0, 0, 208), PAVE1, fTown)
		for _, sx in { -1, 1 } do
			mk("PlazaTrim", Vector3.new(1, 0.4, 56), CFrame.new(sx * 18.5, 0, 208), STONE_D, fTown)
		end
		for _, z in { 179.5, 236.5 } do
			mk("PlazaTrim", Vector3.new(38, 0.4, 1), CFrame.new(0, 0, z), STONE_D, fTown)
		end
		mk("PlazaInlay", Vector3.new(16, 0.4, 16), CFrame.new(0, 0, 214) * CFrame.Angles(0, math.rad(45), 0), PAVE2, fTown)

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Size = Vector3.new(10, 0.4, 10)
		spawn.CFrame = CFrame.new(0, 0.2, 214)
		spawn.Anchored = true
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Color = GOLD
		for _, f in FACES do
			spawn[f] = Enum.SurfaceType.Studs
		end
		spawn.Parent = fTown

		-- Paths: plaza -> public pier, plaza -> shop
		path(CFrame.new(), 0, 8, 179, DOCK_FROM, fTown)
		path(CFrame.new(), 0, 6, 257, 237, fTown)

		-- Entrance arch
		for _, sx in { -1, 1 } do
			mk("ArchBase", Vector3.new(4, 1, 4), CFrame.new(sx * 10, 0.5, 182), STONE_D, fTown)
			mk("ArchPillar", Vector3.new(3, 13, 3), CFrame.new(sx * 10, 7.5, 182), STONE, fTown)
			mk("ArchCap", Vector3.new(4, 1, 4), CFrame.new(sx * 10, 14.5, 182), STONE_D, fTown)
			lampPost(CFrame.new(sx * 14.5, 0, 182), fTown, 7)
		end
		local beam = mk("ArchBeam", Vector3.new(24, 3, 3), CFrame.new(0, 16.5, 182), STONE_D, fTown)
		signText(beam, Enum.NormalId.Front, "CASTLE FISHING", GOLD)
		signText(beam, Enum.NormalId.Back, "CASTLE FISHING", GOLD)

		-- Benches facing the plaza centre
		for _, sx in { -1, 1 } do
			local B = CFrame.new(sx * 14, 0, 200) * CFrame.Angles(0, sx * math.rad(90), 0)
			mk("BenchSeat", Vector3.new(6, 0.5, 2), B * CFrame.new(0, 1.9, 0), WOOD1, fTown)
			mk("BenchBack", Vector3.new(6, 2, 0.4), B * CFrame.new(0, 3.2, 1.2), WOOD1, fTown)
			for _, bx in { -2.5, 2.5 } do
				mk("BenchLeg", Vector3.new(0.5, 1.5, 1.6), B * CFrame.new(bx, 0.9, 0), WOOD_D, fTown)
			end
		end
		-- Planters at the back corners
		for _, sx in { -1, 1 } do
			local P = CFrame.new(sx * 13, 0, 231)
			mk("Planter", Vector3.new(5, 1.6, 5), P * CFrame.new(0, 0.8, 0), STONE_D, fTown)
			mk("Soil", Vector3.new(4.2, 0.2, 4.2), P * CFrame.new(0, 1.6, 0), Color3.fromRGB(90, 64, 44), fTown)
			mk("Shrub", Vector3.new(3.4, 2.4, 3.4), P * CFrame.new(0, 2.9, 0), HEDGE, fTown)
			for k, c in { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255) } do
				local a = k * 2.1
				mk("Bloom", Vector3.new(1, 1, 1), P * CFrame.new(math.cos(a) * 1.5, 4.2, math.sin(a) * 1.5), c, fTown, { deco = true })
			end
		end

		-- ROD SHOP (front faces the pond at z = 257)
		local S = CFrame.new(0, 0, 266)
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
		mk("Timber", Vector3.new(25.5, 0.8, 0.3), S * CFrame.new(0, 1.4, -9.15), WOOD_D, fTown)
		-- Roof
		mk("Roof", Vector3.new(28, 6, 10.5), S * CFrame.new(0, 16, -5.25), ROOF, fTown, { class = "WedgePart" })
		mk("Roof", Vector3.new(28, 6, 10.5), S * CFrame.new(0, 16, 5.25) * CFrame.Angles(0, math.pi, 0), ROOF, fTown, { class = "WedgePart" })
		mk("RoofRidge", Vector3.new(28.4, 0.8, 1.4), S * CFrame.new(0, 19.2, 0), ROOF_D, fTown)
		mk("Chimney", Vector3.new(2.4, 7, 2.4), S * CFrame.new(8, 18.5, 4), STONE_D, fTown)
		mk("ChimneyCap", Vector3.new(3, 0.6, 3), S * CFrame.new(8, 22.3, 4), STONE, fTown)
		-- Door (tagged so the game adds a "Browse Rods" prompt)
		local door = mk("ShopDoor", Vector3.new(5, 8, 0.4), S * CFrame.new(0, 5, -9.2), WOOD2, fTown)
		CollectionService:AddTag(door, "RodShop")
		for _, sx in { -1, 1 } do
			mk("DoorFrame", Vector3.new(0.6, 8.6, 0.5), S * CFrame.new(sx * 2.8, 5.3, -9.25), WOOD_D, fTown)
		end
		mk("DoorFrame", Vector3.new(6.2, 0.6, 0.5), S * CFrame.new(0, 9.3, -9.25), WOOD_D, fTown)
		mk("DoorKnob", Vector3.new(0.4, 0.4, 0.3), S * CFrame.new(1.7, 5, -9.5), GOLD, fTown, { smooth = true })
		-- Windows with flower boxes
		for _, sx in { -1, 1 } do
			local W = S * CFrame.new(sx * 9.5, 0, 0)
			mk("Window", Vector3.new(4, 3.6, 0.2), W * CFrame.new(0, 9.6, -9.15), Color3.fromRGB(190, 225, 245), fTown, { material = Enum.Material.Glass, transparency = 0.3 })
			mk("WindowFrame", Vector3.new(4.6, 0.5, 0.4), W * CFrame.new(0, 11.65, -9.25), WOOD_D, fTown)
			for _, wx in { -2.25, 2.25 } do
				mk("WindowFrame", Vector3.new(0.5, 3.6, 0.4), W * CFrame.new(wx, 9.6, -9.25), WOOD_D, fTown)
			end
			mk("WindowBar", Vector3.new(0.25, 3.6, 0.3), W * CFrame.new(0, 9.6, -9.25), WOOD_D, fTown)
			mk("WindowBar", Vector3.new(4, 0.25, 0.28), W * CFrame.new(0, 9.6, -9.25), WOOD_D, fTown)
			mk("FlowerBox", Vector3.new(4.6, 0.8, 1), W * CFrame.new(0, 7.8, -9.8), WOOD1, fTown)
			for k, c in { Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 220, 90), Color3.fromRGB(170, 120, 255) } do
				mk("Bloom", Vector3.new(0.9, 0.9, 0.9), W * CFrame.new(-2.6 + k * 1.3, 8.6, -9.8), c, fTown, { deco = true })
			end
		end
		board("ShopSign", 8.4, 1.8, S * CFrame.new(0, 11.0, -9.15), fTown, "ROD SHOP")
		-- Rod rack beside the door
		local RR = CFrame.new(-9, 0, 254.5)
		for _, rx in { -2.6, 2.6 } do
			mk("RackPost", Vector3.new(0.6, 4.4, 0.6), RR * CFrame.new(rx, 2.2, 0), WOOD_D, fTown)
		end
		mk("RackBar", Vector3.new(6, 0.5, 0.5), RR * CFrame.new(0, 4.1, 0), WOOD_D, fTown)
		for k, c in { WOOD1, Color3.fromRGB(90, 90, 96), GOLD } do
			local rcf = RR * CFrame.new(-3 + k * 1.5, 3.1, -1) * CFrame.Angles(math.rad(16), 0, 0)
			cyl("DisplayRod", 0.3, 6, rcf, c, fTown, { deco = true })
		end
		for _, sx in { -1, 1 } do
			lampPost(CFrame.new(sx * 5, 0, 247), fTown, 6)
		end

		-- FISH MARKET stall (front faces the plaza, +X)
		local M = CFrame.new(-38, 0, 212) * CFrame.Angles(0, math.rad(-90), 0)
		mk("StallFloor", Vector3.new(14, 0.4, 10), M * CFrame.new(0, 0.2, 0), WOOD2, fTown)
		for _, sx in { -1, 1 } do
			mk("StallPost", Vector3.new(0.8, 8.2, 0.8), M * CFrame.new(sx * 6.6, 4.5, -4.6), WOOD_D, fTown)
			mk("StallPost", Vector3.new(0.8, 10.1, 0.8), M * CFrame.new(sx * 6.6, 5.45, 4.6), WOOD_D, fTown)
		end
		local counter = mk("MarketCounter", Vector3.new(12, 3.4, 1.6), M * CFrame.new(0, 2.1, -3.6), WOOD1, fTown)
		CollectionService:AddTag(counter, "Merchant")
		mk("CounterTop", Vector3.new(12.2, 0.4, 2.2), M * CFrame.new(0, 4.0, -3.6), WOOD_D, fTown)
		mk("IceTray", Vector3.new(11, 0.3, 1.6), M * CFrame.new(0, 4.35, -3.6), Color3.fromRGB(225, 242, 255), fTown, { material = Enum.Material.Ice })
		for k, c in { Color3.fromRGB(200, 200, 205), Color3.fromRGB(90, 200, 110), Color3.fromRGB(70, 150, 255), Color3.fromRGB(255, 150, 90), Color3.fromRGB(180, 100, 255) } do
			local F = M * CFrame.new(-6 + k * 2, 4.75, -3.6) * CFrame.Angles(0, math.rad((k % 2 == 0) and 12 or -12), 0)
			mk("DisplayFish", Vector3.new(0.6, 0.5, 1.4), F, c, fTown, { deco = true, smooth = true })
			mk("DisplayFishTail", Vector3.new(0.2, 0.6, 0.4), F * CFrame.new(0, 0, 0.85), c, fTown, { deco = true, smooth = true })
		end
		-- Striped canopy, lower at the front
		for k = 0, 8 do
			mk("Canopy", Vector3.new(1.65, 0.3, 11), M * CFrame.new(-6.6 + k * 1.65, 9.8, 0) * CFrame.Angles(math.rad(-12), 0, 0),
				(k % 2 == 0) and Color3.fromRGB(60, 140, 220) or Color3.fromRGB(245, 245, 245), fTown)
		end
		for k = 0, 8 do
			mk("Valance", Vector3.new(1.65, 0.8, 0.2), M * CFrame.new(-6.6 + k * 1.65, 8.2, -5.5),
				(k % 2 == 0) and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(60, 140, 220), fTown, { deco = true })
		end
		board("MarketSign", 8, 2, M * CFrame.new(0, 11.6, -3.4), fTown, "FISH MARKET")
		for _, sx in { -1, 1 } do
			mk("SignPost", Vector3.new(0.4, 1.8, 0.4), M * CFrame.new(sx * 3.5, 9.9, -3.2), WOOD_D, fTown, { deco = true })
		end
		mk("Crate", Vector3.new(2.6, 2.6, 2.6), M * CFrame.new(4.5, 1.7, 2.6), WOOD1, fTown)
		mk("Crate", Vector3.new(2, 2, 2), M * CFrame.new(4.4, 4.0, 2.7) * CFrame.Angles(0, 0.35, 0), WOOD3, fTown)

		-- Notice board (front faces the plaza, -X)
		local N = CFrame.new(38, 0, 212) * CFrame.Angles(0, math.rad(90), 0)
		for _, sx in { -1, 1 } do
			mk("BoardPost", Vector3.new(0.8, 7.6, 0.8), N * CFrame.new(sx * 4.6, 3.8, 0), WOOD_D, fTown)
		end
		mk("BoardRoof", Vector3.new(10.4, 0.5, 2), N * CFrame.new(0, 7.85, 0), WOOD_D, fTown)
		mk("BoardBack", Vector3.new(8.8, 5.2, 0.3), N * CFrame.new(0, 4.6, 0), WOOD_D, fTown)
		local notice = mk("NoticeBoard", Vector3.new(8.2, 4.6, 0.4), N * CFrame.new(0, 4.6, -0.1), Color3.fromRGB(236, 222, 184), fTown, { deco = true })
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Front
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 50
		g.LightInfluence = 0.4
		g.Parent = notice
		local title = Instance.new("TextLabel")
		title.Size = UDim2.new(1, 0, 0.26, 0)
		title.BackgroundTransparency = 1
		title.FontFace = SIGN_FONT
		title.Text = "HOW TO FISH"
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(150, 60, 40)
		title.Parent = g
		local body = Instance.new("TextLabel")
		body.Size = UDim2.new(0.86, 0, 0.66, 0)
		body.Position = UDim2.new(0.07, 0, 0.28, 0)
		body.BackgroundTransparency = 1
		body.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
		body.Text = "1. Press 1 to hold your rod\n2. Click the water to cast\n3. Wait for the  !\n4. Hold click to reel it in\n5. Sell at the Fish Market"
		body.TextScaled = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextColor3 = Color3.fromRGB(70, 50, 30)
		body.Parent = g
	end)

	---------------------------------------------------------------------------
	section("Trees and flowers", function()
		local rng = Random.new(21)
		local placed = {}

		-- Rotate a world point into side s's local frame
		local function toSide(x, z, s)
			local p = CFrame.Angles(0, -s * math.pi / 2, 0) * Vector3.new(x, 0, z)
			return p.X, p.Z
		end
		local function free(x, z, r)
			if math.abs(x) > 270 - r or math.abs(z) > 270 - r then
				return false
			end
			if math.abs(x) < SHORE + 10 + r and math.abs(z) < SHORE + 10 + r then
				return false
			end
			for s = 0, 3 do
				local lx, lz = toSide(x, z, s)
				for _, bx in { -BASE_X, BASE_X } do
					if math.abs(lx - bx) < BASE / 2 + 4 + r and lz > BASE_Z - BASE / 2 - 4 - r and lz < BASE_Z + BASE / 2 + 4 + r then
						return false
					end
					if math.abs(lx - bx) < 5 + r and lz > 140 and lz < BASE_Z then
						return false
					end
				end
				if math.abs(lx) < 8 + r and lz > 140 and lz < 190 then
					return false
				end
				if s == 0 and math.abs(lx) < 56 + r and lz > 150 then
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
		local function scatter(count, r, build)
			local n, tries = 0, 0
			while n < count and tries < count * 60 do
				tries += 1
				local x, z = rng:NextNumber(-270, 270), rng:NextNumber(-270, 270)
				if free(x, z, r) then
					n += 1
					table.insert(placed, { x, z, r })
					build(CFrame.new(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				end
			end
		end

		scatter(16, 7, function(cf) -- round oak
			local s = rng:NextNumber(0.85, 1.2)
			local g = rng:NextInteger(-10, 10)
			mk("Trunk", Vector3.new(2.2, 7, 2.2) * s, cf * CFrame.new(0, 3.5 * s, 0), WOOD_D, fNature)
			mk("Leaves", Vector3.new(10, 5, 10) * s, cf * CFrame.new(0, 9 * s, 0), Color3.fromRGB(60 + g, 140 + g, 62), fNature)
			mk("Leaves", Vector3.new(6.5, 3, 6.5) * s, cf * CFrame.new(0.6 * s, 12.5 * s, -0.4 * s), Color3.fromRGB(72 + g, 156 + g, 70), fNature)
			mk("Leaves", Vector3.new(5, 4, 5) * s, cf * CFrame.new(4.2 * s, 8 * s, 2.6 * s), Color3.fromRGB(54 + g, 130 + g, 58), fNature)
		end)
		scatter(14, 6, function(cf) -- pine
			local s = rng:NextNumber(0.9, 1.3)
			mk("Trunk", Vector3.new(1.6, 4, 1.6) * s, cf * CFrame.new(0, 2 * s, 0), WOOD_D, fNature)
			for i, w in { 9, 7, 5, 3 } do
				mk("Needles", Vector3.new(w, 2.6, w) * s, cf * CFrame.new(0, (3 + i * 2.3) * s, 0) * CFrame.Angles(0, math.rad(i * 20), 0),
					(i % 2 == 0) and Color3.fromRGB(40, 110, 66) or Color3.fromRGB(48, 124, 74), fNature)
			end
		end)
		scatter(14, 3, function(cf) -- bush
			local s = rng:NextNumber(0.8, 1.2)
			mk("Bush", Vector3.new(4.6, 2.8, 4) * s, cf * CFrame.new(0, 1.4 * s, 0), HEDGE_D, fNature)
			mk("Bush", Vector3.new(3, 2, 2.8) * s, cf * CFrame.new(1.4 * s, 2.6 * s, 0.4 * s), HEDGE, fNature)
		end)
		local petals = { Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 220, 80), Color3.fromRGB(250, 250, 250), Color3.fromRGB(170, 120, 255) }
		scatter(12, 3, function(cf) -- flower patch
			local c = petals[rng:NextInteger(1, #petals)]
			for k = 1, 5 do
				local a = k * 1.26
				local F = cf * CFrame.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8)
				mk("Stem", Vector3.new(0.4, 1.4, 0.4), F * CFrame.new(0, 0.7, 0), Color3.fromRGB(50, 130, 60), fNature, { deco = true })
				mk("Bloom", Vector3.new(1.1, 0.8, 1.1), F * CFrame.new(0, 1.8, 0), c, fNature, { deco = true })
			end
		end)
		scatter(8, 4, function(cf) -- rocks
			local s = rng:NextNumber(2.6, 4.5)
			mk("Rock", Vector3.new(s * 1.3, s * 0.8, s), cf * CFrame.new(0, s * 0.4, 0), STONE_D, fNature)
			mk("Rock", Vector3.new(s * 0.7, s * 0.5, s * 0.6), cf * CFrame.new(s * 0.9, s * 0.25, s * 0.3), STONE, fNature)
		end)
	end)

	section("Lighting", function()
		Lighting.ClockTime = 14.5
		Lighting.Brightness = 2.5
		Lighting.Ambient = Color3.fromRGB(105, 115, 135)
		Lighting.OutdoorAmbient = Color3.fromRGB(125, 135, 150)
		Lighting.EnvironmentDiffuseScale = 0.5
		Lighting.EnvironmentSpecularScale = 0.5
		local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
		atm.Density = 0.22
		atm.Haze = 0.8
		atm.Color = Color3.fromRGB(190, 215, 240)
		atm.Decay = Color3.fromRGB(110, 150, 200)
		atm.Parent = Lighting
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
		bloom.Intensity = 0.3
		bloom.Size = 24
		bloom.Threshold = 1.2
		bloom.Parent = Lighting
		local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.12
		cc.Contrast = 0.06
		cc.Parent = Lighting
	end)

	if failed == 0 then
		print("[BuildMap] Done! 8 bases with private docks, 4 public piers, Rod Shop, Fish Market.")
	else
		warn("[BuildMap] Finished with " .. failed .. " problem(s). Send a screenshot of the orange lines above.")
	end
end
