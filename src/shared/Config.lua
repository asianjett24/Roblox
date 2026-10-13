-- Central tuning knobs. Change numbers here instead of digging through scripts.
local Config = {}

Config.DataStoreName = "CastleFishing_v1"
Config.AutosaveInterval = 120

Config.StartingCoins = 0
Config.InventoryCap = 60

-- Fishing timing (seconds)
Config.BiteDelayMin = 2.5
Config.BiteDelayMax = 7
Config.MinReelTime = 1.2 -- server rejects catches faster than this after a bite
Config.MaxReelTime = 45 -- a bite that isn't resolved by then is dropped

-- How water is recognised. Any of these counts:
--   * part tagged "FishingWater" (CollectionService / Tag editor)
--   * part whose Name is in WaterNames
--   * part with Material = Water, or Terrain water
Config.WaterTag = "FishingWater"
Config.WaterNames = { "WaterTri", "Water" }

-- Plots: Models tagged "Plot" (BuildMap.lua does this), or the children of workspace.Plots.
-- A part named "Dock" inside a plot is that player's private dock; "Spawn" is where they spawn;
-- "TankWater" is where their caught fish swim.
Config.PlotTag = "Plot"
Config.PlotFolderName = "Plots"

-- Tag a part "Merchant" for a Sell prompt, "RodShop" for a Browse Rods prompt.
Config.MerchantTag = "Merchant"
Config.RodShopTag = "RodShop"
Config.SellAnywhere = true -- the Bag's "Sell All" works anywhere

Config.TankMaxFish = 10 -- fish shown swimming in your base tank

-- Private dock upgrades (fishing from your own base's dock)
Config.Dock = {
	MaxLevel = 5,
	Costs = { 750, 3000, 12000, 40000 }, -- cost to go from level N to N+1
	LuckPerLevel = 0.12,
	BiteSpeedPerLevel = 0.1,
}

return Config
