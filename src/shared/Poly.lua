-- Low-poly geometry: real flat-shaded triangles built from pairs of WedgeParts
-- (the classic method from EgoMoose's "3D triangles" article), plus helpers for
-- rocks, cones, trunks, trees and simple meshes.
local Poly = {}

local FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }
local THICKNESS = 0.05

local function newWedge(props)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanCollide = false
	w.CanTouch = false
	w.CastShadow = props.Shadow == true
	w.CanQuery = props.Query == true
	w.Material = props.Material or Enum.Material.SmoothPlastic
	w.Color = props.Color or Color3.new(1, 1, 1)
	if props.Transparency then
		w.Transparency = props.Transparency
	end
	if props.Reflectance then
		w.Reflectance = props.Reflectance
	end
	for _, f in FACES do
		w[f] = Enum.SurfaceType.Smooth
	end
	if props.Name then
		w.Name = props.Name
	end
	return w
end
Poly.NewWedge = newWedge

-- Works out the two wedge sizes/CFrames that draw triangle a, b, c.
-- Returns size1, cf1, size2, cf2 (or nil for a degenerate triangle).
function Poly.Solve(a: Vector3, b: Vector3, c: Vector3, thickness: number?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local normal = ac:Cross(ab)
	if normal.Magnitude < 1e-6 or bc.Magnitude < 1e-6 then
		return nil
	end
	local right = normal.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local t = thickness or THICKNESS
	local size1 = Vector3.new(t, height, math.abs(ab:Dot(back)))
	local cf1 = CFrame.fromMatrix((a + b) / 2, right, up, back)
	local size2 = Vector3.new(t, height, math.abs(ac:Dot(back)))
	local cf2 = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	return size1, cf1, size2, cf2
end

-- Draws one triangle. props: Color, Material, Transparency, Parent, Name, Query, Shadow.
-- Returns the two wedges (or nothing for a degenerate triangle).
function Poly.Triangle(a: Vector3, b: Vector3, c: Vector3, props)
	props = props or {}
	local s1, cf1, s2, cf2 = Poly.Solve(a, b, c, props.Thickness)
	if not s1 then
		return nil
	end
	local w1, w2 = newWedge(props), newWedge(props)
	w1.Size, w1.CFrame = s1, cf1
	w2.Size, w2.CFrame = s2, cf2
	w1.Parent = props.Parent
	w2.Parent = props.Parent
	return w1, w2
end

function Poly.Quad(a, b, c, d, props)
	Poly.Triangle(a, b, c, props)
	Poly.Triangle(a, c, d, props)
end

-- verts: { Vector3 }, tris: { {i, j, k} }, colors: optional per-triangle Color3 list
function Poly.Mesh(verts, tris, props, colors)
	local parts = {}
	for n, t in tris do
		local p = props
		if colors and colors[n] then
			p = table.clone(props)
			p.Color = colors[n]
		end
		local w1, w2 = Poly.Triangle(verts[t[1]], verts[t[2]], verts[t[3]], p)
		if w1 then
			table.insert(parts, w1)
			table.insert(parts, w2)
		end
	end
	return parts
end

-- Shade a colour a little lighter or darker (k in -1..1) for flat-shaded variety.
function Poly.Shade(color: Color3, k: number): Color3
	if k >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), k)
	end
	return color:Lerp(Color3.new(0, 0, 0), -k)
end

-- Low-poly boulder: a jittered bipyramid. cf = centre, size = full extents.
function Poly.Rock(cf: CFrame, size: Vector3, color: Color3, rng: Random, props)
	props = table.clone(props or {})
	local sides = 6
	local verts = {}
	local top = cf * Vector3.new(rng:NextNumber(-0.15, 0.15) * size.X, size.Y * 0.5, rng:NextNumber(-0.15, 0.15) * size.Z)
	local bottom = cf * Vector3.new(0, -size.Y * 0.5, 0)
	for i = 0, sides - 1 do
		local a = i / sides * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local r = rng:NextNumber(0.8, 1.05)
		verts[i] = cf * Vector3.new(math.cos(a) * size.X * 0.5 * r, size.Y * rng:NextNumber(-0.05, 0.2), math.sin(a) * size.Z * 0.5 * r)
	end
	local parts = {}
	for i = 0, sides - 1 do
		local j = (i + 1) % sides
		props.Color = Poly.Shade(color, rng:NextNumber(-0.12, 0.12))
		for _, w in { Poly.Triangle(top, verts[i], verts[j], props) } do
			table.insert(parts, w)
		end
		props.Color = Poly.Shade(color, rng:NextNumber(-0.25, -0.05))
		for _, w in { Poly.Triangle(bottom, verts[j], verts[i], props) } do
			table.insert(parts, w)
		end
	end
	return parts
end

-- Cone with its base centred on cf (pointing up cf's Y), radius r, height h.
function Poly.Cone(cf: CFrame, r: number, h: number, sides: number, color: Color3, props, rng: Random?)
	props = table.clone(props or {})
	local tip = cf * Vector3.new(0, h, 0)
	local spin = if rng then rng:NextNumber(0, math.pi) else 0
	for i = 0, sides - 1 do
		local a0 = i / sides * math.pi * 2 + spin
		local a1 = (i + 1) / sides * math.pi * 2 + spin
		local p0 = cf * Vector3.new(math.cos(a0) * r, 0, math.sin(a0) * r)
		local p1 = cf * Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r)
		props.Color = Poly.Shade(color, if rng then rng:NextNumber(-0.1, 0.1) else (i % 2) * 0.06)
		Poly.Triangle(tip, p0, p1, props)
	end
end

-- Frustum (tapered prism), e.g. a tree trunk or a dock leg. Bottom at cf, top h above.
function Poly.Frustum(cf: CFrame, r0: number, r1: number, h: number, sides: number, color: Color3, props)
	props = table.clone(props or {})
	for i = 0, sides - 1 do
		local a0 = i / sides * math.pi * 2
		local a1 = (i + 1) / sides * math.pi * 2
		local b0 = cf * Vector3.new(math.cos(a0) * r0, 0, math.sin(a0) * r0)
		local b1 = cf * Vector3.new(math.cos(a1) * r0, 0, math.sin(a1) * r0)
		local t0 = cf * Vector3.new(math.cos(a0) * r1, h, math.sin(a0) * r1)
		local t1 = cf * Vector3.new(math.cos(a1) * r1, h, math.sin(a1) * r1)
		props.Color = Poly.Shade(color, (i % 2) * 0.07 - 0.03)
		Poly.Quad(b0, b1, t1, t0, props)
	end
end

-- Faceted blob: a jittered double cone with a mid ring (20 triangles). Tree canopies, coral, bushes.
function Poly.Blob(cf: CFrame, size: Vector3, color: Color3, rng: Random, props)
	props = table.clone(props or {})
	local sides = 5
	local top = cf * Vector3.new(0, size.Y * 0.5, 0)
	local bottom = cf * Vector3.new(0, -size.Y * 0.5, 0)
	local upper, lower = {}, {}
	for i = 0, sides - 1 do
		local a = i / sides * math.pi * 2
		local b = a + math.pi / sides
		local j1, j2 = rng:NextNumber(0.9, 1.08), rng:NextNumber(0.9, 1.08)
		upper[i] = cf * Vector3.new(math.cos(a) * size.X * 0.5 * j1, size.Y * 0.12, math.sin(a) * size.Z * 0.5 * j1)
		lower[i] = cf * Vector3.new(math.cos(b) * size.X * 0.4 * j2, -size.Y * 0.22, math.sin(b) * size.Z * 0.4 * j2)
	end
	for i = 0, sides - 1 do
		local j = (i + 1) % sides
		props.Color = Poly.Shade(color, 0.12 + rng:NextNumber(-0.04, 0.04))
		Poly.Triangle(top, upper[j], upper[i], props)
		props.Color = Poly.Shade(color, rng:NextNumber(-0.04, 0.04))
		Poly.Triangle(upper[i], upper[j], lower[i], props)
		props.Color = Poly.Shade(color, -0.08 + rng:NextNumber(-0.04, 0.04))
		Poly.Triangle(upper[j], lower[j], lower[i], props)
		props.Color = Poly.Shade(color, -0.22)
		Poly.Triangle(bottom, lower[i], lower[j], props)
	end
end

return Poly
