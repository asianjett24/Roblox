-- Low-poly sea creatures built from flat-shaded triangles (see Poly), with bones for animation.
--
-- Creature space: the head points down -Z, +Y is up, the creature is centred on the origin.
-- Shapes: fish, shark, hammer, round, flat (rays), turtle, eel, serpent, squid, kraken, jelly.
--
-- A rig is a set of groups ("bones"). Each group has a bind-pose pivot and the parts that
-- move with it. Pose() works out every group's CFrame for the current swim phase and returns
-- part CFrames for workspace:BulkMoveTo.
local Shared = script.Parent
local Poly = require(Shared.Poly)
local FishData = require(Shared.FishData)

local CreatureModels = {}

local WHITE = Color3.fromRGB(250, 250, 250)
local INK = Color3.fromRGB(18, 18, 26)

-- Deterministic random per name so every client draws the same markings.
local function seeded(name: string)
	local h = 7
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 2147483647
	end
	return Random.new(h)
end

-- Builder ---------------------------------------------------------------------------------
local Builder = {}
Builder.__index = Builder

local function newBuilder(name, look, opts)
	local self = setmetatable({}, Builder)
	self.Model = Instance.new("Model")
	self.Model.Name = name
	self.Groups = {}
	self.Look = look
	self.Opts = opts
	self.Rng = seeded(name)
	local mut = opts.Mutation and FishData.MutationByName[opts.Mutation]
	self.Mut = mut
	self.Material = if mut and mut.Material == "Metal" then Enum.Material.Metal
		elseif mut and mut.Material == "Neon" then Enum.Material.Neon
		else Enum.Material.SmoothPlastic
	self.Transparency = if look.Ghost then 0.45 else 0
	return self
end

function Builder:group(name, pivot: CFrame)
	local g = self.Groups[name]
	if not g then
		g = { Pivot = pivot or CFrame.new(), Parts = {} }
		self.Groups[name] = g
	end
	return g
end

-- Applies the mutation to a colour.
function Builder:color(c: Color3): Color3
	local mut = self.Mut
	if not mut then
		return c
	end
	local lum = c.R * 0.3 + c.G * 0.59 + c.B * 0.11
	if mut.Rainbow then
		return Color3.fromHSV(self.Rng:NextNumber(), 0.75, 1)
	end
	if mut.Name == "Shadow" then
		return mut.Color:Lerp(Color3.fromRGB(90, 60, 120), lum * 0.6)
	end
	return mut.Color:Lerp(if lum > 0.5 then WHITE else INK, math.abs(lum - 0.5) * 0.5)
end

function Builder:tri(groupName, a, b, c, color: Color3, glow: boolean?)
	local g = self:group(groupName)
	local w1, w2 = Poly.Triangle(a, b, c, {
		Color = self:color(color),
		Material = if glow then Enum.Material.Neon else self.Material,
		Transparency = self.Transparency,
		Parent = self.Model,
	})
	if w1 then
		table.insert(g.Parts, w1)
		table.insert(g.Parts, w2)
	end
end

function Builder:quad(groupName, a, b, c, d, color, glow)
	self:tri(groupName, a, b, c, color, glow)
	self:tri(groupName, a, c, d, color, glow)
end

-- A small box (eyes, lure bulbs)
function Builder:box(groupName, cf: CFrame, size: Vector3, color: Color3, neon: boolean?)
	local g = self:group(groupName)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = if neon then color else self:color(color)
	p.Material = if neon then Enum.Material.Neon else self.Material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = self.Transparency
	p.Parent = self.Model
	table.insert(g.Parts, p)
	return p
end

-- Hexagonal (or n-sided) cross-section ring. r = { z, w, h, y } (half sizes).
local function ring(r, sides)
	local pts = {}
	for i = 0, sides - 1 do
		local a = math.pi / 2 - i * (math.pi * 2 / sides)
		pts[i] = Vector3.new(r.w * math.cos(a), (r.y or 0) + r.h * math.sin(a), r.z)
	end
	return pts
end

-- Lofts a body through rings. groupOf(k) picks the bone for segment k.
-- colorOf(k, side, sides) picks each facet's colour.
function Builder:loft(rings, sides, groupOf, colorOf, glowOf)
	local pts = {}
	for k, r in rings do
		pts[k] = ring(r, sides)
	end
	for k = 1, #rings - 1 do
		local g = groupOf(k)
		for i = 0, sides - 1 do
			local j = (i + 1) % sides
			local a, b = pts[k][i], pts[k][j]
			local c, d = pts[k + 1][j], pts[k + 1][i]
			local col = colorOf(k, i, sides)
			local glow = glowOf and glowOf(k, i, sides)
			if rings[k].w == 0 and rings[k].h == 0 then
				self:tri(g, a, d, c, col, glow) -- pointed nose
			elseif rings[k + 1].w == 0 and rings[k + 1].h == 0 then
				self:tri(g, a, d, b, col, glow) -- pointed tail
			else
				self:quad(g, a, d, c, b, col, glow)
			end
		end
	end
	return pts
end

-- Colouring helpers ---------------------------------------------------------------------
-- Side index 0 / sides-1 are the top facets; the middle ones are the belly.
local function facetZone(i, sides)
	local mid = (i + 0.5) / sides -- 0..1 going clockwise from the top
	if mid < 0.17 or mid > 0.83 then
		return "top"
	elseif mid > 0.36 and mid < 0.64 then
		return "belly"
	end
	return "side"
end

function Builder:bodyColorFn(segments)
	local look = self.Look
	local rng = self.Rng
	local spots = {}
	if look.Pattern == "spots" then
		for k = 1, segments do
			spots[k] = {}
			for i = 0, 7 do
				spots[k][i] = rng:NextNumber() < 0.3
			end
		end
	end
	return function(k, i, sides)
		local zone = facetZone(i, sides)
		local base = if zone == "top" then look.Body elseif zone == "belly" then look.Belly else look.Body:Lerp(look.Belly, 0.35)
		local accent = look.Accent or look.Fin
		if look.Pattern == "bands" and (k == 2 or k == 4) and zone ~= "belly" then
			return accent
		elseif look.Pattern == "stripes" and zone == "side" and k >= 2 then
			return accent
		elseif look.Pattern == "spots" and zone ~= "belly" and spots[k] and spots[k][i] then
			return accent
		end
		-- subtle per-facet variation gives the flat-shaded low-poly sparkle
		return Poly.Shade(base, (i % 2) * 0.05 - 0.02)
	end
end

-- Eyes: dark cube with a white glint (neon for glowing creatures)
function Builder:eyes(groupName, z, y, x, size)
	local look = self.Look
	local glow = look.Glow or (self.Mut and self.Mut.Glow)
	local eyeColor = if self.Mut and self.Mut.Glow then self.Mut.Glow elseif look.Glow then (look.Accent or look.Fin) else INK
	for _, sx in { -1, 1 } do
		local cf = CFrame.new(sx * x, y, z) * CFrame.Angles(0, 0, math.rad(45))
		self:box(groupName, cf, Vector3.new(size * 0.7, size, size), eyeColor, glow)
		if not glow then
			self:box(groupName, CFrame.new(sx * (x + size * 0.32), y + size * 0.18, z - size * 0.15), Vector3.one * size * 0.3, WHITE, true)
		end
	end
end

-- Thin flat fin: a triangle a-b-c in a group
function Builder:fin(groupName, a, b, c, color)
	self:tri(groupName, a, b, c, color)
end

-- Shapes ------------------------------------------------------------------------------------
local function buildFishLike(B, L, kind)
	local look = B.Look
	local H, W = look.H * L / 2, look.W * L / 2
	local simple = B.Opts.Simple
	local sides = if simple then 4 else 6
	local rings
	if kind == "shark" or kind == "hammer" then
		rings = {
			{ z = -0.5 * L, w = 0, h = 0, y = H * 0.1 },
			{ z = -0.38 * L, w = W * 0.55, h = H * 0.62, y = H * 0.05 },
			{ z = -0.15 * L, w = W, h = H, y = 0 },
			{ z = 0.12 * L, w = W * 0.72, h = H * 0.7, y = H * 0.05 },
			{ z = 0.36 * L, w = W * 0.16, h = H * 0.2, y = H * 0.1 },
		}
	elseif kind == "round" then
		rings = {
			{ z = -0.48 * L, w = W * 0.35, h = H * 0.35, y = 0 },
			{ z = -0.3 * L, w = W * 0.88, h = H * 0.88, y = 0 },
			{ z = 0, w = W, h = H, y = 0 },
			{ z = 0.24 * L, w = W * 0.7, h = H * 0.7, y = 0 },
			{ z = 0.38 * L, w = W * 0.14, h = H * 0.14, y = 0 },
		}
	else
		rings = {
			{ z = -0.5 * L, w = 0, h = 0, y = -H * 0.04 },
			{ z = -0.36 * L, w = W * 0.62, h = H * 0.74, y = H * 0.02 },
			{ z = -0.12 * L, w = W, h = H, y = 0 },
			{ z = 0.13 * L, w = W * 0.74, h = H * 0.76, y = 0 },
			{ z = 0.34 * L, w = W * 0.17, h = H * 0.2, y = 0 },
		}
	end
	local peduncle = rings[#rings]
	local pz = peduncle.z
	B:group("body", CFrame.new())
	B:group("tail", CFrame.new(0, peduncle.y, pz))
	local colorOf = B:bodyColorFn(#rings)
	B:loft(rings, sides, function()
		return "body"
	end, colorOf, if look.Glow and look.Pattern == "spots" then function(k, i, s)
		return colorOf(k, i, s) == (look.Accent or look.Fin)
	end else nil)
	-- cap the peduncle so the body looks closed from behind
	local cap = ring(peduncle, sides)
	local capPoint = Vector3.new(0, peduncle.y, pz + 0.02 * L)
	for i = 0, sides - 1 do
		B:tri("body", cap[i], cap[(i + 1) % sides], capPoint, look.Body)
	end

	-- Tail fin (moves with the "tail" bone)
	local tailH = math.max(H * 1.6, L * 0.14)
	local root = Vector3.new(0, peduncle.y, pz)
	local tail = look.Tail or "fork"
	if tail == "round" or tail == "fan" then
		local spread = if tail == "fan" then 1.25 else 1
		B:fin("tail", root, Vector3.new(0, peduncle.y + tailH * 0.55 * spread, pz + L * 0.16), Vector3.new(0, peduncle.y, pz + L * 0.2), look.Fin)
		B:fin("tail", root, Vector3.new(0, peduncle.y, pz + L * 0.2), Vector3.new(0, peduncle.y - tailH * 0.55 * spread, pz + L * 0.16), Poly.Shade(look.Fin, -0.1))
	elseif tail == "point" then
		B:fin("tail", root + Vector3.new(0, H * 0.3, 0), Vector3.new(0, peduncle.y, pz + L * 0.18), root - Vector3.new(0, H * 0.3, 0), look.Fin)
	else
		local reach = if tail == "crescent" then 0.24 else 0.18
		local up = if kind == "shark" or kind == "hammer" then 1.25 else 1
		local notch = Vector3.new(0, peduncle.y, pz + L * reach * 0.45)
		B:fin("tail", root, Vector3.new(0, peduncle.y + tailH * 0.62 * up, pz + L * reach), notch, look.Fin)
		B:fin("tail", root, notch, Vector3.new(0, peduncle.y - tailH * 0.55, pz + L * reach * 0.9), Poly.Shade(look.Fin, -0.12))
	end

	if simple then
		B:eyes("body", -0.33 * L, H * 0.25, W * 0.5, math.max(0.08 * L, 0.12))
		return
	end

	-- Dorsal fin
	local top = H
	local dorsal = look.Dorsal or "low"
	if dorsal == "low" then
		B:fin("body", Vector3.new(0, top * 0.95, -0.18 * L), Vector3.new(0, top * 1.45, 0.02 * L), Vector3.new(0, top * 0.8, 0.12 * L), look.Fin)
	elseif dorsal == "tall" then
		B:fin("body", Vector3.new(0, top * 0.95, -0.2 * L), Vector3.new(0, top * 2.1, 0.04 * L), Vector3.new(0, top * 0.85, 0.02 * L), look.Fin)
		B:fin("body", Vector3.new(0, H * 0.55, 0.22 * L), Vector3.new(0, H * 0.95, 0.3 * L), Vector3.new(0, H * 0.3, 0.3 * L), look.Fin)
	elseif dorsal == "sail" then
		B:quad("body", Vector3.new(0, top * 0.95, -0.32 * L), Vector3.new(0, top * 2.2, -0.22 * L), Vector3.new(0, top * 1.7, 0.2 * L), Vector3.new(0, top * 0.75, 0.25 * L), look.Fin)
	elseif dorsal == "spiny" then
		for s = 0, 4 do
			local z = -0.24 * L + s * 0.09 * L
			B:fin("body", Vector3.new(0, top * 0.9, z), Vector3.new(0, top * (2.1 - s * 0.15), z + 0.04 * L), Vector3.new(0, top * 0.9, z + 0.07 * L), if s % 2 == 0 then look.Fin else (look.Accent or look.Fin))
		end
	end
	-- Anal fin
	B:fin("body", Vector3.new(0, -H * 0.8, 0.08 * L), Vector3.new(0, -H * 1.25, 0.2 * L), Vector3.new(0, -H * 0.55, 0.26 * L), Poly.Shade(look.Fin, -0.1))

	-- Pectoral fins on their own bones so they can flap
	local finZ = -0.2 * L
	local big = kind == "shark" or kind == "hammer"
	for _, sx in { -1, 1 } do
		local name = if sx < 0 then "finL" else "finR"
		local rootP = Vector3.new(sx * W * 0.8, -H * 0.35, finZ)
		B:group(name, CFrame.new(rootP))
		local span = if big then 0.32 * L else 0.16 * L
		B:fin(name, rootP, rootP + Vector3.new(sx * span, -span * (if big then 0.45 else 0.2), span * 0.7), rootP + Vector3.new(0, 0, (if big then 0.2 else 0.12) * L), look.Fin)
	end

	-- Head details
	local headZ = -0.3 * L
	B:eyes("body", headZ, H * 0.28, W * 0.55, math.max(0.06 * L, 0.12))
	if kind == "hammer" then
		local hz = -0.44 * L
		local span = 0.3 * L
		local th = H * 0.18
		local fl, fr = Vector3.new(-span, H * 0.05, hz), Vector3.new(span, H * 0.05, hz)
		local bc = Vector3.new(0, H * 0.05 + th, hz + 0.08 * L)
		local fc = Vector3.new(0, H * 0.05 + th, hz - 0.03 * L)
		local under = Vector3.new(0, H * 0.05 - th, hz + 0.02 * L)
		B:tri("body", fl, fc, bc, look.Body)
		B:tri("body", fr, bc, fc, look.Body)
		B:tri("body", fl, bc, under, look.Belly)
		B:tri("body", fr, under, bc, look.Belly)
		B:tri("body", fl, under, fc, Poly.Shade(look.Body, -0.1))
		B:tri("body", fr, fc, under, Poly.Shade(look.Body, -0.1))
		for _, sx in { -1, 1 } do
			B:box("body", CFrame.new(sx * span * 0.98, H * 0.1, hz), Vector3.one * math.max(0.05 * L, 0.2), INK)
		end
	end
	if kind == "shark" or kind == "hammer" then
		-- gill slits
		for g = 0, 2 do
			local z = -0.26 * L + g * 0.035 * L
			for _, sx in { -1, 1 } do
				B:box("body", CFrame.new(sx * W * 0.86, -H * 0.05, z), Vector3.new(0.02 * L, H * 0.5, 0.006 * L + 0.02), Poly.Shade(look.Body, -0.35))
			end
		end
	end
	if look.Teeth then
		local mz = -0.44 * L
		for t = -2, 2 do
			local x = t * W * 0.14
			B:fin("body", Vector3.new(x - W * 0.05, -H * 0.18, mz), Vector3.new(x + W * 0.05, -H * 0.18, mz), Vector3.new(x, -H * 0.36, mz - 0.01 * L), WHITE)
		end
	end
	if look.Bill then
		local base = Vector3.new(0, 0, -0.48 * L)
		local tip = Vector3.new(0, -H * 0.05, -0.85 * L)
		B:tri("body", base + Vector3.new(0, H * 0.12, 0), base + Vector3.new(W * 0.12, -H * 0.06, 0), tip, Poly.Shade(look.Body, 0.15))
		B:tri("body", base + Vector3.new(0, H * 0.12, 0), tip, base + Vector3.new(-W * 0.12, -H * 0.06, 0), Poly.Shade(look.Body, 0.05))
	end
	if look.Lure then
		local base = Vector3.new(0, H * 0.95, -0.2 * L)
		local tip = Vector3.new(0, H * 1.9, -0.55 * L)
		B:fin("body", base, base + Vector3.new(0, 0, 0.04 * L), tip, look.Fin)
		local bulb = B:box("body", CFrame.new(tip), Vector3.one * math.max(0.08 * L, 0.25), Color3.fromRGB(190, 255, 240), true)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(140, 255, 230)
		light.Range = 14
		light.Brightness = 2
		light.Parent = bulb
	end
	if look.Spikes then
		local rng = B.Rng
		for k = 2, 4 do
			local pts = ring(rings[k], sides)
			for i = 0, sides - 1 do
				local p = pts[i]
				local out = Vector3.new(p.X, p.Y, 0)
				if out.Magnitude > 1e-3 then
					out = out.Unit
					local side = Vector3.new(0, 0, 0.05 * L)
					B:tri("body", p - side, p + side, p + out * (0.14 * L) + Vector3.new(0, 0, rng:NextNumber(-0.02, 0.02) * L), Poly.Shade(look.Fin, 0.2))
				end
			end
		end
	end
	if look.Horns then
		for _, sx in { -1, 1 } do
			local base = Vector3.new(sx * W * 0.4, H * 0.6, -0.32 * L)
			B:tri("body", base, base + Vector3.new(0, 0, 0.08 * L), base + Vector3.new(sx * W * 0.4, H * 1.3, 0.16 * L), look.Fin)
		end
	end
end

-- Rays: a flat diamond body with flapping wings and a whip tail.
local function buildFlat(B, L)
	local look = B.Look
	local Hh, span = look.H * L / 2, look.W * L / 2
	local core = span * 0.22
	local N = Vector3.new(0, 0, -0.45 * L)
	local T = Vector3.new(0, Hh, -0.08 * L)
	local Bt = Vector3.new(0, -Hh * 0.6, -0.08 * L)
	local P = Vector3.new(0, 0, 0.3 * L)
	local CL, CR = Vector3.new(-core, 0, -0.1 * L), Vector3.new(core, 0, -0.1 * L)
	B:group("body", CFrame.new())
	local top, belly = look.Body, look.Belly
	B:tri("body", N, CR, T, top)
	B:tri("body", N, T, CL, Poly.Shade(top, 0.05))
	B:tri("body", T, CR, P, Poly.Shade(top, -0.05))
	B:tri("body", T, P, CL, top)
	B:tri("body", N, Bt, CR, belly)
	B:tri("body", N, CL, Bt, belly)
	B:tri("body", Bt, P, CR, Poly.Shade(belly, -0.08))
	B:tri("body", Bt, CL, P, Poly.Shade(belly, -0.08))
	local rng = B.Rng
	for _, sx in { -1, 1 } do
		local name = if sx < 0 then "finL" else "finR"
		local edge = if sx < 0 then CL else CR
		B:group(name, CFrame.new(edge))
		local tip = Vector3.new(sx * span, 0, 0.02 * L)
		local mid = Vector3.new(sx * span * 0.55, Hh * 0.25, -0.2 * L)
		local spotted = look.Pattern == "spots"
		B:tri(name, N, edge, mid, top)
		B:tri(name, edge, P, mid, Poly.Shade(top, -0.05))
		B:tri(name, mid, P, tip, if spotted and rng:NextNumber() < 0.5 then (look.Accent or top) else Poly.Shade(top, 0.06))
		B:tri(name, N, mid, tip, if spotted and rng:NextNumber() < 0.5 then (look.Accent or top) else top)
	end
	-- Whip tail
	B:group("tail", CFrame.new(P))
	B:tri("tail", P + Vector3.new(-core * 0.15, 0, 0), P + Vector3.new(core * 0.15, 0, 0), P + Vector3.new(0, 0, 0.55 * L), Poly.Shade(top, -0.15))
	B:eyes("body", -0.3 * L, Hh * 0.6, core * 0.7, math.max(0.04 * L, 0.15))
	if look.Horns then
		for _, sx in { -1, 1 } do
			B:tri("body", N + Vector3.new(sx * core * 0.3, 0, 0), N + Vector3.new(sx * core * 0.9, 0, 0.06 * L), N + Vector3.new(sx * core * 0.8, 0, -0.1 * L), top)
		end
	end
end

-- Turtle: domed faceted shell, head, four flippers
local function buildTurtle(B, L)
	local look = B.Look
	local W, H = look.W * L / 2, look.H * L / 2
	B:group("body", CFrame.new())
	local rings = {
		{ z = -0.36 * L, w = W * 0.45, h = H * 0.35, y = 0 },
		{ z = -0.2 * L, w = W * 0.92, h = H * 0.85, y = H * 0.1 },
		{ z = 0.05 * L, w = W, h = H, y = H * 0.15 },
		{ z = 0.26 * L, w = W * 0.7, h = H * 0.6, y = H * 0.05 },
		{ z = 0.36 * L, w = 0, h = 0, y = 0 },
	}
	local shellA, shellB = look.Body, look.Accent or Poly.Shade(look.Body, -0.2)
	B:loft(rings, 6, function()
		return "body"
	end, function(k, i, sides)
		local zone = facetZone(i, sides)
		if zone == "belly" then
			return look.Belly
		end
		return if (k + i) % 2 == 0 then shellA else shellB
	end)
	-- Head
	local neck = Vector3.new(0, H * 0.1, -0.36 * L)
	local headRings = {
		{ z = -0.34 * L, w = W * 0.22, h = H * 0.35, y = H * 0.1 },
		{ z = -0.48 * L, w = W * 0.2, h = H * 0.32, y = H * 0.15 },
		{ z = -0.56 * L, w = 0, h = 0, y = H * 0.1 },
	}
	B:group("head", CFrame.new(neck))
	B:loft(headRings, 5, function()
		return "head"
	end, function()
		return look.Fin
	end)
	B:eyes("head", -0.48 * L, H * 0.3, W * 0.18, math.max(0.04 * L, 0.12))
	-- Flippers
	for _, f in { { "finL", -1, -0.15, 0.55 }, { "finR", 1, -0.15, 0.55 }, { "rearL", -1, 0.25, 0.28 }, { "rearR", 1, 0.25, 0.28 } } do
		local name, sx, z, len = f[1], f[2], f[3], f[4]
		local rootP = Vector3.new(sx * W * 0.85, 0, z * L)
		B:group(name, CFrame.new(rootP))
		B:tri(name, rootP + Vector3.new(0, 0, -0.06 * L), rootP + Vector3.new(0, 0, 0.06 * L), rootP + Vector3.new(sx * len * L * 0.6, -H * 0.1, len * L * 0.4), look.Fin)
	end
end

-- Eels and serpents: a chain of segments that ripple.
local function buildEel(B, L, serpent)
	local look = B.Look
	local H, W = look.H * L / 2, look.W * L / 2
	local n = if B.Opts.Simple then 5 elseif serpent then 12 else 9
	local segLen = L / n
	local sides = if B.Opts.Simple then 4 else 6
	B.Chain = { N = n, SegLen = segLen }
	local colorOf = B:bodyColorFn(n + 1)
	for s = 0, n - 1 do
		local z0 = -L / 2 + s * segLen
		B:group("seg" .. s, CFrame.new(0, 0, z0))
		local function taper(t)
			return 1 - 0.65 * t
		end
		local t0, t1 = s / n, (s + 1) / n
		local r0 = { z = z0, w = W * taper(t0), h = H * taper(t0), y = 0 }
		-- overlap a little into the next segment so bends don't open gaps
		local r1 = { z = z0 + segLen * 1.12, w = W * taper(t1), h = H * taper(t1), y = 0 }
		if s == 0 then
			r0 = { z = z0 - segLen * 0.35, w = 0, h = 0, y = 0 }
		end
		B:loft({ r0, r1 }, sides, function()
			return "seg" .. s
		end, function(_, i, sd)
			return colorOf(s + 1, i, sd)
		end, if look.Glow then function(_, i, sd)
			return facetZone(i, sd) == "side" and s % 2 == 1
		end else nil)
		if look.Spines and not B.Opts.Simple and s > 0 then
			local top = Vector3.new(0, H * taper(t0) * 0.95, z0 + segLen * 0.2)
			B:tri("seg" .. s, top, top + Vector3.new(0, H * taper(t0) * 1.4, segLen * 0.5), top + Vector3.new(0, 0, segLen * 0.9), look.Fin)
		end
	end
	-- Head details on the first segment
	local headZ = -L / 2 + segLen * 0.35
	B:eyes("seg0", headZ, H * 0.45, W * 0.75, math.max(H * 0.55, 0.15))
	if look.Horns and not B.Opts.Simple then
		for _, sx in { -1, 1 } do
			local base = Vector3.new(sx * W * 0.5, H * 0.6, headZ + segLen * 0.2)
			B:tri("seg0", base, base + Vector3.new(0, 0, segLen * 0.25), base + Vector3.new(sx * W * 0.8, H * 1.8, segLen * 0.9), look.Fin)
		end
	end
	if look.BigMouth and not B.Opts.Simple then
		local jaw = -L / 2 - segLen * 0.3
		B:tri("seg0", Vector3.new(-W * 1.6, -H * 0.2, jaw + segLen * 0.6), Vector3.new(W * 1.6, -H * 0.2, jaw + segLen * 0.6), Vector3.new(0, -H * 1.6, jaw), Poly.Shade(look.Body, -0.2))
	end
	if look.Teeth and not B.Opts.Simple then
		for t = -1, 1 do
			local x = t * W * 0.3
			B:tri("seg0", Vector3.new(x - W * 0.1, -H * 0.3, -L / 2 - segLen * 0.1), Vector3.new(x + W * 0.1, -H * 0.3, -L / 2 - segLen * 0.1), Vector3.new(x, -H * 0.7, -L / 2 - segLen * 0.15), WHITE)
		end
	end
	if look.Lure and not B.Opts.Simple then
		local bulb = B:box("seg0", CFrame.new(0, -H * 1.4, -L / 2), Vector3.one * math.max(H * 0.6, 0.2), look.Fin, true)
		local light = Instance.new("PointLight")
		light.Color = look.Fin
		light.Range = 12
		light.Brightness = 2
		light.Parent = bulb
	end
	-- Tail fin on the last segment
	local last = "seg" .. (n - 1)
	local tz = -L / 2 + n * segLen
	local tailH = H * 2.4
	if look.Tail == "crescent" or look.Tail == "fan" or look.Tail == "fork" then
		B:tri(last, Vector3.new(0, 0, tz - segLen * 0.3), Vector3.new(0, tailH, tz + segLen * 0.4), Vector3.new(0, 0, tz + segLen * 0.2), look.Fin)
		B:tri(last, Vector3.new(0, 0, tz - segLen * 0.3), Vector3.new(0, 0, tz + segLen * 0.2), Vector3.new(0, -tailH, tz + segLen * 0.4), Poly.Shade(look.Fin, -0.1))
	else
		B:tri(last, Vector3.new(0, H * 0.5, tz - segLen * 0.6), Vector3.new(0, 0, tz + segLen * 0.5), Vector3.new(0, -H * 0.5, tz - segLen * 0.6), look.Fin)
	end
end

-- Squid / octopus / kraken: a mantle with arms trailing behind (+Z).
local function buildSquid(B, L, boss)
	local look = B.Look
	local R = look.W * L / 2
	local simple = B.Opts.Simple
	local mantleLen = if look.LongArms then 0.42 * L else 0.5 * L
	B:group("body", CFrame.new())
	local z0 = -L / 2
	local rings = {
		{ z = z0, w = 0, h = 0, y = 0 },
		{ z = z0 + mantleLen * 0.25, w = R * 0.7, h = R * 0.7, y = 0 },
		{ z = z0 + mantleLen * 0.7, w = R, h = R, y = 0 },
		{ z = z0 + mantleLen, w = R * 0.75, h = R * 0.75, y = 0 },
		{ z = z0 + mantleLen * 1.18, w = R * 0.85, h = R * 0.85, y = 0 },
	}
	local colorOf = B:bodyColorFn(#rings)
	B:loft(rings, if simple then 5 else 6, function()
		return "body"
	end, function(k, i, sides)
		if look.Accent and (k + i) % 4 == 0 then
			return look.Accent
		end
		return colorOf(k, i, sides)
	end)
	-- fins at the mantle tip
	if look.LongArms or boss then
		for _, sx in { -1, 1 } do
			B:tri("body", Vector3.new(sx * R * 0.3, 0, z0 + mantleLen * 0.05), Vector3.new(sx * R * 1.6, 0, z0 + mantleLen * 0.35), Vector3.new(sx * R * 0.7, 0, z0 + mantleLen * 0.5), look.Fin)
		end
	end
	local headZ = z0 + mantleLen * 1.18
	B:eyes("body", headZ - mantleLen * 0.12, R * 0.35, R * 0.8, math.max(R * 0.35, 0.18))
	-- Arms: chains of thin 3-sided segments
	local arms = if simple then 4 else (look.Arms or 8)
	local segs = if simple then 2 elseif boss then 5 else 3
	local armLen = (L - mantleLen * 1.18) * (if look.LongArms then 0.75 else 1)
	B.Arms = {}
	local function addArm(a, len, nSegs, thick, id)
		local base = Vector3.new(math.cos(a) * R * 0.6, math.sin(a) * R * 0.6, headZ)
		local out = Vector3.new(math.cos(a), math.sin(a), 0)
		local segLen = len / nSegs
		local arm = { Base = base, Out = out, SegLen = segLen, N = nSegs, Phase = a * 1.7, Id = id }
		table.insert(B.Arms, arm)
		for s = 0, nSegs - 1 do
			local name = "arm" .. id .. "_" .. s
			local pivot = CFrame.new(base + out * (s * segLen * 0.25) + Vector3.new(0, 0, s * segLen))
			B:group(name, pivot)
			local t0 = thick * (1 - s / nSegs * 0.8)
			local t1 = thick * (1 - (s + 1) / nSegs * 0.8)
			local c0 = base + out * (s * segLen * 0.25) + Vector3.new(0, 0, s * segLen)
			local c1 = base + out * ((s + 1) * segLen * 0.25) + Vector3.new(0, 0, (s + 1) * segLen * 1.05)
			-- A low ridge: two faces meeting along the top of the arm (light and cheap)
			local side = Vector3.new(-out.Y, out.X, 0)
			local ridge0, ridge1 = c0 + out * t0, c1 + out * t1
			local l0, r0 = c0 + side * t0, c0 - side * t0
			local l1, r1 = c1 + side * t1, c1 - side * t1
			if s == nSegs - 1 then
				local tip = c1 + Vector3.new(0, 0, segLen * 0.2)
				B:tri(name, ridge0, l0, tip, look.Body)
				B:tri(name, ridge0, tip, r0, Poly.Shade(look.Body, -0.12))
			else
				B:quad(name, ridge0, l0, l1, ridge1, look.Body)
				B:quad(name, ridge0, ridge1, r1, r0, Poly.Shade(look.Body, -0.12))
			end
		end
	end
	for k = 0, arms - 1 do
		addArm(k / arms * math.pi * 2 + 0.3, armLen, segs, R * 0.18, k)
	end
	if look.LongArms and not simple then
		addArm(math.pi * 0.5, armLen * 1.7, segs + 1, R * 0.12, arms)
		addArm(math.pi * 1.5, armLen * 1.7, segs + 1, R * 0.12, arms + 1)
	end
end

-- Jellyfish: faceted bell (always upright) with drifting tentacles.
local function buildJelly(B, L)
	local look = B.Look
	local R = look.W * L / 2
	local H = look.H * L
	B:group("body", CFrame.new())
	local sides = 7
	local top = Vector3.new(0, H * 0.5, 0)
	local mid, rim = {}, {}
	for i = 0, sides - 1 do
		local a = i / sides * math.pi * 2
		mid[i] = Vector3.new(math.cos(a) * R * 0.75, H * 0.2, math.sin(a) * R * 0.75)
		rim[i] = Vector3.new(math.cos(a + 0.22) * R, -H * 0.15, math.sin(a + 0.22) * R)
	end
	for i = 0, sides - 1 do
		local j = (i + 1) % sides
		B:tri("body", top, mid[j], mid[i], Poly.Shade(look.Body, 0.1), true)
		B:quad("body", mid[i], mid[j], rim[j], rim[i], if i % 2 == 0 then look.Body else (look.Accent or look.Belly), true)
	end
	B.Arms = {}
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local base = Vector3.new(math.cos(a) * R * 0.5, -H * 0.15, math.sin(a) * R * 0.5)
		local arm = { Base = base, Out = Vector3.new(0, -1, 0), SegLen = H * 0.5, N = 3, Phase = a, Id = k, Hanging = true }
		table.insert(B.Arms, arm)
		for s = 0, 2 do
			local name = "arm" .. k .. "_" .. s
			local c0 = base - Vector3.new(0, s * arm.SegLen, 0)
			B:group(name, CFrame.new(c0))
			local w = R * 0.08 * (1 - s * 0.25)
			B:tri(name, c0 + Vector3.new(-w, 0, 0), c0 + Vector3.new(w, 0, 0), c0 - Vector3.new(0, arm.SegLen * 1.1, 0), look.Fin, true)
		end
	end
end

-- Public -----------------------------------------------------------------------------------------
-- Builds a creature. id: FishData id, or a guardian table from Zones (with Kind/L/colours).
-- opts: { Scale, Simple, Mutation, Boss }
function CreatureModels.Build(id, opts)
	opts = opts or {}
	local look, kind, name
	if type(id) == "table" then
		local g = id
		kind = g.Kind
		name = g.Name
		look = {
			Body = g.Body, Belly = g.Belly, Fin = g.Fin, Accent = g.Accent,
			L = g.L, H = 0.22, W = 0.2, Tail = "crescent", Dorsal = "tall", Teeth = true,
		}
		if kind == "eel" then
			look.H, look.W, look.Tail, look.Pattern = 0.07, 0.06, "point", "spots"
		elseif kind == "serpent" then
			look.H, look.W, look.Horns, look.Spines, look.Glow = 0.06, 0.055, true, true, true
		elseif kind == "kraken" then
			look.H, look.W, look.Arms, look.LongArms = 0.3, 0.32, 8, true
		end
		opts.Boss = true
	else
		local f = FishData.ById[id]
		look = f.Look
		kind = look.Shape or "fish"
		name = f.Id
	end
	local B = newBuilder(name, look, opts)
	local L = look.L * (opts.Scale or 1)
	if kind == "fish" or kind == "shark" or kind == "hammer" or kind == "round" then
		buildFishLike(B, L, kind)
	elseif kind == "flat" then
		buildFlat(B, L)
	elseif kind == "turtle" then
		buildTurtle(B, L)
	elseif kind == "eel" then
		buildEel(B, L, false)
	elseif kind == "serpent" then
		buildEel(B, L, true)
	elseif kind == "squid" or kind == "kraken" then
		buildSquid(B, L, kind == "kraken")
	elseif kind == "jelly" then
		buildJelly(B, L)
	else
		buildFishLike(B, L, "fish")
	end

	-- Bake offsets (each part relative to its group's bind pivot)
	local groups = {}
	local partCount = 0
	for gname, g in B.Groups do
		local inv = g.Pivot:Inverse()
		local offsets = {}
		for i, p in g.Parts do
			offsets[i] = inv * p.CFrame
		end
		partCount += #g.Parts
		groups[gname] = { Name = gname, Pivot = g.Pivot, Parts = g.Parts, Offsets = offsets }
	end
	local H, W = look.H * L / 2, look.W * L / 2
	local radius = if kind == "flat" then W * 0.45 elseif kind == "jelly" then W * 0.9 else math.max(H, W) * 1.05
	return {
		Model = B.Model,
		Kind = kind,
		Groups = groups,
		Chain = B.Chain,
		Arms = B.Arms,
		L = L,
		Radius = math.max(radius, 0.4),
		Back = if kind == "eel" or kind == "serpent" then L * 0.45 else L * 0.3,
		PartCount = partCount,
	}
end

-- Animation ------------------------------------------------------------------------------------
-- phase: swim cycle angle; swim: 0.3 (lazy) .. 2 (fleeing / chasing).
-- Appends to parts / cframes for workspace:BulkMoveTo.
function CreatureModels.Pose(rig, root: CFrame, phase: number, swim: number, parts, cframes)
	local G = rig.Groups
	local frames = {}
	local kind = rig.Kind
	if kind == "jelly" then
		-- jellies stay upright and pulse
		local pos = root.Position
		local look = root.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		root = CFrame.new(pos + Vector3.new(0, math.sin(phase * 0.5) * 0.3, 0)) * CFrame.Angles(0, yaw, 0)
	end
	local sway = math.sin(phase) * 0.06 * swim
	local body = root * CFrame.Angles(0, sway, 0)
	frames.body = body

	if rig.Chain then
		local n, segLen = rig.Chain.N, rig.Chain.SegLen
		local amp = 0.32 * math.clamp(swim, 0.5, 1.6)
		local f = root * CFrame.new(0, 0, -rig.L / 2) * CFrame.Angles(0, math.sin(phase) * amp * 0.25, 0)
		frames.seg0 = f
		local prev = math.sin(phase) * amp * 0.25
		for s = 1, n - 1 do
			local a = math.sin(phase - s * 0.75) * amp * (0.35 + 0.65 * s / n)
			f = f * CFrame.new(0, 0, segLen) * CFrame.Angles(0, (a - prev) * 0.9, 0)
			prev = a
			frames["seg" .. s] = f
		end
	end

	if G.tail then
		local amp = if kind == "flat" then 0.15 else (0.3 + 0.22 * swim)
		frames.tail = body * G.tail.Pivot * CFrame.Angles(0, math.sin(phase - 0.9) * amp, 0)
	end
	if G.head then
		frames.head = body * G.head.Pivot * CFrame.Angles(math.sin(phase * 0.5) * 0.08, math.sin(phase * 0.3) * 0.12, 0)
	end
	local flap
	if kind == "flat" then
		flap = math.sin(phase * 0.45) * 0.55
	elseif kind == "turtle" then
		flap = math.sin(phase * 0.4) * 0.6
	else
		flap = math.sin(phase * 0.6) * 0.3
	end
	if G.finL then
		frames.finL = body * G.finL.Pivot * CFrame.Angles(0, if kind == "turtle" then flap * 0.6 else 0, flap)
	end
	if G.finR then
		frames.finR = body * G.finR.Pivot * CFrame.Angles(0, if kind == "turtle" then -flap * 0.6 else 0, -flap)
	end
	if G.rearL then
		frames.rearL = body * G.rearL.Pivot * CFrame.Angles(0, -flap * 0.4, flap * 0.4)
		frames.rearR = body * G.rearR.Pivot * CFrame.Angles(0, flap * 0.4, -flap * 0.4)
	end

	if rig.Arms then
		-- Each arm is a chain: every segment hangs off the one before it and bends a little.
		local energy = math.clamp(swim, 0.6, 1.5)
		for _, arm in rig.Arms do
			local f = body
			local prevPivot = nil
			for s = 0, arm.N - 1 do
				local g = G["arm" .. arm.Id .. "_" .. s]
				if g then
					local w = math.sin(phase * 0.7 - s * 0.9 + arm.Phase) * 0.22 * (0.5 + s * 0.35) * energy
					local rel = if prevPivot then prevPivot:Inverse() * g.Pivot else g.Pivot
					local bend = if arm.Hanging then CFrame.Angles(w, 0, w * 0.6) else CFrame.Angles(w * math.sin(arm.Phase), w * math.cos(arm.Phase), 0)
					f = f * rel * bend
					frames[g.Name] = f
					prevPivot = g.Pivot
				end
			end
		end
	end

	for name, g in G do
		local fr = frames[name] or body
		for i, p in g.Parts do
			table.insert(parts, p)
			table.insert(cframes, fr * g.Offsets[i])
		end
	end
end

-- Front and back points of the creature's hit capsule, and its radius.
function CreatureModels.Capsule(rig, root: CFrame): (Vector3, Vector3, number)
	return root * Vector3.new(0, 0, -rig.L / 2), root * Vector3.new(0, 0, rig.Back), rig.Radius
end

return CreatureModels
