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
Config.WaterNames = { "WaterTri", "Water", "Hole", "Pond" }

-- Plots: Models tagged "Plot", or the children of workspace.Plots
Config.PlotTag = "Plot"
Config.PlotFolderName = "Plots"

-- Optional merchant: tag any part "Merchant" to give it Sell / Shop prompts.
Config.MerchantTag = "Merchant"
Config.SellAnywhere = true -- the Bag's "Sell All" works anywhere

-- Private pond upgrades (the hole on each plot)
Config.Pond = {
	MaxLevel = 5,
	Costs = { 750, 3000, 12000, 40000 }, -- cost to go from level N to N+1
	LuckPerLevel = 0.12,
	BiteSpeedPerLevel = 0.1,
}

return Config
