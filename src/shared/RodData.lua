-- Rods in shop order. Luck boosts rarity, BiteSpeed shortens waits,
-- Control widens the reel bar, Range is max cast distance in studs.
local RodData = {}

RodData.List = {
	{ Id = "Basic", Name = "Basic Rod", Price = 0, Luck = 1, BiteSpeed = 1, Control = 1, Range = 45, Color = Color3.fromRGB(120, 80, 40) },
	{ Id = "Sturdy", Name = "Sturdy Rod", Price = 400, Luck = 1.1, BiteSpeed = 1.15, Control = 1.1, Range = 55, Color = Color3.fromRGB(90, 90, 95) },
	{ Id = "Carbon", Name = "Carbon Rod", Price = 2000, Luck = 1.2, BiteSpeed = 1.3, Control = 1.25, Range = 65, Color = Color3.fromRGB(30, 30, 35) },
	{ Id = "Coral", Name = "Coral Rod", Price = 8000, Luck = 1.35, BiteSpeed = 1.45, Control = 1.35, Range = 75, Color = Color3.fromRGB(255, 120, 110) },
	{ Id = "Golden", Name = "Golden Rod", Price = 30000, Luck = 1.55, BiteSpeed = 1.65, Control = 1.5, Range = 85, Color = Color3.fromRGB(255, 200, 50) },
	{ Id = "Royal", Name = "Royal Trident Rod", Price = 120000, Luck = 1.8, BiteSpeed = 2, Control = 1.7, Range = 100, Color = Color3.fromRGB(150, 80, 255) },
}

RodData.ById = {}
for i, rod in ipairs(RodData.List) do
	rod.Order = i
	RodData.ById[rod.Id] = rod
end

return RodData
