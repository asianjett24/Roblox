-- Where every fish is at any moment, worked out the same way on the server and on every
-- client from a few numbers ("segments"), so fish never need to be streamed.
--
-- Each axis moves as A * (1 - cos(W * t)): the fish swims from P0 toward P0 + 2A and back.
-- The server starts a new segment from the fish's current spot every so often.
local FishPath = {}

-- Depth zones in the pond (studs). 1 stud = 2 m on the depth meter.
FishPath.Zones = {
	{ Name = "Shallows", Display = "Kelp Shallows", Min = Vector3.new(-110, -46, -110), Max = Vector3.new(110, -6, 110), Count = 14 },
	{ Name = "Reef", Display = "Coral Reef", Min = Vector3.new(-92, -144, -92), Max = Vector3.new(92, -56, 92), Count = 10 },
	{ Name = "Trench", Display = "Deep Trench", Min = Vector3.new(-72, -244, -72), Max = Vector3.new(72, -156, 72), Count = 7 },
	{ Name = "Abyss", Display = "The Abyss", Min = Vector3.new(-52, -294, -52), Max = Vector3.new(52, -258, 52), Count = 5 },
}
FishPath.ZoneByName = {}
for i, z in FishPath.Zones do
	z.Index = i
	FishPath.ZoneByName[z.Name] = z
end

-- Which zone a depth (world Y) is in, or nil above water.
function FishPath.ZoneAt(y: number)
	if y > -1 then
		return nil
	end
	if y > -50 then
		return FishPath.Zones[1]
	elseif y > -150 then
		return FishPath.Zones[2]
	elseif y > -250 then
		return FishPath.Zones[3]
	end
	return FishPath.Zones[4]
end

function FishPath.RandomPoint(rng: Random, zone, margin: number)
	local lo, hi = zone.Min, zone.Max
	local function pick(a, b)
		a += margin
		b -= margin
		if a >= b then
			return (a + b) / 2
		end
		return rng:NextNumber(a, b)
	end
	return Vector3.new(pick(lo.X, hi.X), pick(lo.Y, hi.Y), pick(lo.Z, hi.Z))
end

-- New segment starting at p0. awayFrom (optional) makes the fish swim away from that point.
function FishPath.NewSegment(rng: Random, zone, p0: Vector3, t0: number, speed: number, margin: number, awayFrom: Vector3?)
	local lo, hi = zone.Min, zone.Max
	local function axis(p, a, b, maxAmp, flee)
		a += margin
		b -= margin
		p = math.clamp(p, a, b)
		local up, down = b - p, p - a
		local sign
		if flee and flee ~= 0 then
			sign = flee
		else
			sign = if rng:NextNumber() * (up + down) < up then 1 else -1
		end
		local room = if sign > 0 then up else down
		if room < 2 then
			sign = -sign
			room = if sign > 0 then up else down
		end
		local amp = math.max(0, math.min(maxAmp, room / 2)) * rng:NextNumber(0.55, 1)
		return p, sign * amp
	end
	local fx, fy, fz = 0, 0, 0
	if awayFrom then
		local d = p0 - awayFrom
		fx = if d.X >= 0 then 1 else -1
		fz = if d.Z >= 0 then 1 else -1
	end
	local px, ax = axis(p0.X, lo.X, hi.X, 40, fx)
	local py, ay = axis(p0.Y, lo.Y, hi.Y, 6, fy)
	local pz, az = axis(p0.Z, lo.Z, hi.Z, 40, fz)
	local function freq(amp)
		return math.clamp(1.8 * speed / math.max(math.abs(amp) * 2, 4) * rng:NextNumber(0.8, 1.2), 0.04, 2.5)
	end
	return {
		T0 = t0,
		P0 = Vector3.new(px, py, pz),
		A = Vector3.new(ax, ay, az),
		W = Vector3.new(freq(ax), freq(ay) * 0.6, freq(az)),
	}
end

function FishPath.Position(seg, t: number): Vector3
	local tau = math.max(0, t - seg.T0)
	local A, W = seg.A, seg.W
	return seg.P0 + Vector3.new(A.X * (1 - math.cos(W.X * tau)), A.Y * (1 - math.cos(W.Y * tau)), A.Z * (1 - math.cos(W.Z * tau)))
end

function FishPath.Velocity(seg, t: number): Vector3
	local tau = math.max(0, t - seg.T0)
	local A, W = seg.A, seg.W
	return Vector3.new(A.X * W.X * math.sin(W.X * tau), A.Y * W.Y * math.sin(W.Y * tau), A.Z * W.Z * math.sin(W.Z * tau))
end

-- Shortest distance between segments p1-q1 and p2-q2, plus the fraction along p1-q1.
function FishPath.SegmentDistance(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3): (number, number)
	local d1, d2, r = q1 - p1, q2 - p2, p1 - p2
	local a, e, f = d1:Dot(d1), d2:Dot(d2), d2:Dot(r)
	local s, t
	if a <= 1e-9 and e <= 1e-9 then
		return r.Magnitude, 0
	end
	if a <= 1e-9 then
		s, t = 0, math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= 1e-9 then
			s, t = math.clamp(-c / a, 0, 1), 0
		else
			local b = d1:Dot(d2)
			local denom = a * e - b * b
			s = if denom > 1e-9 then math.clamp((b * f - c * e) / denom, 0, 1) else 0
			t = (b * s + f) / e
			if t < 0 then
				s, t = math.clamp(-c / a, 0, 1), 0
			elseif t > 1 then
				s, t = math.clamp((b - c) / a, 0, 1), 1
			end
		end
	end
	local c1, c2 = p1 + d1 * s, p2 + d2 * t
	return (c1 - c2).Magnitude, s
end

return FishPath
