-- Loads/saves player data and keeps leaderstats + client UI in sync.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local DataService = {}

local store
local ok, err = pcall(function()
	store = DataStoreService:GetDataStore(Config.DataStoreName)
end)
if not ok then
	warn("[DataService] DataStore unavailable, progress won't save:", err)
end

local profiles: { [Player]: any } = {}
local loadFailed: { [Player]: boolean } = {}
local loadedSignal = Instance.new("BindableEvent")
local changedSignal = Instance.new("BindableEvent")

-- Fires (player, data) whenever a player's data changes.
DataService.OnChanged = changedSignal.Event

local function defaultData()
	return {
		Coins = Config.StartingCoins,
		Gun = "Wooden",
		OwnedGuns = { Wooden = true },
		Inventory = {}, -- { {Id=string, Kg=number}, ... }
		Discovered = {}, -- [fishId] = best kg
		Caught = 0,
		TankLevel = 1,
	}
end

local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		end
	end
	return data
end

local function key(player: Player)
	return "player_" .. player.UserId
end

local function withRetries(fn)
	local success, result
	for attempt = 1, 4 do
		success, result = pcall(fn)
		if success then
			return true, result
		end
		task.wait(attempt * 1.5)
	end
	return false, result
end

local function makeLeaderstats(player: Player, data)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.Coins
	coins.Parent = folder
	local caught = Instance.new("IntValue")
	caught.Name = "Caught"
	caught.Value = data.Caught
	caught.Parent = folder
	folder.Parent = player
end

local function save(player: Player)
	local data = profiles[player]
	if not data or not store or loadFailed[player] then
		return
	end
	local success, e = withRetries(function()
		store:UpdateAsync(key(player), function()
			return data
		end)
	end)
	if not success then
		warn("[DataService] Save failed for", player.Name, e)
	end
end

local function onPlayerAdded(player: Player)
	local data
	if store then
		local success, result = withRetries(function()
			return store:GetAsync(key(player))
		end)
		if success then
			data = result
		else
			-- Don't overwrite their real save with a blank profile later.
			loadFailed[player] = true
			warn("[DataService] Load failed for", player.Name, result)
		end
	end
	if not player.Parent then
		return
	end
	data = reconcile(data or {}, defaultData())
	profiles[player] = data
	makeLeaderstats(player, data)
	if loadFailed[player] then
		Remotes.Notify:FireClient(player, "Couldn't load your save. Progress this session won't be saved.", "error")
	end
	loadedSignal:Fire(player)
	DataService.Changed(player)
end

function DataService.Get(player: Player)
	return profiles[player]
end

-- Yields until the player's data is ready (or they leave).
function DataService.WaitFor(player: Player)
	while player.Parent and not profiles[player] do
		loadedSignal.Event:Wait()
	end
	return profiles[player]
end

function DataService.Changed(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Coins.Value = data.Coins
		stats.Caught.Value = data.Caught
	end
	Remotes.DataChanged:FireClient(player, data)
	changedSignal:Fire(player, data)
end

function DataService.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		profiles[player] = nil
		loadFailed[player] = nil
		loadedSignal:Fire(player) -- release anyone stuck in WaitFor
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			task.spawn(save, p)
		end
		task.wait(3)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for _, p in Players:GetPlayers() do
				task.spawn(save, p)
			end
		end
	end)
	Remotes.GetData.OnServerInvoke = function(player)
		return DataService.WaitFor(player)
	end
end

return DataService
