-- Central tuning knobs. Change numbers here instead of digging through scripts.
local Config = {}

Config.DataStoreName = "CastleSpearfishing_v1"
Config.AutosaveInterval = 120

Config.StartingCoins = 0
Config.InventoryCap = 60

-- Spears
Config.SpearSpeed = 140 -- studs/second in air
Config.SpearSpeedWater = 100 -- studs/second underwater
Config.HitTolerance = 10 -- extra studs the server allows when checking a hit

-- Fish
Config.FishRespawn = 8 -- seconds before a caught fish is replaced
Config.FishRepath = { 10, 20 } -- seconds between a fish picking a new direction
Config.FleeTime = 6 -- seconds a hurt fish swims faster

-- The pond (water surface height and how far it reaches from the centre)
Config.WaterLevel = -1
Config.PondHalf = 120

-- Air tank upgrades (seconds of air underwater per level)
Config.Tank = {
	MaxLevel = 5,
	Air = { 25, 40, 60, 85, 120 },
	Costs = { 750, 3000, 12000, 40000 }, -- cost to go from level N to N+1
}
Config.DrownDamage = 12 -- health per second once you're out of air
Config.AirRefill = 10 -- seconds of air regained per second at the surface

-- Tag a part "Merchant" for a Sell prompt, "GearShop" for a Browse Spearguns prompt.
Config.MerchantTag = "Merchant"
Config.GearShopTag = "GearShop"
Config.SellAnywhere = true -- the Bag's "Sell All" works anywhere

-- Plots: Models tagged "Plot" (BuildMap does this). "Spawn" = where the owner spawns,
-- "TankWater" = where their catch is shown swimming.
Config.PlotTag = "Plot"
Config.PlotFolderName = "Plots"
Config.TankMaxFish = 6

return Config
