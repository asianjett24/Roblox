-- Everything you can catch, plus size classes and mutations.
--   Zone: which dive zone it lives in (see Zones)
--   Speed: cruising speed in studs/second
--   Look: how CreatureModels builds it. L = length in studs at Normal size;
--         H / W = height / width as a fraction of L.
local FishData = {}

local rgb = Color3.fromRGB

FishData.Rarities = {
	{ Name = "Common", Weight = 60, HP = 1, Color = rgb(170, 184, 204) },
	{ Name = "Uncommon", Weight = 25, HP = 1, Color = rgb(96, 214, 96) },
	{ Name = "Rare", Weight = 10, HP = 2, Color = rgb(64, 156, 255) },
	{ Name = "Epic", Weight = 4, HP = 3, Color = rgb(176, 88, 255) },
	{ Name = "Legendary", Weight = 0.9, HP = 4, Color = rgb(255, 176, 32) },
	{ Name = "Mythic", Weight = 0.15, HP = 6, Color = rgb(255, 64, 120) },
}
FishData.RarityIndex = {}
for i, r in FishData.Rarities do
	FishData.RarityIndex[r.Name] = i
end

-- Size classes rolled for every creature. Scale = model size, Kg = weight multiplier.
FishData.Sizes = {
	{ Name = "Tiny", Chance = 18, Scale = 0.65, Kg = 0.35, Value = 0.6 },
	{ Name = "Normal", Chance = 56, Scale = 1, Kg = 1, Value = 1 },
	{ Name = "Large", Chance = 18, Scale = 1.35, Kg = 2.2, Value = 1.8 },
	{ Name = "Giant", Chance = 6.5, Scale = 1.8, Kg = 5, Value = 3.5 },
	{ Name = "Colossal", Chance = 1.5, Scale = 2.5, Kg = 12, Value = 8 },
}
FishData.SizeByName = {}
for i, s in FishData.Sizes do
	s.Index = i
	FishData.SizeByName[s.Name] = s
end

-- Mutations change a creature's colours and multiply its value.
FishData.Mutations = {
	{ Name = "Golden", Chance = 2.5, Value = 3, Color = rgb(255, 200, 50), Material = "Metal" },
	{ Name = "Albino", Chance = 2, Value = 2, Color = rgb(245, 245, 250) },
	{ Name = "Shadow", Chance = 1.2, Value = 2.5, Color = rgb(40, 30, 60), Glow = rgb(170, 90, 255) },
	{ Name = "Neon", Chance = 0.6, Value = 4, Color = rgb(60, 255, 220), Material = "Neon" },
	{ Name = "Rainbow", Chance = 0.15, Value = 6, Rainbow = true },
}
FishData.MutationByName = {}
for _, m in FishData.Mutations do
	FishData.MutationByName[m.Name] = m
end

local function fish(id, rarity, zone, minKg, maxKg, value, speed, look, blurb)
	return { Id = id, Rarity = rarity, Zone = zone, MinKg = minKg, MaxKg = maxKg, Value = value, Speed = speed, Look = look, Blurb = blurb }
end

FishData.Fish = {
	-- Sunlit Shallows ----------------------------------------------------------------
	fish("Sardine", "Common", "Shallows", 0.1, 0.4, 6, 10,
		{ Shape = "fish", L = 2.2, H = 0.24, W = 0.14, Body = rgb(70, 120, 180), Belly = rgb(225, 232, 240), Fin = rgb(140, 170, 205), Tail = "fork", Dorsal = "low" },
		"Travels in huge glittering schools."),
	fish("Clownfish", "Common", "Shallows", 0.1, 0.3, 7, 6,
		{ Shape = "fish", L = 2, H = 0.42, W = 0.2, Body = rgb(255, 120, 30), Belly = rgb(255, 150, 60), Fin = rgb(255, 255, 255), Accent = rgb(255, 255, 255), Pattern = "bands", Tail = "round", Dorsal = "low" },
		"Never far from its anemone."),
	fish("Blue Tang", "Common", "Shallows", 0.2, 0.6, 8, 8,
		{ Shape = "fish", L = 2.6, H = 0.55, W = 0.16, Body = rgb(40, 90, 230), Belly = rgb(70, 130, 245), Fin = rgb(255, 210, 40), Accent = rgb(20, 30, 70), Pattern = "stripes", Tail = "fork", Dorsal = "low" },
		"Bright blue with a yellow tail."),
	fish("Butterflyfish", "Uncommon", "Shallows", 0.2, 0.7, 16, 6,
		{ Shape = "fish", L = 2.6, H = 0.7, W = 0.12, Body = rgb(255, 225, 60), Belly = rgb(255, 245, 190), Fin = rgb(255, 200, 40), Accent = rgb(30, 30, 40), Pattern = "bands", Tail = "round", Dorsal = "low" },
		"Flat as a coin and twice as shiny."),
	fish("Pufferfish", "Uncommon", "Shallows", 0.5, 2, 20, 3,
		{ Shape = "round", L = 2.4, H = 0.8, W = 0.8, Body = rgb(230, 200, 110), Belly = rgb(250, 242, 212), Fin = rgb(205, 170, 90), Accent = rgb(120, 90, 50), Pattern = "spots", Tail = "round", Spikes = true },
		"Puffs up when it is scared. Try not to scare it."),
	fish("Barracuda", "Rare", "Shallows", 4, 14, 55, 14,
		{ Shape = "fish", L = 6.5, H = 0.16, W = 0.11, Body = rgb(110, 125, 140), Belly = rgb(225, 230, 235), Fin = rgb(90, 100, 115), Accent = rgb(60, 70, 85), Pattern = "stripes", Tail = "fork", Dorsal = "low", Teeth = true },
		"A silver torpedo full of teeth."),
	fish("Sea Turtle", "Rare", "Shallows", 30, 120, 70, 4,
		{ Shape = "turtle", L = 6, H = 0.3, W = 0.65, Body = rgb(90, 130, 70), Belly = rgb(220, 200, 140), Fin = rgb(150, 170, 110), Accent = rgb(130, 100, 60) },
		"Older than your grandparents."),
	fish("Mahi-Mahi", "Epic", "Shallows", 8, 25, 200, 13,
		{ Shape = "fish", L = 7, H = 0.3, W = 0.13, Body = rgb(40, 170, 120), Belly = rgb(250, 220, 60), Fin = rgb(40, 120, 200), Tail = "fork", Dorsal = "sail" },
		"Glows green and gold in the sunlight."),

	-- Coral Reef ----------------------------------------------------------------------
	fish("Parrotfish", "Common", "Reef", 1, 4, 18, 7,
		{ Shape = "fish", L = 3.6, H = 0.38, W = 0.2, Body = rgb(60, 200, 170), Belly = rgb(250, 140, 190), Fin = rgb(250, 120, 170), Accent = rgb(255, 230, 90), Pattern = "spots", Tail = "round", Dorsal = "low" },
		"Crunches coral and poops out sand."),
	fish("Lionfish", "Uncommon", "Reef", 0.5, 1.5, 34, 4,
		{ Shape = "fish", L = 3, H = 0.4, W = 0.18, Body = rgb(220, 90, 70), Belly = rgb(250, 220, 200), Fin = rgb(250, 160, 130), Accent = rgb(255, 245, 235), Pattern = "bands", Tail = "round", Dorsal = "spiny" },
		"Beautiful, venomous, everywhere."),
	fish("Stingray", "Uncommon", "Reef", 5, 30, 40, 5,
		{ Shape = "flat", L = 5, H = 0.1, W = 0.9, Body = rgb(140, 120, 100), Belly = rgb(235, 225, 210), Fin = rgb(120, 100, 85), Accent = rgb(90, 75, 60), Pattern = "spots" },
		"Glides like a flying carpet."),
	fish("Octopus", "Rare", "Reef", 3, 15, 85, 5,
		{ Shape = "squid", L = 4, H = 0.4, W = 0.4, Body = rgb(230, 110, 70), Belly = rgb(255, 170, 130), Fin = rgb(200, 90, 60), Accent = rgb(255, 230, 200), Arms = 8 },
		"Eight arms, three hearts, zero patience."),
	fish("Grouper", "Rare", "Reef", 20, 80, 95, 5,
		{ Shape = "fish", L = 7, H = 0.36, W = 0.26, Body = rgb(130, 110, 80), Belly = rgb(220, 200, 160), Fin = rgb(110, 90, 65), Accent = rgb(80, 65, 45), Pattern = "spots", Tail = "round", Dorsal = "spiny" },
		"Has a mouth big enough to swallow a diver's flipper."),
	fish("Blacktip Shark", "Epic", "Reef", 20, 60, 260, 13,
		{ Shape = "shark", L = 9, H = 0.2, W = 0.18, Body = rgb(120, 125, 135), Belly = rgb(235, 235, 235), Fin = rgb(30, 30, 35), Tail = "crescent", Dorsal = "tall" },
		"Every fin dipped in ink."),
	fish("Manta Ray", "Legendary", "Reef", 300, 1200, 900, 6,
		{ Shape = "flat", L = 10, H = 0.08, W = 1.6, Body = rgb(40, 50, 70), Belly = rgb(240, 240, 245), Fin = rgb(35, 45, 60), Accent = rgb(230, 230, 235), Pattern = "spots", Horns = true },
		"The gentle giant of the reef."),

	-- Twilight Trench -------------------------------------------------------------------
	fish("Lanternfish", "Common", "Trench", 0.05, 0.2, 30, 9,
		{ Shape = "fish", L = 2, H = 0.26, W = 0.16, Body = rgb(60, 70, 110), Belly = rgb(140, 150, 190), Fin = rgb(90, 100, 140), Accent = rgb(120, 220, 255), Pattern = "spots", Tail = "fork", Dorsal = "low", Glow = true },
		"Little lights in the dark."),
	fish("Hatchetfish", "Uncommon", "Trench", 0.05, 0.2, 45, 6,
		{ Shape = "fish", L = 1.8, H = 0.8, W = 0.12, Body = rgb(180, 190, 210), Belly = rgb(230, 235, 245), Fin = rgb(160, 170, 190), Tail = "fork", Dorsal = "low", Glow = true, Shiny = true },
		"Shaped like a tiny silver axe."),
	fish("Moon Jelly", "Uncommon", "Trench", 0.5, 3, 50, 2,
		{ Shape = "jelly", L = 3.5, H = 0.6, W = 1, Body = rgb(170, 200, 255), Belly = rgb(220, 235, 255), Fin = rgb(200, 220, 255), Accent = rgb(240, 160, 255), Glow = true },
		"Drifts wherever the current goes."),
	fish("Swordfish", "Rare", "Trench", 40, 150, 160, 15,
		{ Shape = "fish", L = 10, H = 0.2, W = 0.13, Body = rgb(40, 62, 112), Belly = rgb(212, 218, 228), Fin = rgb(30, 46, 92), Tail = "crescent", Dorsal = "tall", Bill = true },
		"The fastest blade in the sea."),
	fish("Coelacanth", "Epic", "Trench", 30, 90, 420, 4,
		{ Shape = "fish", L = 7, H = 0.3, W = 0.22, Body = rgb(40, 70, 110), Belly = rgb(80, 110, 150), Fin = rgb(60, 90, 130), Accent = rgb(230, 240, 255), Pattern = "spots", Tail = "fan", Dorsal = "low" },
		"A living fossil, 400 million years old."),
	fish("Giant Squid", "Legendary", "Trench", 100, 300, 1100, 7,
		{ Shape = "squid", L = 12, H = 0.22, W = 0.22, Body = rgb(200, 80, 80), Belly = rgb(240, 160, 150), Fin = rgb(180, 60, 60), Accent = rgb(255, 220, 200), Arms = 8, LongArms = true },
		"Eyes the size of dinner plates."),

	-- The Abyss ---------------------------------------------------------------------------
	fish("Anglerfish", "Common", "Abyss", 3, 20, 90, 4,
		{ Shape = "fish", L = 4, H = 0.5, W = 0.45, Body = rgb(62, 46, 42), Belly = rgb(92, 72, 62), Fin = rgb(46, 36, 32), Tail = "round", Dorsal = "none", Lure = true, Teeth = true },
		"Its light is the last thing many fish see."),
	fish("Gulper Eel", "Uncommon", "Abyss", 1, 5, 130, 6,
		{ Shape = "eel", L = 7, H = 0.08, W = 0.07, Body = rgb(30, 30, 40), Belly = rgb(60, 55, 70), Fin = rgb(255, 80, 120), Tail = "point", Glow = true, BigMouth = true },
		"All mouth, very little fish."),
	fish("Vampire Squid", "Rare", "Abyss", 0.5, 4, 260, 4,
		{ Shape = "squid", L = 3.5, H = 0.4, W = 0.4, Body = rgb(130, 20, 40), Belly = rgb(170, 40, 60), Fin = rgb(100, 10, 30), Accent = rgb(80, 220, 255), Arms = 8, Glow = true },
		"Not a vampire. Not quite a squid."),
	fish("Goblin Shark", "Epic", "Abyss", 100, 210, 700, 9,
		{ Shape = "shark", L = 11, H = 0.18, W = 0.16, Body = rgb(220, 160, 170), Belly = rgb(245, 210, 215), Fin = rgb(200, 140, 150), Tail = "fork", Dorsal = "low", Bill = true, Teeth = true },
		"A pink nightmare with a slingshot jaw."),
	fish("Colossal Squid", "Legendary", "Abyss", 300, 700, 2400, 6,
		{ Shape = "squid", L = 16, H = 0.24, W = 0.24, Body = rgb(150, 30, 50), Belly = rgb(220, 120, 120), Fin = rgb(120, 20, 40), Accent = rgb(255, 200, 120), Arms = 8, LongArms = true, Glow = true },
		"Even bigger than the giant one."),
	fish("Ghost Shark", "Mythic", "Abyss", 50, 150, 6000, 8,
		{ Shape = "shark", L = 9, H = 0.22, W = 0.18, Body = rgb(200, 230, 255), Belly = rgb(240, 250, 255), Fin = rgb(170, 210, 255), Tail = "crescent", Dorsal = "tall", Glow = true, Ghost = true },
		"Some divers swear they swam straight through it."),

	-- Leviathan's Rift ----------------------------------------------------------------------
	fish("Dragonfish", "Rare", "Rift", 2, 10, 520, 10,
		{ Shape = "eel", L = 6, H = 0.12, W = 0.1, Body = rgb(40, 20, 60), Belly = rgb(80, 40, 100), Fin = rgb(255, 90, 200), Tail = "fork", Glow = true, Teeth = true, Lure = true },
		"A shadow with a glowing chin."),
	fish("Sea Dragon", "Epic", "Rift", 20, 80, 1500, 8,
		{ Shape = "eel", L = 10, H = 0.12, W = 0.1, Body = rgb(40, 150, 110), Belly = rgb(240, 210, 90), Fin = rgb(250, 200, 60), Tail = "fan", Horns = true, Spines = true },
		"Real dragons swim."),
	fish("Megalodon Pup", "Legendary", "Rift", 600, 2000, 5200, 12,
		{ Shape = "shark", L = 16, H = 0.24, W = 0.22, Body = rgb(70, 80, 95), Belly = rgb(225, 225, 225), Fin = rgb(60, 70, 85), Tail = "crescent", Dorsal = "tall", Teeth = true },
		"Just a baby. Do not meet its mother."),
	fish("Kraken Spawn", "Mythic", "Rift", 400, 1500, 14000, 6,
		{ Shape = "squid", L = 14, H = 0.3, W = 0.3, Body = rgb(110, 30, 140), Belly = rgb(200, 100, 200), Fin = rgb(90, 20, 120), Accent = rgb(140, 255, 230), Arms = 8, LongArms = true, Glow = true },
		"Will grow up to sink ships."),
	fish("Leviathan Hatchling", "Mythic", "Rift", 800, 3000, 20000, 9,
		{ Shape = "eel", L = 22, H = 0.1, W = 0.09, Body = rgb(92, 42, 142), Belly = rgb(232, 192, 82), Fin = rgb(242, 202, 72), Tail = "crescent", Horns = true, Spines = true, Glow = true },
		"The Rift's next ruler."),
}

FishData.ById = {}
for i, f in FishData.Fish do
	f.Order = i
	FishData.ById[f.Id] = f
end

function FishData.GetRarity(fishId: string)
	local f = FishData.ById[fishId]
	return f and FishData.Rarities[FishData.RarityIndex[f.Rarity]]
end

-- Value of a caught creature: base value scaled by weight, size class and mutation.
function FishData.GetValue(fishId: string, kg: number, sizeName: string?, mutation: string?): number
	local f = FishData.ById[fishId]
	if not f then
		return 0
	end
	local size = FishData.SizeByName[sizeName or "Normal"] or FishData.SizeByName.Normal
	local avg = (f.MinKg + f.MaxKg) / 2 * size.Kg
	local value = f.Value * size.Value * math.sqrt(math.max(kg, 0.01) / math.max(avg, 0.01))
	local mut = mutation and FishData.MutationByName[mutation]
	if mut then
		value *= mut.Value
	end
	return math.max(1, math.floor(value + 0.5))
end

local function pickWeighted(list, field, rng)
	local total = 0
	for _, item in list do
		total += item[field]
	end
	local pick = rng:NextNumber() * total
	for _, item in list do
		pick -= item[field]
		if pick <= 0 then
			return item
		end
	end
	return list[#list]
end

-- Rolls a new creature for a zone: species, size class, mutation and weight.
function FishData.Roll(zoneName: string, rng: Random, luck: number?)
	luck = luck or 1
	local pool = {}
	for _, f in FishData.Fish do
		if f.Zone == zoneName then
			local tier = FishData.RarityIndex[f.Rarity]
			table.insert(pool, { Fish = f, W = FishData.Rarities[tier].Weight * luck ^ (tier - 1) })
		end
	end
	local f = pickWeighted(pool, "W", rng).Fish
	local size = pickWeighted(FishData.Sizes, "Chance", rng)
	local mutation = nil
	local roll = rng:NextNumber() * 100
	for _, m in FishData.Mutations do
		roll -= m.Chance * luck
		if roll <= 0 then
			mutation = m.Name
			break
		end
	end
	local kg = (f.MinKg + (f.MaxKg - f.MinKg) * rng:NextNumber() ^ 2) * size.Kg
	return f, size.Name, mutation, math.floor(kg * 100 + 0.5) / 100
end

-- Display name, e.g. "Giant Golden Barracuda"
function FishData.FullName(fishId: string, sizeName: string?, mutation: string?): string
	local parts = {}
	if sizeName and sizeName ~= "Normal" then
		table.insert(parts, sizeName)
	end
	if mutation then
		table.insert(parts, mutation)
	end
	table.insert(parts, fishId)
	return table.concat(parts, " ")
end

return FishData
