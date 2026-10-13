local Controllers = script.Parent:WaitForChild("Controllers")

local UIController = require(Controllers:WaitForChild("UIController"))
local FishRenderer = require(Controllers:WaitForChild("FishRenderer"))
local SpearController = require(Controllers:WaitForChild("SpearController"))
local UnderwaterController = require(Controllers:WaitForChild("UnderwaterController"))

UIController.Init()
FishRenderer.Init()
SpearController.Init(UIController, FishRenderer)
UnderwaterController.Init(UIController)
