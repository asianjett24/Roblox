-- Every fish in the game.
--   Zone: depth zone it lives in (see FishPath.Zones)
--   Speed: cruising speed in studs/second
--   Look: how FishModels builds it (sizes are multiples of Length L)
local FishData = {}

local rgb = Color3.fromRGB

FishData.Rarities = {
	{ Name = "Common", Weight = 60, HP = 1, Color = rgb(196, 204, 214) },
	{ Name = "Uncommon", Weight = 25, HP = 1, Color = rgb(88, 214, 120) },
	{ Name = "Rare", Weight = 10, HP = 2, Color = rgb(72, 156, 255) },
	{ Name = "Epic", Weight = 4, HP = 3, Color = rgb(178, 98, 255) },
	{ Name = "Legendary", Weight = 0.9, HP = 4, Color = rgb(255, 188, 48) },
	{ Name = "Mythic", Weight = 0.1, HP = 6, Color = rgb(255, 74, 120) },
}

FishData.RarityIndex = {}
for i, r in FishData.Rarities do
	FishData.RarityIndex[r.Name] = i
end

-- Value is the price of an average-weight fish.
FishData.Fish = {
	-- Kelp Shallows
	{ Id = "Minnow", Rarity = "Common", Zone = "Shallows", MinKg = 0.1, MaxKg = 0.4, Value = 5, Speed = 9,
		Look = { L = 1.8, H = 0.28, W = 0.16, Body = rgb(168, 180, 192), Belly = rgb(228, 232, 238), Fin = rgb(150, 162, 175), Tail = "fork" } },
	{ Id = "Sardine", Rarity = "Common", Zone = "Shallows", MinKg = 0.2, MaxKg = 0.6, Value = 7, Speed = 10,
		Look = { L = 2.1, H = 0.26, W = 0.16, Body = rgb(64, 108, 170), Belly = rgb(222, 228, 238), Fin = rgb(118, 150, 196), Tail = "fork",
			Spots = { 5, rgb(30, 50, 90) } } },
	{ Id = "Bluegill", Rarity = "Common", Zone = "Shallows", MinKg = 0.2, MaxKg = 0.8, Value = 8, Speed = 7,
		Look = { L = 2.3, H = 0.5, W = 0.18, Body = rgb(74, 112, 96), Belly = rgb(242, 152, 64), Fin = rgb(56, 90, 82), Tail = "round",
			Stripes = { 4, rgb(52, 80, 70) } } },
	{ Id = "Perch", Rarity = "Uncommon", Zone = "Shallows", MinKg = 0.4, MaxKg = 1.5, Value = 18, Speed = 8,
		Look = { L = 2.8, H = 0.32, W = 0.18, Body = rgb(156, 176, 64), Belly = rgb(236, 226, 172), Fin = rgb(232, 120, 50), Tail = "fork",
			Stripes = { 5, rgb(52, 74, 32) } } },
	{ Id = "Koi", Rarity = "Uncommon", Zone = "Shallows", MinKg = 0.8, MaxKg = 3, Value = 25, Speed = 5,
		Look = { L = 3.2, H = 0.3, W = 0.2, Body = rgb(246, 244, 238), Belly = rgb(252, 250, 246), Fin = rgb(250, 246, 240), Tail = "round",
			Spots = { 6, rgb(240, 108, 40) }, Whiskers = true } },
	{ Id = "Pufferfish", Rarity = "Rare", Zone = "Shallows", MinKg = 0.5, MaxKg = 2, Value = 70, Speed = 3,
		Look = { Shape = "round", L = 2, H = 0.78, W = 0.78, Body = rgb(232, 202, 112), Belly = rgb(250, 242, 212), Fin = rgb(204, 170, 90), Tail = "round",
			Spots = { 8, rgb(122, 92, 52) }, Spikes = true } },
	-- Coral Reef
	{ Id = "Mackerel", Rarity = "Uncommon", Zone = "Reef", MinKg = 0.5, MaxKg = 2, Value = 22, Speed = 11,
		Look = { L = 3.2, H = 0.24, W = 0.17, Body = rgb(48, 122, 142), Belly = rgb(230, 236, 242), Fin = rgb(60, 92, 112), Tail = "fork",
			Stripes = { 7, rgb(20, 52, 70) } } },
	{ Id = "Salmon", Rarity = "Rare", Zone = "Reef", MinKg = 2, MaxKg = 8, Value = 60, Speed = 9,
		Look = { L = 4.5, H = 0.27, W = 0.18, Body = rgb(150, 160, 178), Belly = rgb(242, 172, 160), Fin = rgb(120, 122, 136), Tail = "fork",
			Spots = { 7, rgb(58, 60, 72) } } },
	{ Id = "Catfish", Rarity = "Rare", Zone = "Reef", MinKg = 2, MaxKg = 12, Value = 65, Speed = 5,
		Look = { L = 5, H = 0.24, W = 0.26, Body = rgb(88, 82, 72), Belly = rgb(202, 192, 170), Fin = rgb(70, 66, 56), Tail = "round",
			Whiskers = true } },
	{ Id = "Golden Koi", Rarity = "Epic", Zone = "Reef", MinKg = 1, MaxKg = 4, Value = 250, Speed = 6,
		Look = { L = 3.6, H = 0.3, W = 0.2, Body = rgb(255, 196, 60), Belly = rgb(255, 228, 140), Fin = rgb(255, 226, 120), Tail = "round",
			Spots = { 5, rgb(255, 252, 240) }, Whiskers = true, Shiny = true } },
	-- Deep Trench
	{ Id = "Swordfish", Rarity = "Epic", Zone = "Trench", MinKg = 30, MaxKg = 120, Value = 220, Speed = 14,
		Look = { L = 9, H = 0.2, W = 0.13, Body = rgb(40, 62, 112), Belly = rgb(212, 218, 228), Fin = rgb(30, 46, 92), Tail = "crescent",
			Bill = true, TallFin = true } },
	{ Id = "Anglerfish", Rarity = "Epic", Zone = "Trench", MinKg = 3, MaxKg = 20, Value = 200, Speed = 4,
		Look = { L = 4, H = 0.46, W = 0.42, Body = rgb(62, 46, 42), Belly = rgb(92, 72, 62), Fin = rgb(46, 36, 32), Tail = "round",
			Lure = true, Mouth = true } },
	{ Id = "Castle Carp", Rarity = "Legendary", Zone = "Trench", MinKg = 10, MaxKg = 40, Value = 900, Speed = 6,
		Look = { L = 6, H = 0.36, W = 0.22, Body = rgb(172, 122, 62), Belly = rgb(222, 192, 132), Fin = rgb(142, 92, 50), Tail = "round",
			Spots = { 9, rgb(128, 88, 40) }, Crown = true, Whiskers = true } },
	-- The Abyss
	{ Id = "Great White", Rarity = "Legendary", Zone = "Abyss", MinKg = 300, MaxKg = 1100, Value = 1100, Speed = 12,
		Look = { L = 14, H = 0.24, W = 0.22, Body = rgb(118, 128, 140), Belly = rgb(236, 236, 236), Fin = rgb(108, 118, 130), Tail = "crescent",
			TallFin = true, Mouth = true } },
	{ Id = "Moon Eel", Rarity = "Mythic", Zone = "Abyss", MinKg = 5, MaxKg = 25, Value = 5000, Speed = 7,
		Look = { Shape = "eel", L = 10, H = 0.09, W = 0.08, Body = rgb(150, 190, 232), Belly = rgb(222, 236, 250), Fin = rgb(172, 212, 255), Tail = "round",
			Spots = { 8, rgb(210, 245, 255) }, Glow = true } },
	{ Id = "Royal Leviathan", Rarity = "Mythic", Zone = "Abyss", MinKg = 200, MaxKg = 900, Value = 6500, Speed = 9,
		Look = { Shape = "eel", L = 22, H = 0.1, W = 0.09, Body = rgb(92, 42, 142), Belly = rgb(232, 192, 82), Fin = rgb(242, 202, 72), Tail = "crescent",
			Horns = true, Spines = true, Glow = true } },
}

FishData.ById = {}
for _, fish in FishData.Fish do
	FishData.ById[fish.Id] = fish
end

function FishData.GetRarity(fishId: string)
	local fish = FishData.ById[fishId]
	return fish and FishData.Rarities[FishData.RarityIndex[fish.Rarity]]
end

function FishData.GetValue(fishId: string, kg: number): number
	local fish = FishData.ById[fishId]
	if not fish then
		return 0
	end
	local avg = (fish.MinKg + fish.MaxKg) / 2
	return math.max(1, math.floor(fish.Value * (kg / avg) + 0.5))
end

-- How big to draw a fish of this weight (1 = average).
function FishData.SizeScale(fishId: string, kg: number): number
	local fish = FishData.ById[fishId]
	if not fish then
		return 1
	end
	local avg = (fish.MinKg + fish.MaxKg) / 2
	return math.clamp((kg / avg) ^ (1 / 3), 0.75, 1.3)
end

-- Picks a species for a zone by rarity weight and rolls its weight in kg.
function FishData.RollForZone(zoneName: string, rng: Random)
	local pool, total = {}, 0
	for _, fish in FishData.Fish do
		if fish.Zone == zoneName then
			local w = FishData.Rarities[FishData.RarityIndex[fish.Rarity]].Weight
			total += w
			table.insert(pool, { fish = fish, w = w })
		end
	end
	local pick = rng:NextNumber() * total
	local chosen = pool[#pool].fish
	for _, entry in pool do
		pick -= entry.w
		if pick <= 0 then
			chosen = entry.fish
			break
		end
	end
	-- Lighter fish are more common so heavy ones feel special.
	local kg = chosen.MinKg + (chosen.MaxKg - chosen.MinKg) * rng:NextNumber() ^ 2
	return chosen, math.floor(kg * 100 + 0.5) / 100
end

return FishData
