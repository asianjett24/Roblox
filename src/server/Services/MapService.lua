-- Rebuilds the map when you press Play if it's missing or older than BuildMap's version.
-- (Run require(game.ServerStorage.BuildMap)() in the Command Bar to update it in edit mode too.)
local ServerStorage = game:GetService("ServerStorage")

local MapService = {}

function MapService.Init()
	local module = ServerStorage:FindFirstChild("BuildMap")
	if not module or not module:IsA("ModuleScript") then
		return
	end
	local BuildMap = require(module)
	if type(BuildMap) ~= "table" or not BuildMap.Version then
		return
	end
	local map = workspace:FindFirstChild("Map")
	local current = map and map:GetAttribute("Version")
	if current ~= BuildMap.Version then
		warn(string.format("[MapService] Map is out of date (v%s, latest v%d). Rebuilding it for this play session.", tostring(current or "none"), BuildMap.Version))
		BuildMap()
	end
end

return MapService
