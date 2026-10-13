-- Spearguns in shop order.
--   Damage: hits taken off a fish (fish have 1-6 health by rarity)
--   Range: how far the spear flies (studs)
--   Reload: seconds between shots
local GunData = {}

GunData.List = {
	{
		Id = "Wooden", Name = "Driftwood Speargun", Price = 0, Damage = 1, Range = 45, Reload = 1.2,
		Body = Color3.fromRGB(150, 104, 62), BodyMaterial = Enum.Material.Wood,
		Trim = Color3.fromRGB(70, 70, 76), Band = Color3.fromRGB(220, 70, 60),
	},
	{
		Id = "Reef", Name = "Reef Runner", Price = 400, Damage = 1, Range = 55, Reload = 1.0,
		Body = Color3.fromRGB(40, 150, 160), BodyMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(230, 230, 235), Band = Color3.fromRGB(250, 200, 60),
	},
	{
		Id = "Carbon", Name = "Carbon Striker", Price = 2000, Damage = 2, Range = 65, Reload = 0.85,
		Body = Color3.fromRGB(38, 40, 46), BodyMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(120, 125, 135), Band = Color3.fromRGB(80, 220, 120),
	},
	{
		Id = "Coral", Name = "Coral Lancer", Price = 8000, Damage = 2, Range = 75, Reload = 0.75,
		Body = Color3.fromRGB(240, 120, 110), BodyMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(250, 240, 230), Band = Color3.fromRGB(70, 200, 230),
	},
	{
		Id = "Golden", Name = "Gilded Harpoon", Price = 30000, Damage = 3, Range = 85, Reload = 0.65,
		Body = Color3.fromRGB(240, 190, 70), BodyMaterial = Enum.Material.Metal,
		Trim = Color3.fromRGB(60, 50, 40), Band = Color3.fromRGB(40, 40, 44),
	},
	{
		Id = "Royal", Name = "Royal Trident", Price = 120000, Damage = 4, Range = 100, Reload = 0.5,
		Body = Color3.fromRGB(110, 60, 190), BodyMaterial = Enum.Material.SmoothPlastic,
		Trim = Color3.fromRGB(245, 200, 80), Band = Color3.fromRGB(245, 200, 80), Glow = true,
	},
}

GunData.ById = {}
for i, gun in GunData.List do
	gun.Order = i
	GunData.ById[gun.Id] = gun
end

return GunData
