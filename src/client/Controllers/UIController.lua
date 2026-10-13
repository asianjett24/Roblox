-- Builds all the menus in code: coins HUD, Bag, Rod Shop, Fish Index, Pond, toasts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishData = require(Shared.FishData)
local RodData = require(Shared.RodData)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local player = Players.LocalPlayer

local UIController = {}
UIController.Data = nil

local FONT = Enum.Font.FredokaOne
local BG = Color3.fromRGB(28, 34, 48)
local PANEL = Color3.fromRGB(40, 48, 66)
local ACCENT = Color3.fromRGB(70, 170, 255)
local GOOD = Color3.fromRGB(80, 200, 110)

local gui: ScreenGui
local panels = {}
local refreshers = {}

local function make(class, props, children)
	local inst = Instance.new(class)
	for k, v in props or {} do
		inst[k] = v
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

local function corner(r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

local function stroke(color, thickness)
	return make("UIStroke", { Color = color or Color3.new(0, 0, 0), Thickness = thickness or 2, Transparency = 0.4 })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return make("TextLabel", props)
end

local function button(text, color, props)
	props = props or {}
	props.Text = text
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = Color3.new(1, 1, 1)
	props.BackgroundColor3 = color or ACCENT
	props.AutoButtonColor = true
	local b = make("TextButton", props, { corner(8), make("UIPadding", {
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	}) })
	return b
end

-- Toasts ------------------------------------------------------------------
local toastHolder
function UIController.Notify(text: string, kind: string?)
	local color = if kind == "error"
		then Color3.fromRGB(220, 70, 70)
		elseif kind == "success" then GOOD
		else ACCENT
	local t = label({
		Text = text,
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 0.1,
		BackgroundColor3 = color,
		Parent = toastHolder,
	})
	corner(8).Parent = t
	make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = t })
	task.delay(3, function()
		TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		task.wait(0.4)
		t:Destroy()
	end)
end

-- Panels ------------------------------------------------------------------
local function closeAll(except)
	for name, p in panels do
		if name ~= except then
			p.Visible = false
		end
	end
end

local function makePanel(name, title)
	local frame = make("Frame", {
		Name = name,
		Size = UDim2.fromScale(0.5, 0.6),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = BG,
		Visible = false,
		Parent = gui,
	}, {
		corner(14),
		stroke(Color3.new(0, 0, 0), 3),
		make("UISizeConstraint", { MinSize = Vector2.new(320, 260), MaxSize = Vector2.new(640, 480) }),
	})
	label({ Text = title, Size = UDim2.new(1, -60, 0, 40), Position = UDim2.fromOffset(16, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	local close = button("X", Color3.fromRGB(200, 60, 60), { Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -46, 0, 10), Parent = frame })
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local body = make("ScrollingFrame", {
		Name = "Body",
		Size = UDim2.new(1, -24, 1, -110),
		Position = UDim2.fromOffset(12, 56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	})
	local footer = make("Frame", {
		Name = "Footer",
		Size = UDim2.new(1, -24, 0, 42),
		Position = UDim2.new(0, 12, 1, -52),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	panels[name] = frame
	return frame, body, footer
end

local function clearBody(body)
	for _, c in body:GetChildren() do
		if not c:IsA("UIGridLayout") and not c:IsA("UIListLayout") then
			c:Destroy()
		end
	end
end

local function row(parent, order)
	return make("Frame", {
		Size = UDim2.new(1, -8, 0, 48),
		BackgroundColor3 = PANEL,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(8) })
end

-- Bag
local function buildBag()
	local _, body, footer = makePanel("Bag", "Fish Bag")
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	local totalLabel = label({ Size = UDim2.new(0.55, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = footer })
	local sell = button("Sell All", GOOD, { Size = UDim2.new(0.4, 0, 1, 0), Position = UDim2.fromScale(0.6, 0), Parent = footer })
	sell.Activated:Connect(function()
		local ok, msg = Remotes.SellAll:InvokeServer()
		UIController.Notify(msg, if ok then "success" else "error")
	end)

	refreshers.Bag = function(data)
		clearBody(body)
		local items = table.clone(data.Inventory)
		table.sort(items, function(a, b)
			return FishData.GetValue(a.Id, a.Kg) > FishData.GetValue(b.Id, b.Kg)
		end)
		local total = 0
		for i, item in items do
			local value = FishData.GetValue(item.Id, item.Kg)
			total += value
			local rarity = FishData.GetRarity(item.Id)
			local r = row(body, i)
			make("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = rarity.Color, Parent = r }, { corner(3) })
			label({ Text = item.Id, Size = UDim2.new(0.4, 0, 0.6, 0), Position = UDim2.new(0, 14, 0, 4), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rarity.Color, Parent = r })
			label({ Text = rarity.Name .. " · " .. Format.Kg(item.Kg), Size = UDim2.new(0.4, 0, 0.35, 0), Position = UDim2.new(0, 14, 0.6, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(170, 180, 200), Parent = r })
			label({ Text = Format.Number(value) .. " c", Size = UDim2.new(0.3, 0, 0.6, 0), Position = UDim2.new(0.68, 0, 0.2, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(255, 220, 90), Parent = r })
		end
		if #items == 0 then
			label({ Text = "No fish yet. Go cast your rod!", Size = UDim2.new(1, 0, 0, 40), TextColor3 = Color3.fromRGB(170, 180, 200), Parent = body })
		end
		totalLabel.Text = string.format("%d/%d fish · %s c", #items, Config.InventoryCap, Format.Number(total))
	end
end

-- Rod shop
local function buildShop()
	local _, body = makePanel("Shop", "Rod Shop")
	make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	refreshers.Shop = function(data)
		clearBody(body)
		for _, rod in RodData.List do
			local r = row(body, rod.Order)
			r.Size = UDim2.new(1, -8, 0, 58)
			make("Frame", { Size = UDim2.fromOffset(10, 40), Position = UDim2.new(0, 10, 0.5, -20), BackgroundColor3 = rod.Color, Parent = r }, { corner(4) })
			label({ Text = rod.Name, Size = UDim2.new(0.5, 0, 0.5, 0), Position = UDim2.new(0, 30, 0, 4), TextXAlignment = Enum.TextXAlignment.Left, Parent = r })
			label({
				Text = string.format("Luck x%.2f · Speed x%.2f · Control x%.2f", rod.Luck, rod.BiteSpeed, rod.Control),
				Size = UDim2.new(0.6, 0, 0.32, 0),
				Position = UDim2.new(0, 30, 0.58, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = Color3.fromRGB(170, 180, 200),
				Parent = r,
			})
			local owned = data.OwnedRods[rod.Id]
			local equipped = data.Rod == rod.Id
			local text, color
			if equipped then
				text, color = "Equipped", Color3.fromRGB(90, 90, 100)
			elseif owned then
				text, color = "Equip", ACCENT
			else
				text, color = Format.Number(rod.Price) .. " c", if data.Coins >= rod.Price then GOOD else Color3.fromRGB(120, 120, 130)
			end
			local b = button(text, color, { Size = UDim2.new(0.28, 0, 0, 38), Position = UDim2.new(0.7, 0, 0.5, -19), Parent = r })
			b.Activated:Connect(function()
				if equipped then
					return
				end
				local remote = if owned then Remotes.EquipRod else Remotes.BuyRod
				local ok, msg = remote:InvokeServer(rod.Id)
				UIController.Notify(msg, if ok then "success" else "error")
			end)
		end
	end
end

-- Fish index
local function buildIndex()
	local _, body, footer = makePanel("Index", "Fish Index")
	make("UIGridLayout", { CellSize = UDim2.fromOffset(110, 80), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	local progress = label({ Size = UDim2.fromScale(1, 1), Parent = footer })
	refreshers.Index = function(data)
		clearBody(body)
		local found = 0
		for i, fish in FishData.Fish do
			local rarity = FishData.GetRarity(fish.Id)
			local best = data.Discovered[fish.Id]
			if best then
				found += 1
			end
			local cell = make("Frame", { BackgroundColor3 = PANEL, LayoutOrder = FishData.RarityIndex[fish.Rarity] * 100 + i, Parent = body }, { corner(8), stroke(rarity.Color, 2) })
			label({ Text = if best then fish.Id else "???", Size = UDim2.new(1, -8, 0.4, 0), Position = UDim2.fromOffset(4, 4), TextColor3 = if best then rarity.Color else Color3.fromRGB(120, 120, 130), Parent = cell })
			label({ Text = rarity.Name .. " · " .. fish.Zone, Size = UDim2.new(1, -8, 0.25, 0), Position = UDim2.new(0, 4, 0.45, 0), TextColor3 = Color3.fromRGB(170, 180, 200), Parent = cell })
			label({ Text = if best then "Best: " .. Format.Kg(best) else "", Size = UDim2.new(1, -8, 0.22, 0), Position = UDim2.new(0, 4, 0.73, 0), TextColor3 = Color3.fromRGB(255, 220, 90), Parent = cell })
		end
		progress.Text = string.format("Discovered %d / %d", found, #FishData.Fish)
	end
end

-- Pond
local function buildPond()
	local _, body, footer = makePanel("Pond", "My Pond")
	local info = label({ Size = UDim2.new(1, 0, 0, 120), TextScaled = false, TextSize = 20, TextWrapped = true, Parent = body })
	local upgrade = button("Upgrade", GOOD, { Size = UDim2.fromScale(1, 1), Parent = footer })
	upgrade.Activated:Connect(function()
		local ok, msg = Remotes.UpgradePond:InvokeServer()
		UIController.Notify(msg, if ok then "success" else "error")
	end)
	refreshers.Pond = function(data)
		local lvl = data.PondLevel
		local bonus = lvl - 1
		info.Text = string.format(
			"The hole on your plot is your private pond.\nOnly you can fish there, and it has its own fish.\n\nLevel %d / %d\nLuck +%d%%  ·  Bite speed +%d%%",
			lvl,
			Config.Pond.MaxLevel,
			math.floor(Config.Pond.LuckPerLevel * bonus * 100 + 0.5),
			math.floor(Config.Pond.BiteSpeedPerLevel * bonus * 100 + 0.5)
		)
		if lvl >= Config.Pond.MaxLevel then
			upgrade.Text = "Max Level"
			upgrade.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		else
			local cost = Config.Pond.Costs[lvl]
			upgrade.Text = "Upgrade (" .. Format.Number(cost) .. " c)"
			upgrade.BackgroundColor3 = if data.Coins >= cost then GOOD else Color3.fromRGB(120, 120, 130)
		end
	end
end

-- Catch popup ---------------------------------------------------------------
function UIController.ShowCatch(info)
	local rarity = FishData.GetRarity(info.Id)
	local card = make("Frame", {
		Size = UDim2.fromOffset(320, 130),
		Position = UDim2.new(0.5, 0, 0.22, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = BG,
		Parent = gui,
	}, { corner(14), stroke(rarity.Color, 4) })
	local tag = if info.New then "NEW! " elseif info.Record then "RECORD! " else ""
	label({ Text = tag .. rarity.Name, Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 8), TextColor3 = rarity.Color, Parent = card })
	label({ Text = info.Id, Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 36), Parent = card })
	label({ Text = Format.Kg(info.Kg) .. "  ·  " .. Format.Number(info.Value) .. " coins", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 90), TextColor3 = Color3.fromRGB(255, 220, 90), Parent = card })
	local scale = make("UIScale", { Scale = 0.3, Parent = card })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(2.6, function()
		TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0 }):Play()
		task.wait(0.25)
		card:Destroy()
	end)
end

function UIController.GetGui()
	return gui
end

local function refreshAll(data)
	UIController.Data = data
	for _, fn in refreshers do
		fn(data)
	end
end

function UIController.Init()
	gui = make("ScreenGui", { Name = "FishingUI", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

	toastHolder = make("Frame", {
		Size = UDim2.fromOffset(360, 300),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { make("UIListLayout", { Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

	-- Coins HUD
	local hud = make("Frame", { Size = UDim2.fromOffset(200, 46), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = BG, BackgroundTransparency = 0.15, Parent = gui }, { corner(12), stroke() })
	local coins = label({ Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), TextColor3 = Color3.fromRGB(255, 220, 90), Parent = hud })
	refreshers.Hud = function(data)
		coins.Text = "Coins: " .. Format.Number(data.Coins)
	end

	-- Side menu buttons
	local menu = make("Frame", { Size = UDim2.fromOffset(110, 230), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui }, {
		make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	buildBag()
	buildShop()
	buildIndex()
	buildPond()
	for i, entry in { { "Bag", Color3.fromRGB(80, 160, 90) }, { "Shop", Color3.fromRGB(230, 150, 50) }, { "Index", Color3.fromRGB(150, 90, 220) }, { "Pond", ACCENT } } do
		local name = entry[1]
		local b = button(name, entry[2], { Size = UDim2.new(1, 0, 0, 48), LayoutOrder = i, Parent = menu })
		b.Activated:Connect(function()
			local p = panels[name]
			closeAll(name)
			p.Visible = not p.Visible
		end)
	end

	Remotes.DataChanged.OnClientEvent:Connect(refreshAll)
	Remotes.Notify.OnClientEvent:Connect(UIController.Notify)
	Remotes.Announce.OnClientEvent:Connect(function(name, fishId, rarityName, kg)
		UIController.Notify(string.format("%s caught a %s %s (%s)!", name, rarityName, fishId, Format.Kg(kg)), "success")
	end)
	task.spawn(function()
		local data = Remotes.GetData:InvokeServer()
		if data then
			refreshAll(data)
		end
	end)
end

return UIController
