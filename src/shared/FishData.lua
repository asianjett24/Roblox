-- Every fish in the game. Zone: "Open" (anywhere except your dock), "Dock" (your own base's dock) or "Any".
local FishData = {}

FishData.Rarities = {
	{ Name = "Common", Weight = 60, Color = Color3.fromRGB(200, 200, 200), Difficulty = 1 },
	{ Name = "Uncommon", Weight = 25, Color = Color3.fromRGB(90, 220, 110), Difficulty = 1.15 },
	{ Name = "Rare", Weight = 10, Color = Color3.fromRGB(70, 150, 255), Difficulty = 1.35 },
	{ Name = "Epic", Weight = 4, Color = Color3.fromRGB(180, 90, 255), Difficulty = 1.6 },
	{ Name = "Legendary", Weight = 0.9, Color = Color3.fromRGB(255, 190, 40), Difficulty = 1.9 },
	{ Name = "Mythic", Weight = 0.1, Color = Color3.fromRGB(255, 70, 110), Difficulty = 2.3 },
}

FishData.RarityIndex = {}
for i, r in ipairs(FishData.Rarities) do
	FishData.RarityIndex[r.Name] = i
end

-- Value is the price of an average-weight fish.
FishData.Fish = {
	{ Id = "Minnow", Icon = "🐟", Rarity = "Common", Zone = "Any", MinKg = 0.1, MaxKg = 0.4, Value = 5 },
	{ Id = "Sardine", Icon = "🐟", Rarity = "Common", Zone = "Open", MinKg = 0.2, MaxKg = 0.6, Value = 7 },
	{ Id = "Bluegill", Icon = "🐟", Rarity = "Common", Zone = "Dock", MinKg = 0.2, MaxKg = 0.8, Value = 8 },
	{ Id = "Perch", Icon = "🐟", Rarity = "Uncommon", Zone = "Any", MinKg = 0.4, MaxKg = 1.5, Value = 18 },
	{ Id = "Mackerel", Icon = "🐟", Rarity = "Uncommon", Zone = "Open", MinKg = 0.5, MaxKg = 2, Value = 22 },
	{ Id = "Koi", Icon = "🐠", Rarity = "Uncommon", Zone = "Dock", MinKg = 0.8, MaxKg = 3, Value = 25 },
	{ Id = "Salmon", Icon = "🐟", Rarity = "Rare", Zone = "Open", MinKg = 2, MaxKg = 8, Value = 60 },
	{ Id = "Catfish", Icon = "🐟", Rarity = "Rare", Zone = "Dock", MinKg = 2, MaxKg = 12, Value = 65 },
	{ Id = "Pufferfish", Icon = "🐡", Rarity = "Rare", Zone = "Any", MinKg = 0.5, MaxKg = 2, Value = 70 },
	{ Id = "Swordfish", Icon = "🐟", Rarity = "Epic", Zone = "Open", MinKg = 30, MaxKg = 120, Value = 220 },
	{ Id = "Golden Koi", Icon = "🐠", Rarity = "Epic", Zone = "Dock", MinKg = 1, MaxKg = 4, Value = 250 },
	{ Id = "Anglerfish", Icon = "🐡", Rarity = "Epic", Zone = "Any", MinKg = 3, MaxKg = 20, Value = 200 },
	{ Id = "Castle Carp", Icon = "🐠", Rarity = "Legendary", Zone = "Dock", MinKg = 10, MaxKg = 40, Value = 900 },
	{ Id = "Great White", Icon = "🦈", Rarity = "Legendary", Zone = "Open", MinKg = 300, MaxKg = 1100, Value = 1100 },
	{ Id = "Moon Eel", Icon = "🐍", Rarity = "Mythic", Zone = "Open", MinKg = 5, MaxKg = 25, Value = 5000 },
	{ Id = "Royal Leviathan", Icon = "🐉", Rarity = "Mythic", Zone = "Dock", MinKg = 200, MaxKg = 900, Value = 6500 },
}

FishData.ById = {}
for _, fish in ipairs(FishData.Fish) do
	FishData.ById[fish.Id] = fish
end

FishData.ZoneNames = { Any = "Anywhere", Open = "Open Water", Dock = "Your Dock" }

function FishData.GetValue(fishId: string, kg: number): number
	local fish = FishData.ById[fishId]
	if not fish then
		return 0
	end
	local avg = (fish.MinKg + fish.MaxKg) / 2
	return math.max(1, math.floor(fish.Value * (kg / avg) + 0.5))
end

function FishData.GetRarity(fishId: string)
	local fish = FishData.ById[fishId]
	return fish and FishData.Rarities[FishData.RarityIndex[fish.Rarity]]
end

-- Luck multiplies the weight of each tier above Common by luck^(tier-1).
function FishData.Roll(zone: string, luck: number, rng: Random)
	local pool = {}
	local total = 0
	for _, fish in ipairs(FishData.Fish) do
		if fish.Zone == "Any" or fish.Zone == zone then
			local tier = FishData.RarityIndex[fish.Rarity]
			local w = FishData.Rarities[tier].Weight * luck ^ (tier - 1)
			total += w
			table.insert(pool, { fish = fish, w = w })
		end
	end
	local pick = rng:NextNumber() * total
	local chosen = pool[#pool].fish
	for _, entry in ipairs(pool) do
		pick -= entry.w
		if pick <= 0 then
			chosen = entry.fish
			break
		end
	end
	-- Bias toward lighter fish so heavy ones feel special.
	local kg = chosen.MinKg + (chosen.MaxKg - chosen.MinKg) * rng:NextNumber() ^ 2
	return chosen, math.floor(kg * 100 + 0.5) / 100
end

return FishData
