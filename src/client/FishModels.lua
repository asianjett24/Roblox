-- Builds fish out of smooth parts and animates them swimming.
-- Fish space: the head points down -Z, +Y is up. Sizes come from FishData Look (multiples of L).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FishData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FishData"))

local FishModels = {}

local FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }
local WHITE = Color3.fromRGB(250, 250, 250)
local PUPIL = Color3.fromRGB(16, 18, 24)

local function newPart(parent, size: Vector3, color: Color3, kind: string?, material)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(math.max(size.X, 0.02), math.max(size.Y, 0.02), math.max(size.Z, 0.02))
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	for _, f in FACES do
		p[f] = Enum.SurfaceType.Smooth
	end
	if kind == "ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif kind == "ball" then
		p.Shape = Enum.PartType.Ball
	end
	p.Parent = parent
	return p
end

-- Deterministic "random" per species so every client draws the same markings.
local function seeded(name: string)
	local h = 0
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 2147483647
	end
	return Random.new(h)
end

-- Builds a rig. simple = fewer parts (used for the little fish in base aquariums).
function FishModels.Build(speciesId: string, scale: number, simple: boolean?)
	local species = FishData.ById[speciesId]
	local look = species.Look
	local L = look.L * scale
	local H, W = look.H * L, look.W * L
	local shape = look.Shape or "fish"
	local rng = seeded(speciesId)
	local glowMat = if look.Glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local bodyMat = if look.Shiny then Enum.Material.Metal else Enum.Material.SmoothPlastic
	local thin = math.max(0.03 * L, 0.04)

	local model = Instance.new("Model")
	model.Name = speciesId
	local rig = { Model = model, Items = {}, L = L, H = H, W = W, Shape = shape, Species = species }

	local function add(kind, part, offset: CFrame, seg)
		table.insert(rig.Items, { Part = part, Kind = kind, Offset = offset, Seg = seg })
		return part
	end

	local function eyes(kind, z, y, halfWidth, size, seg)
		for _, sx in { -1, 1 } do
			add(kind, newPart(model, Vector3.one * size, if look.Glow then look.Fin else WHITE, "ball", glowMat), CFrame.new(sx * halfWidth, y, z), seg)
			if not simple then
				add(kind, newPart(model, Vector3.one * size * 0.55, PUPIL, "ball"), CFrame.new(sx * (halfWidth + size * 0.28), y + size * 0.05, z - size * 0.12), seg)
			end
		end
	end

	if shape == "eel" then
		local n = if simple then 5 elseif L > 15 then 12 else 9
		local segLen = L / n
		rig.Segments = n
		rig.SegLen = segLen
		for i = 0, n - 1 do
			local t = 1 - 0.55 * (i / (n - 1))
			if i == 0 then
				t = 1.15
			end
			-- each segment is posed in its own frame (see Pose)
			add("seg", newPart(model, Vector3.new(W * t, H * t, segLen * 1.6), look.Body, "ellipsoid", bodyMat), CFrame.new(), i)
			if not simple then
				add("seg", newPart(model, Vector3.new(W * t * 0.9, H * t * 0.7, segLen * 1.5), look.Belly, "ellipsoid"), CFrame.new(0, -H * t * 0.16, 0), i)
				if look.Spines and i > 0 then
					add("seg", newPart(model, Vector3.new(thin, H * t * 0.7, segLen * 0.9), look.Fin, "ellipsoid", Enum.Material.Metal), CFrame.new(0, H * t * 0.42, 0) * CFrame.Angles(math.rad(18), 0, 0), i)
				end
				if look.Spots and i % 2 == 1 then
					add("seg", newPart(model, Vector3.new(W * t * 0.5, H * t * 0.2, segLen * 0.5), look.Spots[2], "ellipsoid", glowMat), CFrame.new(0, H * t * 0.4, 0), i)
				end
			end
		end
		eyes("seg", -segLen * 0.35, H * 0.2, W * 0.45, math.max(H, W) * 0.32, 0)
		if look.Horns and not simple then
			for _, sx in { -1, 1 } do
				add("seg", newPart(model, Vector3.new(W * 0.22, W * 0.22, L * 0.08), look.Fin, "ellipsoid", Enum.Material.Metal),
					CFrame.new(sx * W * 0.35, H * 0.55, segLen * 0.1) * CFrame.Angles(math.rad(35), sx * math.rad(20), 0), 0)
			end
		end
		add("seg", newPart(model, Vector3.new(thin, H * 1.6, segLen * 1.4), look.Fin, "ellipsoid", glowMat), CFrame.new(0, 0, segLen * 0.7), n - 1)
		rig.Radius = math.max(H, W) * 0.7
		rig.Back = L / 2
		return rig
	end

	-- Regular and round fish
	local round = shape == "round"
	local bodyLen = if round then L * 0.85 else L * 0.72
	local z0 = if round then 0 else -0.08 * L
	local pivot = z0 + bodyLen * 0.46
	rig.Pivot = pivot
	rig.Radius = math.max(H, W) * 0.5
	rig.Back = pivot + L * 0.1

	add("body", newPart(model, Vector3.new(W, H, bodyLen), look.Body, "ellipsoid", bodyMat), CFrame.new(0, 0, z0))
	if not simple then
		add("body", newPart(model, Vector3.new(W * 0.94, H * 0.72, bodyLen * 0.86), look.Belly, "ellipsoid"), CFrame.new(0, -H * 0.15, z0 + 0.02 * L))
	end

	-- Cross-section of the body at z (0..1)
	local function section(z)
		local u = (z - z0) / (bodyLen / 2)
		return math.sqrt(math.max(0, 1 - u * u))
	end

	if not simple then
		if look.Stripes then
			local count, color = look.Stripes[1], look.Stripes[2]
			for i = 1, count do
				local z = z0 - bodyLen * 0.3 + (i - 1) / math.max(count - 1, 1) * bodyLen * 0.62
				local f = section(z)
				add("body", newPart(model, Vector3.new(W * f * 1.04, H * f * 1.04, math.max(0.045 * L, 0.05)), color, "ellipsoid"), CFrame.new(0, 0, z))
			end
		end
		if look.Spots then
			local count, color = look.Spots[1], look.Spots[2]
			for _ = 1, count do
				local z = z0 + rng:NextNumber(-0.32, 0.3) * bodyLen
				local f = section(z)
				local a = rng:NextNumber(-1.1, 1.1)
				local size = math.min(W, H) * rng:NextNumber(0.35, 0.55)
				add("body", newPart(model, Vector3.new(size * f + 0.02, size * 0.25, size * 1.2 * f + 0.02), color, "ellipsoid", glowMat),
					CFrame.new((W / 2) * f * math.sin(a), (H / 2) * f * math.cos(a), z) * CFrame.Angles(0, 0, -a))
			end
		end
	end

	-- Tail
	local tail = look.Tail or "fork"
	local tailH = math.max(H, L * 0.2)
	if tail == "round" then
		add("tail", newPart(model, Vector3.new(thin, tailH * 0.9, L * 0.26), look.Fin, "ellipsoid", glowMat), CFrame.new(0, 0, L * 0.11))
	else
		local angle = if tail == "crescent" then 42 else 30
		local len = if tail == "crescent" then L * 0.34 else L * 0.28
		for _, sy in { -1, 1 } do
			add("tail", newPart(model, Vector3.new(thin, tailH * 0.32, len), look.Fin, "ellipsoid", glowMat),
				CFrame.Angles(math.rad(-angle * sy), 0, 0) * CFrame.new(0, 0, len * 0.45))
		end
	end

	-- Fins
	if look.TallFin then
		add("body", newPart(model, Vector3.new(thin, H * 1.05, bodyLen * 0.3), look.Fin, "ellipsoid"), CFrame.new(0, H * 0.62, z0 - 0.02 * L) * CFrame.Angles(math.rad(22), 0, 0))
	elseif not simple then
		add("body", newPart(model, Vector3.new(thin, H * 0.6, bodyLen * 0.42), look.Fin, "ellipsoid"), CFrame.new(0, H * 0.42, z0 + 0.02 * L) * CFrame.Angles(math.rad(8), 0, 0))
	end
	if not simple then
		add("body", newPart(model, Vector3.new(thin, H * 0.36, bodyLen * 0.2), look.Fin, "ellipsoid"), CFrame.new(0, -H * 0.42, z0 + bodyLen * 0.3))
		rig.FinL = CFrame.new(-W * 0.42, -H * 0.18, z0 - bodyLen * 0.18)
		rig.FinR = CFrame.new(W * 0.42, -H * 0.18, z0 - bodyLen * 0.18)
		local finSize = Vector3.new(math.max(L * 0.16, W * 0.5), thin * 0.7, L * 0.11)
		add("finL", newPart(model, finSize, look.Fin, "ellipsoid", glowMat), CFrame.Angles(0, 0, math.rad(25)) * CFrame.new(-finSize.X * 0.45, 0, finSize.Z * 0.3))
		add("finR", newPart(model, finSize, look.Fin, "ellipsoid", glowMat), CFrame.Angles(0, 0, math.rad(-25)) * CFrame.new(finSize.X * 0.45, 0, finSize.Z * 0.3))
	end

	-- Eyes
	local eyeZ = z0 - bodyLen * 0.34
	local eyeSize = math.min(0.075 * L, math.min(H, W) * 0.42)
	eyes("body", eyeZ, H * 0.12, (W / 2) * section(eyeZ) * 0.86, eyeSize)

	if not simple then
		local front = z0 - bodyLen / 2
		if look.Mouth then
			add("body", newPart(model, Vector3.new(W * 0.62, H * 0.24, 0.1 * L), Color3.fromRGB(44, 18, 22), "ellipsoid"), CFrame.new(0, -H * 0.12, front + 0.03 * L))
			add("body", newPart(model, Vector3.new(W * 0.64, H * 0.06, 0.08 * L), WHITE, "ellipsoid"), CFrame.new(0, -H * 0.06, front + 0.035 * L))
		end
		if look.Whiskers then
			for _, sx in { -1, 1 } do
				add("body", newPart(model, Vector3.new(thin * 0.6, thin * 0.6, L * 0.26), look.Fin:Lerp(Color3.new(0, 0, 0), 0.3), "ellipsoid"),
					CFrame.new(sx * W * 0.25, -H * 0.14, front + 0.06 * L) * CFrame.Angles(0, sx * math.rad(35), 0) * CFrame.new(0, 0, L * 0.12))
			end
		end
		if look.Bill then
			add("body", newPart(model, Vector3.new(thin * 1.2, thin * 1.2, L * 0.4), look.Body:Lerp(WHITE, 0.4), "ellipsoid"), CFrame.new(0, -H * 0.05, front - L * 0.17))
		end
		if look.Lure then
			local base = Vector3.new(0, H * 0.42, z0 - bodyLen * 0.22)
			local tip = base + Vector3.new(0, L * 0.2, -L * 0.24)
			add("body", newPart(model, Vector3.new(thin * 0.6, thin * 0.6, (tip - base).Magnitude), look.Fin, "ellipsoid"), CFrame.lookAt((base + tip) / 2, tip))
			local bulb = add("body", newPart(model, Vector3.one * 0.1 * L, Color3.fromRGB(190, 255, 240), "ball", Enum.Material.Neon), CFrame.new(tip))
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(140, 255, 230)
			light.Range = 12
			light.Brightness = 2
			light.Parent = bulb
		end
		if look.Spikes then
			for ring = -1, 1 do
				local z = z0 + ring * bodyLen * 0.22
				local f = section(z)
				for k = 0, 5 do
					local a = k * math.pi / 3 + ring * 0.5
					local p = Vector3.new((W / 2) * f * math.cos(a), (H / 2) * f * math.sin(a), z)
					local normal = Vector3.new(p.X / (W * W), p.Y / (H * H), (z - z0) / (bodyLen * bodyLen))
					if normal.Magnitude > 1e-4 then
						add("body", newPart(model, Vector3.new(thin * 0.7, thin * 0.7, L * 0.14), look.Fin:Lerp(WHITE, 0.3), "ellipsoid"),
							CFrame.lookAt(p, p - normal.Unit) * CFrame.new(0, 0, L * 0.03))
					end
				end
			end
		end
		if look.Crown then
			local zc = z0 - bodyLen * 0.2
			local top = (H / 2) * section(zc)
			local gold = Color3.fromRGB(255, 205, 70)
			add("body", newPart(model, Vector3.new(L * 0.2, L * 0.04, L * 0.16), gold, "ellipsoid", Enum.Material.Metal), CFrame.new(0, top * 0.96, zc))
			for k = 0, 4 do
				local a = k / 5 * math.pi * 2
				add("body", newPart(model, Vector3.new(L * 0.035, L * 0.08, L * 0.035), gold, nil, Enum.Material.Metal),
					CFrame.new(math.cos(a) * L * 0.08, top + L * 0.04, zc + math.sin(a) * L * 0.065))
			end
		end
	end
	return rig
end

-- Poses a rig for this frame. Appends parts and CFrames for workspace:BulkMoveTo.
--   phase: swim cycle angle, swim: 0.3 (lazy) .. 2 (fleeing)
function FishModels.Pose(rig, root: CFrame, phase: number, swim: number, parts, cframes)
	if rig.Shape == "eel" then
		local n, segLen = rig.Segments, rig.SegLen
		local amp = rig.W * 1.3 + rig.L * 0.025
		local frames = {}
		local xs = {}
		for i = 0, n - 1 do
			xs[i] = math.sin(phase - i * 0.75) * amp * (0.2 + 0.8 * i / (n - 1))
		end
		for i = 0, n - 1 do
			local z = -rig.L / 2 + segLen * (i + 0.5)
			local nextX = xs[math.min(i + 1, n - 1)]
			local prevX = xs[math.max(i - 1, 0)]
			local yaw = math.atan((nextX - prevX) / (2 * segLen))
			frames[i] = root * CFrame.new(xs[i], 0, z) * CFrame.Angles(0, yaw, 0)
		end
		for _, it in rig.Items do
			table.insert(parts, it.Part)
			table.insert(cframes, frames[it.Seg] * it.Offset)
		end
		return
	end
	local body = root * CFrame.Angles(0, math.sin(phase) * 0.06 * swim, 0)
	local tail = root * CFrame.new(0, 0, rig.Pivot) * CFrame.Angles(0, math.sin(phase - 0.9) * (0.3 + 0.22 * swim), 0)
	local flap = math.sin(phase * 0.6) * 0.35
	for _, it in rig.Items do
		local f
		if it.Kind == "body" then
			f = body
		elseif it.Kind == "tail" then
			f = tail
		elseif it.Kind == "finL" then
			f = body * rig.FinL * CFrame.Angles(0, 0, flap)
		else
			f = body * rig.FinR * CFrame.Angles(0, 0, -flap)
		end
		table.insert(parts, it.Part)
		table.insert(cframes, f * it.Offset)
	end
end

-- Front and back points of the fish's hit capsule.
function FishModels.Capsule(rig, root: CFrame): (Vector3, Vector3, number)
	return root * Vector3.new(0, 0, -rig.L / 2), root * Vector3.new(0, 0, rig.Back), rig.Radius
end

return FishModels
