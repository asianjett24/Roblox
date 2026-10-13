-- The UI texture sheet. Config.UIAtlasId may be a Decal ID (what the Creator Hub shows after
-- an upload) instead of the Image ID that ImageLabels need, which makes the image fail to load.
-- This looks the ID up: if it's a Decal, clients get its Image ID through an attribute.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local AtlasService = {}

function AtlasService.Init()
	local id = tonumber(string.match(tostring(Config.UIAtlasId or ""), "%d+")) or 0
	if id <= 0 then
		ReplicatedStorage:SetAttribute("UIAtlasImage", 0)
		return
	end
	task.spawn(function()
		local image = 0
		local ok, model = pcall(InsertService.LoadAsset, InsertService, id)
		if ok and model then
			local decal = model:FindFirstChildWhichIsA("Decal", true)
			if decal then
				image = tonumber(string.match(decal.Texture, "(%d+)%s*$")) or 0
			end
			model:Destroy()
		end
		if image > 0 and image ~= id then
			print(string.format("[UI] Config.UIAtlasId %d is a Decal; using its image %d.", id, image))
		end
		ReplicatedStorage:SetAttribute("UIAtlasImage", image)
	end)
end

return AtlasService
