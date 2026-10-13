local Controllers = script.Parent:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
local FishingController = require(Controllers:WaitForChild("FishingController"))

UIController.Init()
FishingController.Init(UIController)
