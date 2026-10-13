local Services = script.Parent:WaitForChild("Services")

local order = { "AtlasService", "MapService", "DataService", "PlotService", "GearService", "ShopService", "StoreService", "DiverService", "ChaseService", "FishService" }
for _, name in order do
	local service = require(Services:WaitForChild(name))
	if service.Init then
		service.Init()
	end
end
