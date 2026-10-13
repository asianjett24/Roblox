-- The dive zones: a stepped pit, each zone wider at the top than the next.
-- Each zone has its own fog colour and a Guardian sleeping in a lair on the zone's floor
-- (a rocky shelf where the next zone begins). Spear a fish and the guardian of that zone
-- wakes up and chases you until you get out of the water.
local Zones = {}

local rgb = Color3.fromRGB

Zones.WaterLevel = -1
Zones.MetersPerStud = 2

Zones.List = {
	{
		Name = "Shallows", Display = "Sunlit Shallows", Top = -1, Bottom = -70, Half = 180, Count = 18,
		Fog = rgb(70, 185, 225), FogDeep = rgb(40, 140, 200), Floor = rgb(226, 206, 150), Wall = rgb(150, 132, 104),
		LairCorner = Vector2.new(1, 1),
		Guardian = { Name = "Reef Shark", Kind = "shark", L = 18, Speed = 17.5, Wake = 2, Bite = 8, Damage = 35,
			Body = rgb(120, 135, 150), Belly = rgb(235, 238, 240), Fin = rgb(100, 115, 130) },
	},
	{
		Name = "Reef", Display = "Coral Reef", Top = -70, Bottom = -170, Half = 155, Count = 16,
		Fog = rgb(40, 150, 200), FogDeep = rgb(30, 110, 175), Floor = rgb(200, 170, 130), Wall = rgb(120, 104, 96),
		LairCorner = Vector2.new(-1, 1),
		Guardian = { Name = "Giant Moray", Kind = "eel", L = 34, Speed = 20, Wake = 1.8, Bite = 8, Damage = 45,
			Body = rgb(70, 110, 50), Belly = rgb(190, 200, 90), Fin = rgb(60, 95, 45), Accent = rgb(230, 220, 120) },
	},
	{
		Name = "Trench", Display = "Twilight Trench", Top = -170, Bottom = -280, Half = 130, Count = 13,
		Fog = rgb(30, 80, 150), FogDeep = rgb(20, 50, 115), Floor = rgb(90, 96, 120), Wall = rgb(70, 74, 96),
		LairCorner = Vector2.new(-1, -1),
		Guardian = { Name = "Great Hammerhead", Kind = "hammer", L = 28, Speed = 23.5, Wake = 1.6, Bite = 10, Damage = 55,
			Body = rgb(95, 110, 125), Belly = rgb(225, 228, 232), Fin = rgb(80, 95, 110) },
	},
	{
		Name = "Abyss", Display = "The Abyss", Top = -280, Bottom = -400, Half = 105, Count = 10,
		Fog = rgb(18, 34, 80), FogDeep = rgb(10, 18, 50), Floor = rgb(52, 56, 78), Wall = rgb(40, 42, 62),
		LairCorner = Vector2.new(1, -1),
		Guardian = { Name = "The Kraken", Kind = "kraken", L = 36, Speed = 27.5, Wake = 1.3, Bite = 12, Damage = 70,
			Body = rgb(170, 40, 50), Belly = rgb(230, 140, 120), Fin = rgb(140, 30, 40), Accent = rgb(255, 210, 120) },
	},
	{
		Name = "Rift", Display = "Leviathan's Rift", Top = -400, Bottom = -520, Half = 80, Count = 8,
		Fog = rgb(40, 14, 70), FogDeep = rgb(22, 6, 42), Floor = rgb(48, 30, 70), Wall = rgb(38, 24, 56),
		LairCorner = Vector2.new(0, 0),
		Guardian = { Name = "Ancient Leviathan", Kind = "serpent", L = 64, Speed = 29.5, Wake = 1.3, Bite = 14, Damage = 100,
			Body = rgb(70, 30, 120), Belly = rgb(235, 190, 80), Fin = rgb(245, 200, 70), Accent = rgb(140, 255, 230) },
	},
}

Zones.ByName = {}
for i, z in Zones.List do
	z.Index = i
	Zones.ByName[z.Name] = z
	-- Where fish swim (a box inside the zone, away from the walls, floor and surface)
	z.Min = Vector3.new(-z.Half + 8, z.Bottom + 6, -z.Half + 8)
	z.Max = Vector3.new(z.Half - 8, z.Top - 5, z.Half - 8)
	-- The guardian's lair sits on this zone's floor: the shelf between this zone's wall and the next one's.
	local nextHalf = if Zones.List[i + 1] then Zones.List[i + 1].Half else 0
	if z.LairCorner.Magnitude > 0 then
		local d = (z.Half + nextHalf) / 2
		z.Lair = Vector3.new(z.LairCorner.X * d, z.Bottom + 6, z.LairCorner.Y * d)
	else
		z.Lair = Vector3.new(0, z.Bottom + 10, 0)
	end
	z.ShelfInner = nextHalf
end

-- The zone a world height is in (nil above the water).
function Zones.At(y: number)
	if y > Zones.WaterLevel then
		return nil
	end
	for _, z in Zones.List do
		if y > z.Bottom then
			return z
		end
	end
	return Zones.List[#Zones.List]
end

-- True if a point is inside the water of the pit.
function Zones.InWater(p: Vector3): boolean
	local z = Zones.At(p.Y)
	if not z then
		return false
	end
	return math.abs(p.X) < z.Half and math.abs(p.Z) < z.Half
end

function Zones.Depth(y: number): number
	return math.max(0, (Zones.WaterLevel - y) * Zones.MetersPerStud)
end

return Zones
