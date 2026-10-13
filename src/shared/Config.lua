-- Central tuning knobs. Change numbers here instead of digging through scripts.
local Config = {}

Config.DataStoreName = "SpearfishingCove_v1"

-- UI textures: upload assets/ui/ui_atlas.png to Roblox (see README) and put its number here,
-- e.g. Config.UIAtlasId = 123456789. Leave it at 0 to use the built-in drawn style.
Config.UIAtlasId = 78180036653855
Config.AutosaveInterval = 120

Config.StartingCoins = 0
Config.InventoryCap = 60

-- Spears
Config.SpearSpeed = 150 -- studs/second in air
Config.SpearSpeedWater = 140 -- studs/second underwater
Config.HitTolerance = 10 -- extra studs the server allows when checking a hit

-- Fish
Config.FishRespawn = 8 -- seconds before a caught fish is replaced
Config.FishRepath = { 10, 20 } -- seconds between a fish picking a new direction
Config.FleeTime = 6 -- seconds a hurt fish swims faster
Config.LairRadius = 40 -- rare fish (Rare and up) stay this close to their zone's guardian

-- The chase: spear a fish and you carry it; the zone's guardian wakes up and chases you.
-- Get out of the water to bank the catch. If the guardian bites you, you drop it.
Config.Chase = {
	ReturnSpeed = 0.6, -- guardian speed (fraction) when swimming home
	TurnRate = 3.5, -- how quickly guardians change direction
	Knockback = 60, -- how hard a bite throws you
}

-- Upgrades (bought in the Gear tab of the shop)
Config.Tank = {
	Name = "Air Tank",
	MaxLevel = 5,
	Air = { 30, 45, 65, 90, 125 }, -- seconds of air underwater
	Costs = { 750, 3000, 12000, 40000 }, -- cost to go from level N to N+1
}
Config.Fins = {
	Name = "Flippers",
	MaxLevel = 5,
	Speed = { 16, 19, 22, 25, 28 }, -- swim speed
	Costs = { 600, 2500, 10000, 35000 },
}
-- Escaping with a hunter this close (studs, beyond its bite range) pays a bonus on top.
Config.CloseCall = { Distance = 14, Bonus = 0.25 }
Config.Dash = { Multiplier = 1.7, Duration = 1.2, Cooldown = 6 } -- Shift underwater
Config.DrownDamage = 12 -- health per second once you're out of air
Config.AirRefill = 12 -- seconds of air regained per second at the surface

-- Tag a part "Merchant" for a Sell prompt, "GearShop" for the shop, "PearlShop" for the Robux store.
Config.MerchantTag = "Merchant"
Config.GearShopTag = "GearShop"
Config.PearlShopTag = "PearlShop"
Config.SellAnywhere = true -- the Bag's "Sell All" works anywhere

-- Plots: Models tagged "Plot" (BuildMap does this).
Config.PlotTag = "Plot"
Config.PlotFolderName = "Plots"
Config.TankMaxFish = 12

-- Robux store. Put your real IDs in here once you create them on the Creator Dashboard;
-- items with Id = 0 show as "Coming soon".
Config.Store = {
	Passes = {
		{ Key = "VIP", Id = 0, Name = "VIP Diver", Price = 299, Blurb = "+25% coins from every sale and a VIP tag", Color = Color3.fromRGB(255, 196, 40) },
		{ Key = "DoubleCoins", Id = 0, Name = "2x Coins", Price = 399, Blurb = "Double coins from every sale, forever", Color = Color3.fromRGB(90, 210, 80) },
		{ Key = "TurboFins", Id = 0, Name = "Turbo Fins", Price = 249, Blurb = "+15% swim speed on top of your Flippers", Color = Color3.fromRGB(60, 170, 255) },
		{ Key = "BigBag", Id = 0, Name = "Huge Bag", Price = 199, Blurb = "Carry 150 fish instead of 60", Color = Color3.fromRGB(190, 100, 255) },
	},
	Products = {
		{ Key = "Coins1", Id = 0, Name = "Coin Pouch", Price = 49, Coins = 2500, Color = Color3.fromRGB(255, 196, 40) },
		{ Key = "Coins2", Id = 0, Name = "Coin Chest", Price = 199, Coins = 15000, Color = Color3.fromRGB(255, 140, 40) },
		{ Key = "Coins3", Id = 0, Name = "Treasure Hoard", Price = 799, Coins = 80000, Color = Color3.fromRGB(255, 90, 120) },
		{ Key = "Repellent", Id = 0, Name = "Shark Repellent", Price = 39, Charges = 3, Color = Color3.fromRGB(80, 220, 200),
			Blurb = "Guardians sleep through your next 3 catches" },
	},
}

return Config
