-- All the menus: coin + bag counters, side menu, Bag / Shop / Index / Dock panels,
-- catch popup, toasts and the bottom hint line.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FishData = require(Shared.FishData)
local RodData = require(Shared.RodData)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local UIKit = require(script.Parent.Parent:WaitForChild("UIKit"))

local make, text, corner, stroke, tween = UIKit.make, UIKit.text, UIKit.corner, UIKit.stroke, UIKit.tween
local C, F = UIKit.Color, UIKit.Font

local player = Players.LocalPlayer

local UIController = {}
UIController.Data = nil
UIController.Kit = UIKit

local gui: ScreenGui
local panels = {}
local openName: string? = nil
local menuButtons = {}
local toastHolder, hintFrame, hintLabel
local coinsLabel, bagLabel, coinPill
local shownCoins = 0
local hasData = false
local coinValue = Instance.new("NumberValue")

local function coins(n)
	return "$" .. Format.Number(n)
end

local function clear(container)
	for _, c in container:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- Toasts --------------------------------------------------------------------
function UIController.Notify(message: string, kind: string?)
	local accent = if kind == "error" then C.Danger elseif kind == "success" then C.Good else C.Accent
	local icon = if kind == "error" then "✕" elseif kind == "success" then "✓" else "•"
	local toast = make("CanvasGroup", {
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Panel,
		GroupTransparency = 1,
		Parent = toastHolder,
	}, { corner(20), stroke(accent, 2, 0.2), UIKit.pad(0, 16), UIKit.list(Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center) })
	text(icon, 18, F.Black, accent, { LayoutOrder = 1, Parent = toast })
	text(message, 17, F.Bold, C.Text, { LayoutOrder = 2, Parent = toast })
	tween(toast, 0.2, { GroupTransparency = 0 })
	task.delay(3, function()
		tween(toast, 0.35, { GroupTransparency = 1 }).Completed:Wait()
		toast:Destroy()
	end)
end

function UIController.SetHint(message: string?)
	if message then
		hintLabel.Text = message
		hintFrame.Visible = true
	else
		hintFrame.Visible = false
	end
end

-- Panels --------------------------------------------------------------------
local function setOpen(name: string?)
	openName = name
	for n, p in panels do
		local want = n == name
		if want and not p.Root.Visible then
			p.Root.Visible = true
			p.Root.GroupTransparency = 1
			p.Scale.Scale = 0.92
			tween(p.Scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(p.Root, 0.15, { GroupTransparency = 0 })
			if UIController.Data and p.Refresh then
				p.Refresh(UIController.Data)
			end
		elseif not want and p.Root.Visible then
			tween(p.Scale, 0.12, { Scale = 0.96 })
			tween(p.Root, 0.12, { GroupTransparency = 1 }).Completed:Connect(function()
				if openName ~= n then
					p.Root.Visible = false
				end
			end)
		end
		local b = menuButtons[n]
		if b then
			b.Stroke.Transparency = if want then 0 else 0.85
		end
	end
end
UIController.Open = setOpen

local function makePanel(name, icon, title, hasFooter)
	local root = make("CanvasGroup", {
		Name = name,
		Size = UDim2.fromOffset(640, 460),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local scale = make("UIScale", { Parent = root })
	local card = make("Frame", {
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = C.Panel,
		Parent = root,
	}, { corner(18), stroke(Color3.new(1, 1, 1), 2, 0.86), UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 206, 218)) })

	text(icon, 30, F.Black, C.Text, { Position = UDim2.fromOffset(20, 14), Parent = card })
	text(title, 28, F.Black, C.Text, { Position = UDim2.fromOffset(64, 15), Parent = card })
	local close = make("TextButton", {
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.new(1, -54, 0, 14),
		BackgroundColor3 = C.Card,
		Text = "✕",
		TextSize = 18,
		FontFace = F.Black,
		TextColor3 = C.Sub,
		AutoButtonColor = false,
		Parent = card,
	}, { UIKit.round(), stroke(Color3.new(1, 1, 1), 1.5, 0.85) })
	UIKit.juice(close)
	close.Activated:Connect(function()
		setOpen(nil)
	end)
	make("Frame", { Size = UDim2.new(1, -40, 0, 1), Position = UDim2.fromOffset(20, 66), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = card })

	local footerH = if hasFooter then 68 else 0
	local body = make("ScrollingFrame", {
		Name = "Body",
		Size = UDim2.new(1, -24, 1, -(80 + footerH)),
		Position = UDim2.fromOffset(12, 74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Sub,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = card,
	}, { UIKit.pad(8) })
	local footer
	if hasFooter then
		footer = make("Frame", {
			Size = UDim2.new(1, -40, 0, 48),
			Position = UDim2.new(0, 20, 1, -60),
			BackgroundTransparency = 1,
			Parent = card,
		})
	end
	local p = { Root = root, Scale = scale, Body = body, Footer = footer }
	panels[name] = p
	return p
end

local function emptyState(parent, icon, title, sub)
	local holder = make("Frame", { Name = "Empty", Size = UDim2.new(1, 0, 0, 220), BackgroundTransparency = 1, Parent = parent }, {
		UIKit.list(nil, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	text(icon, 54, F.Black, C.Text, { LayoutOrder = 1, Parent = holder })
	text(title, 22, F.Black, C.Text, { LayoutOrder = 2, Parent = holder })
	text(sub, 16, F.Medium, C.Sub, { LayoutOrder = 3, Parent = holder })
	return holder
end

-- Bag ------------------------------------------------------------------------
local function buildBag()
	local p = makePanel("Bag", "🎒", "Fish Bag", true)
	local grid = make("Frame", { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = p.Body })
	make("UIGridLayout", { CellSize = UDim2.fromOffset(134, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local summary = text("", 18, F.Bold, C.Sub, { Size = UDim2.new(0.6, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = p.Footer })
	local sell = UIKit.button("Sell All", C.Good, { Size = UDim2.fromOffset(170, 48), Position = UDim2.new(1, -170, 0, 0), Parent = p.Footer })
	sell.Activated:Connect(function()
		local ok, msg = Remotes.SellAll:InvokeServer()
		UIController.Notify(msg, if ok then "success" else "error")
	end)

	p.Refresh = function(data)
		clear(grid)
		local items = table.clone(data.Inventory)
		table.sort(items, function(a, b)
			return FishData.GetValue(a.Id, a.Kg) > FishData.GetValue(b.Id, b.Kg)
		end)
		local total = 0
		for i, item in items do
			local value = FishData.GetValue(item.Id, item.Kg)
			total += value
			local fish = FishData.ById[item.Id]
			local rarity = FishData.GetRarity(item.Id)
			local card = make("Frame", { BackgroundColor3 = C.Card, LayoutOrder = i, Parent = grid }, { corner(14), stroke(rarity.Color, 2, 0.4) })
			make("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = rarity.Color, BackgroundTransparency = 0.6, Parent = card }, {
				corner(14),
				UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 120)),
			})
			text(fish.Icon, 42, F.Black, C.Text, { Size = UDim2.new(1, 0, 0, 70), AutomaticSize = Enum.AutomaticSize.None, Parent = card })
			text(item.Id, 16, F.Black, rarity.Color:Lerp(Color3.new(1, 1, 1), 0.35), {
				Size = UDim2.new(1, -16, 0, 20), AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.fromOffset(8, 76),
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
			})
			text(rarity.Name .. " · " .. Format.Kg(item.Kg), 13, F.Medium, C.Sub, {
				Size = UDim2.new(1, -16, 0, 16), AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.fromOffset(8, 98),
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card,
			})
			text(coins(value), 17, F.Black, C.Gold, { Size = UDim2.new(1, -16, 0, 20), AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.fromOffset(8, 120), TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		end
		grid.Visible = #items > 0
		local empty = p.Body:FindFirstChild("Empty")
		if #items == 0 and not empty then
			emptyState(p.Body, "🎣", "Your bag is empty", "Cast your rod into the water to catch fish.")
		elseif #items > 0 and empty then
			empty:Destroy()
		end
		summary.Text = string.format('<font color="#FFCE54">%s</font>   ·   %d / %d fish', coins(total), #items, Config.InventoryCap)
	end
end

-- Rod shop ---------------------------------------------------------------------
local function buildShop()
	local p = makePanel("Shop", "🎣", "Rod Shop", false)
	make("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p.Body })
	local function chip(parent, label, order)
		local c = make("Frame", { Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.Bg, BackgroundTransparency = 0.3, LayoutOrder = order, Parent = parent }, {
			UIKit.round(),
			UIKit.pad(0, 10),
		})
		text(label, 13, F.Bold, C.Sub, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = c })
	end
	p.Refresh = function(data)
		for _, c in p.Body:GetChildren() do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for _, rod in RodData.List do
			local owned = data.OwnedRods[rod.Id]
			local equipped = data.Rod == rod.Id
			local row = make("Frame", { Size = UDim2.new(1, 0, 0, 84), BackgroundColor3 = C.Card, LayoutOrder = rod.Order, Parent = p.Body }, {
				corner(14),
				stroke(if equipped then C.Accent else Color3.new(1, 1, 1), 2, if equipped then 0 else 0.9),
			})
			local swatch = make("Frame", { Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(14, 14), BackgroundColor3 = rod.Color, Parent = row }, {
				corner(14),
				UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150), 45),
			})
			text("🎣", 28, F.Black, C.Text, { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, Parent = swatch })
			text(rod.Name, 20, F.Black, C.Text, { Position = UDim2.fromOffset(84, 14), Parent = row })
			local chips = make("Frame", { Size = UDim2.new(1, -240, 0, 24), Position = UDim2.fromOffset(84, 46), BackgroundTransparency = 1, Parent = row }, {
				UIKit.list(Enum.FillDirection.Horizontal, 6),
			})
			chip(chips, string.format("Luck ×%.2f", rod.Luck), 1)
			chip(chips, string.format("Bite ×%.2f", rod.BiteSpeed), 2)
			chip(chips, string.format("Control ×%.2f", rod.Control), 3)

			local label, color
			if equipped then
				label, color = "Equipped", C.Muted
			elseif owned then
				label, color = "Equip", C.Accent
			else
				label, color = coins(rod.Price), if data.Coins >= rod.Price then C.Good else C.Muted
			end
			local b = UIKit.button(label, color, { Size = UDim2.fromOffset(130, 44), Position = UDim2.new(1, -144, 0.5, -22), Parent = row })
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

-- Fish index -------------------------------------------------------------------
local function buildIndex()
	local p = makePanel("Index", "📖", "Fish Index", true)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(110, 132), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p.Body })
	local progressText = text("", 16, F.Bold, C.Sub, { Position = UDim2.fromOffset(0, 0), Parent = p.Footer })
	local bar = make("Frame", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -14), BackgroundColor3 = C.Bg, Parent = p.Footer }, { UIKit.round() })
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, Parent = bar }, { UIKit.round(), UIKit.gradient(C.Accent, C.Good, 0) })

	p.Refresh = function(data)
		clear(p.Body)
		local found = 0
		for i, fish in FishData.Fish do
			local rarity = FishData.GetRarity(fish.Id)
			local best = data.Discovered[fish.Id]
			if best then
				found += 1
			end
			local cell = make("Frame", {
				BackgroundColor3 = if best then C.Card else C.Bg,
				LayoutOrder = FishData.RarityIndex[fish.Rarity] * 100 + i,
				Parent = p.Body,
			}, { corner(14), stroke(rarity.Color, 2, if best then 0.35 else 0.75) })
			text(if best then fish.Icon else "❔", 38, F.Black, C.Text, {
				Size = UDim2.new(1, 0, 0, 58), AutomaticSize = Enum.AutomaticSize.None,
				TextTransparency = if best then 0 else 0.5, Parent = cell,
			})
			text(if best then fish.Id else "???", 14, F.Black, if best then C.Text else C.Sub, {
				Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 60), AutomaticSize = Enum.AutomaticSize.None,
				TextTruncate = Enum.TextTruncate.AtEnd, Parent = cell,
			})
			text(rarity.Name, 12, F.Bold, rarity.Color, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 80), AutomaticSize = Enum.AutomaticSize.None, Parent = cell })
			text(if best then "Best " .. Format.Kg(best) else FishData.ZoneNames[fish.Zone], 12, F.Medium, C.Sub, {
				Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, 100), AutomaticSize = Enum.AutomaticSize.None, Parent = cell,
			})
		end
		progressText.Text = string.format("Discovered %d of %d fish", found, #FishData.Fish)
		tween(fill, 0.4, { Size = UDim2.fromScale(found / #FishData.Fish, 1) })
	end
end

-- Dock upgrades ----------------------------------------------------------------
local function buildDock()
	local p = makePanel("Dock", "⚓", "My Dock", true)
	p.Body.ScrollingEnabled = false
	local levelText = text("", 40, F.Black, C.Text, { Position = UDim2.fromOffset(12, 6), Parent = p.Body })
	local pips = make("Frame", { Size = UDim2.fromOffset(300, 22), Position = UDim2.fromOffset(14, 60), BackgroundTransparency = 1, Parent = p.Body }, {
		UIKit.list(Enum.FillDirection.Horizontal, 8),
	})
	local pipFrames = {}
	for i = 1, Config.Dock.MaxLevel do
		pipFrames[i] = make("Frame", { Size = UDim2.fromOffset(44, 14), BackgroundColor3 = C.Bg, LayoutOrder = i, Parent = pips }, { UIKit.round() })
	end
	local function statRow(y, icon, label)
		local row = make("Frame", { Size = UDim2.new(1, -24, 0, 52), Position = UDim2.fromOffset(12, y), BackgroundColor3 = C.Card, Parent = p.Body }, { corner(12) })
		text(icon, 24, F.Black, C.Text, { Position = UDim2.fromOffset(14, 12), Parent = row })
		text(label, 18, F.Bold, C.Sub, { Position = UDim2.fromOffset(52, 15), Parent = row })
		return text("", 20, F.Black, C.Good, { Position = UDim2.new(1, -16, 0, 14), AnchorPoint = Vector2.new(1, 0), Parent = row })
	end
	local luck = statRow(100, "🍀", "Luck bonus")
	local speed = statRow(160, "⚡", "Bite speed bonus")
	text("Fish from your own base's dock to catch dock-only fish and get these bonuses.", 15, F.Medium, C.Sub, {
		Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 222), AutomaticSize = Enum.AutomaticSize.None,
		TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = p.Body,
	})
	local upgrade, upgradeLabel = UIKit.button("Upgrade", C.Good, { Size = UDim2.fromScale(1, 1), Parent = p.Footer })
	upgrade.Activated:Connect(function()
		local ok, msg = Remotes.UpgradeDock:InvokeServer()
		UIController.Notify(msg, if ok then "success" else "error")
	end)

	p.Refresh = function(data)
		local lvl = data.DockLevel
		local bonus = lvl - 1
		levelText.Text = "Level " .. lvl
		for i, pip in pipFrames do
			pip.BackgroundColor3 = if i <= lvl then C.Accent else C.Bg
		end
		luck.Text = string.format("+%d%%", math.floor(Config.Dock.LuckPerLevel * bonus * 100 + 0.5))
		speed.Text = string.format("+%d%%", math.floor(Config.Dock.BiteSpeedPerLevel * bonus * 100 + 0.5))
		if lvl >= Config.Dock.MaxLevel then
			upgradeLabel.Text = "Max Level"
			upgrade.BackgroundColor3 = C.Muted
		else
			local cost = Config.Dock.Costs[lvl]
			upgradeLabel.Text = "Upgrade  ·  " .. coins(cost)
			upgrade.BackgroundColor3 = if data.Coins >= cost then C.Good else C.Muted
		end
	end
end

-- Catch popup --------------------------------------------------------------------
function UIController.ShowCatch(info)
	local fish = FishData.ById[info.Id]
	local rarity = FishData.GetRarity(info.Id)
	local root = make("CanvasGroup", {
		Size = UDim2.fromOffset(420, 150),
		Position = UDim2.new(0.5, 0, 0, 150),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Parent = gui,
	})
	local scale = make("UIScale", { Scale = 0.6, Parent = root })
	local card = make("Frame", { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.Panel, Parent = root }, {
		corner(20),
		UIKit.gradient(rarity.Color:Lerp(C.Panel, 0.55), C.Panel, 0),
	})
	local ring = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Parent = card })
	local shimmer = make("UIGradient", { Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1)), Parent = ring })
	text(fish.Icon, 64, F.Black, C.Text, { Size = UDim2.fromOffset(110, 142), AutomaticSize = Enum.AutomaticSize.None, Parent = card })
	local tag = if info.New then "NEW!  " elseif info.Record then "RECORD!  " else ""
	text(tag .. string.upper(rarity.Name), 16, F.Black, rarity.Color:Lerp(Color3.new(1, 1, 1), 0.2), { Position = UDim2.fromOffset(110, 22), Parent = card })
	text(info.Id, 32, F.Black, C.Text, { Position = UDim2.fromOffset(110, 44), Parent = card })
	text(Format.Kg(info.Kg) .. "   ·   " .. coins(info.Value), 18, F.Bold, C.Gold, { Position = UDim2.fromOffset(110, 92), Parent = card })

	tween(root, 0.15, { GroupTransparency = 0 })
	tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	local spin = tween(shimmer, 2.8, { Rotation = 360 }, Enum.EasingStyle.Linear)
	task.delay(2.8, function()
		spin:Cancel()
		tween(scale, 0.2, { Scale = 0.9 })
		tween(root, 0.2, { GroupTransparency = 1 }).Completed:Wait()
		root:Destroy()
	end)
end

function UIController.GetGui()
	return gui
end

-- HUD ----------------------------------------------------------------------------
local function refreshAll(data)
	UIController.Data = data
	if not hasData then
		coinValue.Value = data.Coins
	else
		tween(coinValue, 0.5, { Value = data.Coins })
	end
	if hasData and data.Coins > shownCoins then
		local gain = data.Coins - shownCoins
		do
			local pop = text("+" .. Format.Number(gain), 22, F.Black, C.Gold, {
				Position = UDim2.new(0.5, 0, 1, 6), AnchorPoint = Vector2.new(0.5, 0), Parent = coinPill,
			})
			make("UIStroke", { Thickness = 1.5, Transparency = 0.4, Parent = pop })
			tween(pop, 0.9, { Position = UDim2.new(0.5, 0, 1, 30), TextTransparency = 1 })
			task.delay(0.9, function()
				pop:Destroy()
			end)
		end
	end
	shownCoins = data.Coins
	hasData = true
	bagLabel.Text = string.format("🐟 %d / %d", #data.Inventory, Config.InventoryCap)
	bagLabel.TextColor3 = if #data.Inventory >= Config.InventoryCap then C.Danger else C.Text
	for _, p in panels do
		if p.Root.Visible and p.Refresh then
			p.Refresh(data)
		end
	end
end

local function pill(width, parent, order)
	return make("Frame", { Size = UDim2.fromOffset(width, 46), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.15, LayoutOrder = order, Parent = parent }, {
		UIKit.round(),
		stroke(Color3.new(1, 1, 1), 1.5, 0.85),
	})
end

function UIController.Init()
	gui = make("ScreenGui", {
		Name = "FishingUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Keep everything the same size on phones and big monitors
	local uiScale = make("UIScale", { Parent = gui })
	local function rescale()
		local vp = Workspace.CurrentCamera.ViewportSize
		uiScale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.6, 1.3)
	end
	rescale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- Top counters
	local top = make("Frame", { Size = UDim2.fromOffset(420, 46), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui }, {
		UIKit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center),
	})
	coinPill = pill(190, top, 1)
	local coinRow = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = coinPill }, {
		UIKit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local coinIcon = make("Frame", { Size = UDim2.fromOffset(26, 26), BackgroundColor3 = C.Gold, LayoutOrder = 1, Parent = coinRow }, {
		UIKit.round(),
		UIKit.gradient(Color3.fromRGB(255, 236, 150), Color3.fromRGB(230, 160, 40)),
		make("UIStroke", { Color = Color3.fromRGB(170, 110, 20), Thickness = 2 }),
	})
	text("$", 17, F.Black, Color3.fromRGB(150, 95, 15), { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, Parent = coinIcon })
	coinsLabel = text("0", 22, F.Black, C.Gold, { LayoutOrder = 2, Parent = coinRow })
	coinValue.Changed:Connect(function(v)
		coinsLabel.Text = Format.Number(math.floor(v + 0.5))
	end)
	local bagPill = pill(150, top, 2)
	bagLabel = text("🐟 0 / " .. Config.InventoryCap, 20, F.Black, C.Text, { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, Parent = bagPill })

	toastHolder = make("Frame", { Size = UDim2.fromOffset(600, 200), Position = UDim2.new(0.5, 0, 0, 72), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui }, {
		UIKit.list(nil, 8, Enum.HorizontalAlignment.Center),
	})

	hintFrame = make("Frame", {
		Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 1, -110), AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.Bg, BackgroundTransparency = 0.25, Visible = false, Parent = gui,
	}, { UIKit.round(), UIKit.pad(0, 18) })
	hintLabel = text("", 17, F.Bold, C.Text, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = hintFrame })

	-- Side menu
	local menu = make("Frame", { Size = UDim2.fromOffset(84, 360), Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui }, {
		UIKit.list(nil, 10, nil, Enum.VerticalAlignment.Center),
	})
	buildBag()
	buildShop()
	buildIndex()
	buildDock()
	for i, entry in { { "Bag", "🎒", Color3.fromRGB(72, 170, 96) }, { "Shop", "🎣", Color3.fromRGB(232, 146, 52) }, { "Index", "📖", Color3.fromRGB(146, 96, 226) }, { "Dock", "⚓", Color3.fromRGB(56, 150, 230) } } do
		local name, icon, color = entry[1], entry[2], entry[3]
		local b = make("TextButton", { Size = UDim2.fromOffset(80, 80), BackgroundColor3 = color, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = menu }, {
			corner(18),
			UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
		})
		local ring = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = 0.85, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
		text(icon, 32, F.Black, C.Text, { Size = UDim2.new(1, 0, 0, 52), AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.fromOffset(0, 4), Parent = b })
		local l = text(name, 15, F.Black, C.Text, { Size = UDim2.new(1, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.fromOffset(0, 54), Parent = b })
		make("UIStroke", { Thickness = 1, Transparency = 0.6, Parent = l })
		UIKit.juice(b)
		b.Activated:Connect(function()
			setOpen(if openName == name then nil else name)
		end)
		menuButtons[name] = { Button = b, Stroke = ring }
	end

	Remotes.DataChanged.OnClientEvent:Connect(refreshAll)
	Remotes.Notify.OnClientEvent:Connect(UIController.Notify)
	Remotes.OpenPanel.OnClientEvent:Connect(function(name)
		if panels[name] then
			setOpen(name)
		end
	end)
	Remotes.Announce.OnClientEvent:Connect(function(name, fishId, rarityName, kg)
		UIController.Notify(string.format("%s caught a %s %s (%s)!", name, rarityName, fishId, Format.Kg(kg)), "success")
	end)
	task.spawn(function()
		local data = Remotes.GetData:InvokeServer()
		if data and not hasData then
			refreshAll(data)
		end
	end)
end

return UIController
