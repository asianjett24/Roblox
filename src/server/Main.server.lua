local Services = script.Parent:WaitForChild("Services")

local order = { "MapService", "DataService", "PlotService", "RodService", "ShopService", "FishingService" }
for _, name in order do
	local service = require(Services:WaitForChild(name))
	if service.Init then
		service.Init()
	end
end
