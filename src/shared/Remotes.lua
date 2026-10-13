-- Server creates the remotes, clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = { "Bite", "CatchResult", "DataChanged", "Notify", "Announce", "Reel" }
local FUNCTIONS = { "Cast", "GetData", "SellAll", "BuyRod", "EquipRod", "UpgradePond" }

local Remotes = {}
local folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	for _, name in EVENTS do
		local r = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	for _, name in FUNCTIONS do
		local r = folder:FindFirstChild(name) or Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = folder
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in EVENTS do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in FUNCTIONS do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
