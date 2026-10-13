-- The interface: top bar (coins, bag), side navigation, Bag / Shop / Index / Gear panels,
-- catch popup with a live 3D fish, toasts and the hint line.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local FishPath = require(Shared.FishPath)
local Format = require(Shared.Format)
local GunData = require(Shared.GunData)
local GunModels = require(Shared.GunModels)
local Remotes = require(Shared.Remotes)
local UIKit = require(script.Parent.Parent:WaitForChild("UIKit"))
local FishModels = require(script.Parent.Parent:WaitForChild("FishModels"))

local make, text, tween, icon = UIKit.make, UIKit.text, UIKit.tween, UIKit.icon
local C, F = UIKit.Color, UIKit.Font

local player = Players.LocalPlayer

local UIController = {}
UIController.Data = nil
UIController.Kit = UIKit

local gui: ScreenGui
local panels = {}
local navButtons = {}
local openName: string? = nil
local toastHolder, hintFrame, hintLabel
local coinsLabel, bagLabel, coinPill
local coinValue = Instance.new("NumberValue")
local shownCoins, hasData = 0, false

local NAV = {
	{ Name = "Bag", Icon = "bag", Key = Enum.KeyCode.B, Title = "Fish Bag" },
	{ Name = "Shop", Icon = "trident", Key = Enum.KeyCode.V, Title = "Gear Shop" },
	{ Name = "Index", Icon = "book", Key = Enum.KeyCode.X, Title = "Fish Index" },
	{ Name = "Gear", Icon = "bubbles", Key = Enum.KeyCode.G, Title = "Dive Gear" },
}

local function clearChildren(container)
	for _, c in container:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function coinText(parent, amount, size, order)
	local row = make("Frame", { Size = UDim2.fromOffset(0, size + 4), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = order or 0, Parent = parent }, {
		UIKit.list(Enum.FillDirection.Horizontal, 5, nil, Enum.VerticalAlignment.Center),
	})
	icon("coin", size, nil, { LayoutOrder = 1, Parent = row })
	local label = text(Format.Number(amount), size, F.Black, C.Gold, { LayoutOrder = 2, Parent = row })
	return row, label
end

-- Live 3D previews -------------------------------------------------------------------------
local spinners = {} -- [ViewportFrame] = function(dt), run every frame while on screen

local function viewport(parent, props)
	props = props or {}
	props.BackgroundTransparency = 1
	props.Ambient = Color3.fromRGB(150, 160, 180)
	props.LightColor = Color3.fromRGB(255, 250, 240)
	props.LightDirection = Vector3.new(-0.6, -1, -0.4)
	props.Parent = parent
	local vf = make("ViewportFrame", props)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.Parent = vf
	vf.CurrentCamera = cam
	return vf, cam
end

local function fishViewport(parent, speciesId, props)
	local vf, cam = viewport(parent, props)
	local rig = FishModels.Build(speciesId, 1)
	rig.Model.Parent = vf
	local L = rig.L
	cam.CFrame = CFrame.lookAt(Vector3.new(L * 1.9, L * 0.35, -L * 0.15), Vector3.zero)
	local phase, angle = 0, 0
	local parts, cframes = {}, {}
	local function spin(dt)
		phase += dt * 7
		angle += dt * 0.6
		table.clear(parts)
		table.clear(cframes)
		FishModels.Pose(rig, CFrame.Angles(0, math.sin(angle) * 0.6, 0), phase, 1, parts, cframes)
		for i, p in parts do
			p.CFrame = cframes[i]
		end
	end
	spin(0)
	spinners[vf] = spin
	return vf
end

local function gunViewport(parent, gun, props)
	local vf, cam = viewport(parent, props)
	local model = GunModels.Build(gun, false)
	model.Parent = vf
	local center = Vector3.new(0, 0.5, -2.3)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(9.5, 2.2, 0.5), center)
	local angle = math.random() * 6
	local function spin(dt)
		angle += dt * 0.8
		model:PivotTo(CFrame.new(center) * CFrame.Angles(0.12, math.sin(angle) * 0.45, 0) * CFrame.new(-center))
	end
	spin(0)
	spinners[vf] = spin
	return vf
end

local function onScreen(gui: GuiObject)
	local node = gui
	while node and node:IsA("GuiObject") do
		if not node.Visible then
			return false
		end
		node = node.Parent
	end
	return node ~= nil and node:IsA("ScreenGui")
end

RunService.RenderStepped:Connect(function(dt)
	for vf, spin in spinners do
		if not vf.Parent then
			spinners[vf] = nil
		elseif onScreen(vf) then
			spin(dt)
		end
	end
end)

-- Toasts and hint ------------------------------------------------------------------------------
function UIController.Notify(message: string, kind: string?)
	local accent = if kind == "error" then C.Danger elseif kind == "success" then C.Good else C.Accent
	local glyph = if kind == "error" then "alert" elseif kind == "success" then "check" else "fish"
	local toast = make("CanvasGroup", {
		Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Panel,
		GroupTransparency = 1,
		Parent = toastHolder,
	}, {
		UIKit.corner(14),
		UIKit.stroke(accent, 1.5, 0.45),
		make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 18) }),
		UIKit.list(Enum.FillDirection.Horizontal, 12, nil, Enum.VerticalAlignment.Center),
	})
	local badge = make("Frame", { Size = UDim2.fromOffset(32, 32), BackgroundColor3 = accent, BackgroundTransparency = 0.8, LayoutOrder = 1, Parent = toast }, { UIKit.corner(10) })
	icon(glyph, 18, accent, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = badge })
	text(message, 16, F.Bold, C.Text, { LayoutOrder = 2, Parent = toast })
	local scale = make("UIScale", { Scale = 0.9, Parent = toast })
	tween(toast, 0.2, { GroupTransparency = 0 })
	tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		tween(toast, 0.3, { GroupTransparency = 1 }).Completed:Wait()
		toast:Destroy()
	end)
end

function UIController.SetHint(message: string?)
	if message then
		if hintLabel.Text ~= message then
			hintLabel.Text = message
		end
		hintFrame.Visible = true
	else
		hintFrame.Visible = false
	end
end

-- Panels -------------------------------------------------------------------------------------------
local function setOpen(name: string?)
	openName = name
	for n, p in panels do
		local want = n == name
		if want and not p.Root.Visible then
			p.Root.Visible = true
			p.Scale.Scale = 0.88
			tween(p.Scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
			if UIController.Data and p.Refresh then
				p.Refresh(UIController.Data)
			end
		elseif not want and p.Root.Visible then
			tween(p.Scale, 0.12, { Scale = 0.9 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
				if openName ~= n then
					p.Root.Visible = false
				end
			end)
		end
	end
	for n, b in navButtons do
		local active = n == name
		tween(b.Bg, 0.15, { BackgroundTransparency = if active then 0 else 1 })
		b.Icon.Visible = not active
		b.IconActive.Visible = active
		b.Label.TextColor3 = if active then C.Bg else C.Sub
		tween(b.Bar, 0.15, { Size = UDim2.fromOffset(4, if active then 26 else 0) })
	end
end
UIController.Open = setOpen

function UIController.IsPanelOpen(): boolean
	return openName ~= nil
end

local PANEL_W, PANEL_H, MARGIN = 700, 500, 16

local function makePanel(nav, hasFooter)
	-- Plain Frame (not a CanvasGroup) so the 3D previews inside always render.
	local root = make("Frame", {
		Name = nav.Name,
		Size = UDim2.fromOffset(PANEL_W + MARGIN * 2, PANEL_H + MARGIN * 2),
		Position = UDim2.fromScale(0.5, 0.53),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	local scale = make("UIScale", { Parent = root })
	local holder = make("Frame", { Size = UDim2.new(1, -MARGIN * 2, 1, -MARGIN * 2), Position = UDim2.fromOffset(MARGIN, MARGIN), BackgroundTransparency = 1, Parent = root })
	UIKit.shadow(holder, 22, 4, 0)
	local card = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1, Parent = holder }, {
		UIKit.corner(22),
		UIKit.gradient(C.Panel, C.PanelLo),
		UIKit.stroke(Color3.new(1, 1, 1), 1, 0.88),
	})
	-- Header
	local badge = make("Frame", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(24, 22), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card }, {
		UIKit.corner(14),
		UIKit.gradient(C.Accent, C.AccentDeep, 135),
	})
	icon(nav.Icon, 26, C.Bg, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = badge })
	text(nav.Title, 24, F.Black, C.Text, { Position = UDim2.fromOffset(84, 20), Parent = card })
	local subtitle = text("", 14, F.Medium, C.Sub, { Position = UDim2.fromOffset(84, 48), Parent = card })
	local close = make("TextButton", { Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -60, 0, 26), BackgroundColor3 = C.Card, Text = "", AutoButtonColor = false, Parent = card }, {
		UIKit.round(),
		UIKit.stroke(Color3.new(1, 1, 1), 1, 0.88),
	})
	icon("close", 14, C.Sub, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = close })
	UIKit.juice(close, 0.06)
	close.Activated:Connect(function()
		setOpen(nil)
	end)
	make("Frame", { Size = UDim2.new(1, -48, 0, 1), Position = UDim2.fromOffset(24, 88), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = card })

	local footerH = if hasFooter then 76 else 0
	local body = make("ScrollingFrame", {
		Name = "Body",
		Size = UDim2.new(1, -28, 1, -(100 + footerH)),
		Position = UDim2.fromOffset(14, 96),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = C.Faint,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = card,
	}, { UIKit.pad(10, 10) })
	local footer
	if hasFooter then
		make("Frame", { Size = UDim2.new(1, -48, 0, 1), Position = UDim2.new(0, 24, 1, -footerH), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.92, BorderSizePixel = 0, Parent = card })
		footer = make("Frame", { Size = UDim2.new(1, -48, 0, 48), Position = UDim2.new(0, 24, 1, -62), BackgroundTransparency = 1, Parent = card })
	end
	local p = { Root = root, Scale = scale, Body = body, Footer = footer, Subtitle = subtitle }
	panels[nav.Name] = p
	return p
end

local function emptyState(parent, glyph, title, sub)
	local holder = make("Frame", { Name = "Empty", Size = UDim2.new(1, 0, 0, 260), BackgroundTransparency = 1, Parent = parent }, {
		UIKit.list(nil, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local disc = make("Frame", { Size = UDim2.fromOffset(84, 84), BackgroundColor3 = C.Card, LayoutOrder = 1, Parent = holder }, { UIKit.round() })
	icon(glyph, 40, C.Faint, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = disc })
	text(title, 20, F.Black, C.Text, { LayoutOrder = 2, Parent = holder })
	text(sub, 15, F.Medium, C.Sub, { LayoutOrder = 3, Parent = holder })
	return holder
end

-- A fish "portrait": tinted fish icon on a rarity-coloured backdrop.
local function portrait(parent, speciesId, discovered, height)
	local species = FishData.ById[speciesId]
	local rarity = FishData.GetRarity(speciesId)
	local box = make("Frame", { Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent }, {
		UIKit.corner(12),
		make("UIGradient", {
			Color = ColorSequence.new(if discovered then rarity.Color else C.Muted, C.Card),
			Transparency = NumberSequence.new(0.55, 0.9),
			Rotation = 90,
		}),
	})
	icon("fish", math.floor(height * 0.66), if discovered then species.Look.Body:Lerp(Color3.new(1, 1, 1), 0.15) else C.PanelLo, {
		Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), Parent = box,
	})
	return box
end

-- Bag ------------------------------------------------------------------------------------------------
local function buildBag()
	local p = makePanel(NAV[1], true)
	local grid = make("Frame", { Name = "Grid", Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = p.Body })
	make("UIGridLayout", { CellSize = UDim2.fromOffset(146, 178), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local summary = make("Frame", { Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, Parent = p.Footer }, {
		UIKit.list(Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center),
	})
	text("Bag value", 15, F.Bold, C.Sub, { LayoutOrder = 1, Parent = summary })
	local _, totalLabel = coinText(summary, 0, 20, 2)
	local sell = UIKit.button("Sell All", "success", { Size = UDim2.fromOffset(176, 48), Position = UDim2.new(1, -176, 0, 0), Parent = p.Footer })
	sell.Activated:Connect(function()
		local ok, msg = Remotes.SellAll:InvokeServer()
		UIController.Notify(msg, if ok then "success" else "error")
	end)

	p.Refresh = function(data)
		clearChildren(grid)
		local items = table.clone(data.Inventory)
		table.sort(items, function(a, b)
			return FishData.GetValue(a.Id, a.Kg) > FishData.GetValue(b.Id, b.Kg)
		end)
		local total = 0
		for i, item in items do
			local value = FishData.GetValue(item.Id, item.Kg)
			total += value
			local rarity = FishData.GetRarity(item.Id)
			local card = make("Frame", { BackgroundColor3 = C.Card, LayoutOrder = i, Parent = grid }, {
				UIKit.corner(16),
				UIKit.stroke(rarity.Color, 1, 0.55),
				UIKit.pad(6, 6),
			})
			portrait(card, item.Id, true, 86)
			UIKit.chip(string.upper(rarity.Name), rarity.Color, { Position = UDim2.fromOffset(6, 6), Parent = card })
			text(item.Id, 16, F.Black, C.Text, { Size = UDim2.new(1, -8, 0, 20), Position = UDim2.fromOffset(4, 94), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
			text(Format.Kg(item.Kg), 13, F.Medium, C.Sub, { Position = UDim2.fromOffset(4, 116), Parent = card })
			local row = coinText(card, value, 16)
			row.Position = UDim2.fromOffset(4, 140)
		end
		local empty = p.Body:FindFirstChild("Empty")
		grid.Visible = #items > 0
		if #items == 0 and not empty then
			emptyState(p.Body, "bag", "Your bag is empty", "Dive in and spear some fish!")
		elseif #items > 0 and empty then
			empty:Destroy()
		end
		totalLabel.Text = Format.Number(total)
		p.Subtitle.Text = string.format("%d of %d slots used", #items, Config.InventoryCap)
	end
end

-- Shop --------------------------------------------------------------------------------------------------
local function statBar(parent, label, frac, y)
	text(label, 12, F.Bold, C.Sub, { Position = UDim2.fromOffset(0, y), Parent = parent })
	local track = make("Frame", { Size = UDim2.new(1, -96, 0, 6), Position = UDim2.fromOffset(92, y + 5), BackgroundColor3 = C.PanelLo, Parent = parent }, { UIKit.round() })
	make("Frame", { Size = UDim2.fromScale(math.clamp(frac, 0.04, 1), 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track }, {
		UIKit.round(),
		UIKit.gradient(C.Accent, C.Good, 0),
	})
end

local function buildShop()
	local p = makePanel(NAV[2], false)
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p.Body })
	p.Subtitle.Text = "Better spearguns hit harder, reach further and reload faster"
	p.Refresh = function(data)
		clearChildren(p.Body)
		for _, gun in GunData.List do
			local owned = data.OwnedGuns[gun.Id]
			local equipped = data.Gun == gun.Id
			local row = make("Frame", { Size = UDim2.new(1, 0, 0, 112), BackgroundColor3 = C.Card, LayoutOrder = gun.Order, Parent = p.Body }, {
				UIKit.corner(16),
				UIKit.stroke(if equipped then C.Accent else Color3.new(1, 1, 1), if equipped then 2 else 1, if equipped then 0.1 else 0.9),
			})
			local stage = make("Frame", { Size = UDim2.fromOffset(170, 96), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), Parent = row }, {
				UIKit.corner(12),
				UIKit.gradient(C.CardHi, C.PanelLo),
			})
			gunViewport(stage, gun, { Size = UDim2.fromScale(1, 1) })
			text(gun.Name, 19, F.Black, C.Text, { Position = UDim2.fromOffset(194, 12), Parent = row })
			local stats = make("Frame", { Size = UDim2.new(1, -380, 0, 56), Position = UDim2.fromOffset(194, 44), BackgroundTransparency = 1, Parent = row })
			statBar(stats, "Damage  " .. gun.Damage, gun.Damage / 4, 0)
			statBar(stats, string.format("Range  %d", gun.Range), gun.Range / 100, 18)
			statBar(stats, string.format("Reload  %.2fs", gun.Reload), 0.65 / gun.Reload, 36)

			local b
			local size, pos = UDim2.fromOffset(150, 46), UDim2.new(1, -166, 0.5, -23)
			if equipped then
				b = UIKit.button("Equipped", "disabled", { Size = size, Position = pos, Parent = row })
			elseif owned then
				b = UIKit.button("Equip", "primary", { Size = size, Position = pos, Parent = row })
			else
				local afford = data.Coins >= gun.Price
				local label
				b, label = UIKit.button("", if afford then "gold" else "disabled", { Size = size, Position = pos, Parent = row })
				label.Visible = false
				local price = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = b }, {
					UIKit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
				})
				icon("coin", 20, nil, { LayoutOrder = 1, Parent = price })
				text(Format.Number(gun.Price), 18, F.Black, if afford then C.Bg else C.Sub, { LayoutOrder = 2, Parent = price })
			end
			b.Activated:Connect(function()
				if equipped then
					return
				end
				local remote = if owned then Remotes.EquipGun else Remotes.BuyGun
				local ok, msg = remote:InvokeServer(gun.Id)
				UIController.Notify(msg, if ok then "success" else "error")
			end)
		end
	end
end

-- Index -------------------------------------------------------------------------------------------------
local function buildIndex()
	local p = makePanel(NAV[3], true)
	local grid = make("Frame", { Name = "Grid", Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = p.Body })
	make("UIGridLayout", { CellSize = UDim2.fromOffset(120, 166), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local track = make("Frame", { Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 0.5, -5), BackgroundColor3 = C.PanelLo, Parent = p.Footer }, { UIKit.round() })
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track }, { UIKit.round(), UIKit.gradient(C.Accent, C.Good, 0) })

	p.Refresh = function(data)
		clearChildren(grid)
		local found = 0
		for i, fish in FishData.Fish do
			local rarity = FishData.GetRarity(fish.Id)
			local best = data.Discovered[fish.Id]
			if best then
				found += 1
			end
			local zone = FishPath.ZoneByName[fish.Zone]
			local cell = make("Frame", { BackgroundColor3 = if best then C.Card else C.PanelLo, LayoutOrder = zone.Index * 100 + FishData.RarityIndex[fish.Rarity] * 10 + i, Parent = grid }, {
				UIKit.corner(16),
				UIKit.stroke(rarity.Color, 1, if best then 0.55 else 0.85),
				UIKit.pad(6, 6),
			})
			portrait(cell, fish.Id, best ~= nil, 74)
			text(if best then fish.Id else "???", 14, F.Black, if best then C.Text else C.Faint, {
				Size = UDim2.new(1, -4, 0, 18), Position = UDim2.fromOffset(2, 80), AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = cell,
			})
			UIKit.chip(string.upper(rarity.Name), rarity.Color, { Position = UDim2.fromOffset(2, 102), Parent = cell })
			text(if best then "Best " .. Format.Kg(best) else zone.Display, 12, F.Medium, C.Sub, {
				Size = UDim2.new(1, -4, 0, 16), Position = UDim2.fromOffset(2, 130), AutomaticSize = Enum.AutomaticSize.None,
				TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = cell,
			})
		end
		p.Subtitle.Text = string.format("%d of %d species discovered", found, #FishData.Fish)
		tween(fill, 0.5, { Size = UDim2.fromScale(math.max(found / #FishData.Fish, 0.02), 1) })
	end
end

-- Gear (air tank) ---------------------------------------------------------------------------------------
local function buildGear()
	local p = makePanel(NAV[4], true)
	p.Body.ScrollingEnabled = false
	p.Subtitle.Text = "A bigger tank lets you reach the deep zones"
	local hero = make("Frame", { Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = Color3.new(1, 1, 1), Parent = p.Body }, {
		UIKit.corner(18),
		UIKit.gradient(C.AccentDeep, C.Card, 0),
	})
	icon("bubbles", 64, C.Text, { Position = UDim2.fromOffset(26, 28), Parent = hero })
	text("AIR TANK", 13, F.Black, C.Accent, { Position = UDim2.fromOffset(112, 22), Parent = hero })
	local level = text("", 30, F.Black, C.Text, { Position = UDim2.fromOffset(112, 40), Parent = hero })
	local pips = make("Frame", { Size = UDim2.fromOffset(260, 10), Position = UDim2.fromOffset(114, 84), BackgroundTransparency = 1, Parent = hero }, {
		UIKit.list(Enum.FillDirection.Horizontal, 6),
	})
	local pipFrames = {}
	for i = 1, Config.Tank.MaxLevel do
		pipFrames[i] = make("Frame", { Size = UDim2.fromOffset(46, 8), BackgroundColor3 = C.PanelLo, LayoutOrder = i, Parent = pips }, { UIKit.round() })
	end
	local function statRow(y, glyph, label)
		local row = make("Frame", { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, y), BackgroundColor3 = C.Card, Parent = p.Body }, { UIKit.corner(14) })
		local badge = make("Frame", { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = C.PanelLo, Parent = row }, { UIKit.corner(10) })
		icon(glyph, 20, C.Accent, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = badge })
		text(label, 16, F.Bold, C.Sub, { Position = UDim2.fromOffset(60, 19), Parent = row })
		return text("", 18, F.Black, C.Text, { Position = UDim2.new(1, -18, 0, 17), AnchorPoint = Vector2.new(1, 0), RichText = true, Parent = row })
	end
	local airRow = statRow(134, "bubbles", "Air supply")
	local depthRow = statRow(204, "depth", "Safe round-trip depth")
	local upgrade, hiddenLabel = UIKit.button("", "gold", { Size = UDim2.fromScale(1, 1), Parent = p.Footer })
	hiddenLabel.Visible = false
	local priceRow = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = upgrade }, {
		UIKit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local upgradeText = text("Upgrade tank", 18, F.Black, C.Bg, { LayoutOrder = 1, Parent = priceRow })
	local priceIcon = icon("coin", 20, nil, { LayoutOrder = 2, Parent = priceRow })
	local priceText = text("", 18, F.Black, C.Bg, { LayoutOrder = 3, Parent = priceRow })
	upgrade.Activated:Connect(function()
		local ok, msg = Remotes.UpgradeTank:InvokeServer()
		UIController.Notify(msg, if ok then "success" else "error")
	end)

	p.Refresh = function(data)
		local lvl = data.TankLevel
		level.Text = "Level " .. lvl
		for i, pip in pipFrames do
			pip.BackgroundColor3 = if i <= lvl then C.Accent else C.PanelLo
		end
		local air = Config.Tank.Air[lvl]
		local maxed = lvl >= Config.Tank.MaxLevel
		airRow.Text = if maxed then air .. "s" else string.format('%ds  <font color="#38BDF8">→ %ds</font>', air, Config.Tank.Air[lvl + 1])
		-- Half the air down, half back up, swimming about 14 studs/s, 2 m per stud
		depthRow.Text = string.format("%dm", math.floor(air / 2 * 14 * 2))
		if maxed then
			UIKit.setVariant(upgrade, upgradeText, "disabled")
			upgradeText.Text = "Tank maxed out"
			priceIcon.Visible, priceText.Visible = false, false
		else
			local cost = Config.Tank.Costs[lvl]
			UIKit.setVariant(upgrade, upgradeText, if data.Coins >= cost then "gold" else "disabled")
			priceText.TextColor3 = upgradeText.TextColor3
			upgradeText.Text = "Upgrade tank"
			priceIcon.Visible, priceText.Visible = true, true
			priceText.Text = Format.Number(cost)
		end
	end
end

-- Catch popup ---------------------------------------------------------------------------------------------
function UIController.ShowCatch(info)
	local rarity = FishData.GetRarity(info.Id)
	local root = make("Frame", {
		Size = UDim2.fromOffset(480, 186),
		Position = UDim2.new(0.5, 0, 0, 170),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local scale = make("UIScale", { Scale = 0.3, Parent = root })
	local holder = make("Frame", { Size = UDim2.new(1, -20, 1, -20), Position = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, Parent = root })
	UIKit.shadow(holder, 22, 3, 0)
	local card = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 1, Parent = holder }, {
		UIKit.corner(22),
		UIKit.gradient(rarity.Color:Lerp(C.Panel, 0.62), C.PanelLo, 0),
	})
	local ring = make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2.5, Parent = card })
	local shimmer = make("UIGradient", { Color = ColorSequence.new(rarity.Color, Color3.new(1, 1, 1)), Parent = ring })
	fishViewport(card, info.Id, { Size = UDim2.fromOffset(190, 166), Position = UDim2.fromOffset(0, 0) })
	local tags = make("Frame", { Size = UDim2.fromOffset(260, 22), Position = UDim2.fromOffset(196, 26), BackgroundTransparency = 1, Parent = card }, {
		UIKit.list(Enum.FillDirection.Horizontal, 6),
	})
	if info.New then
		UIKit.chip("NEW", C.Good, { LayoutOrder = 1, Parent = tags })
	elseif info.Record then
		UIKit.chip("RECORD", C.Gold, { LayoutOrder = 1, Parent = tags })
	end
	UIKit.chip(string.upper(rarity.Name), rarity.Color, { LayoutOrder = 2, Parent = tags })
	text(info.Id, 32, F.Black, C.Text, { Position = UDim2.fromOffset(196, 54), Parent = card })
	local meta = make("Frame", { Size = UDim2.fromOffset(260, 26), Position = UDim2.fromOffset(198, 106), BackgroundTransparency = 1, Parent = card }, {
		UIKit.list(Enum.FillDirection.Horizontal, 14, nil, Enum.VerticalAlignment.Center),
	})
	text(Format.Kg(info.Kg), 18, F.Bold, C.Sub, { LayoutOrder = 1, Parent = meta })
	coinText(meta, info.Value, 18, 2)

	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	local spin = tween(shimmer, 3, { Rotation = 360 }, Enum.EasingStyle.Linear)
	task.delay(3, function()
		spin:Cancel()
		tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		root:Destroy()
	end)
end

function UIController.GetGui()
	return gui
end

-- HUD ---------------------------------------------------------------------------------------------------------
local function refreshAll(data)
	UIController.Data = data
	if not hasData then
		coinValue.Value = data.Coins
	else
		tween(coinValue, 0.5, { Value = data.Coins })
		if data.Coins > shownCoins then
			local pop = text("+" .. Format.Number(data.Coins - shownCoins), 20, F.Black, C.Gold, {
				Position = UDim2.new(0.5, 0, 1, 6), AnchorPoint = Vector2.new(0.5, 0), Parent = coinPill,
			})
			make("UIStroke", { Thickness = 1.5, Transparency = 0.5, Parent = pop })
			tween(pop, 0.9, { Position = UDim2.new(0.5, 0, 1, 30), TextTransparency = 1 })
			task.delay(0.9, function()
				pop:Destroy()
			end)
		end
	end
	shownCoins = data.Coins
	hasData = true
	bagLabel.Text = string.format("%d / %d", #data.Inventory, Config.InventoryCap)
	bagLabel.TextColor3 = if #data.Inventory >= Config.InventoryCap then C.Danger else C.Text
	for _, p in panels do
		if p.Root.Visible and p.Refresh then
			p.Refresh(data)
		end
	end
end

local function glassPill(width, parent, order)
	local holder = make("Frame", { Size = UDim2.fromOffset(width, 46), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	UIKit.shadow(holder, 23, 2, 0)
	local pill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.1, ZIndex = 1, Parent = holder }, {
		UIKit.round(),
		UIKit.stroke(Color3.new(1, 1, 1), 1, 0.86),
		UIKit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	return holder, pill
end

function UIController.Init()
	gui = make("ScreenGui", {
		Name = "SpearfishingUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local uiScale = make("UIScale", { Parent = gui })
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		uiScale.Scale = math.clamp(math.min(vp.X / 1366, vp.Y / 800), 0.55, 1.25)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- Top bar
	local top = make("Frame", { Size = UDim2.fromOffset(420, 46), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui }, {
		UIKit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center),
	})
	local coinHolder, coinBox = glassPill(176, top, 1)
	coinPill = coinHolder
	icon("coin", 26, nil, { LayoutOrder = 1, Parent = coinBox })
	coinsLabel = text("0", 22, F.Black, C.Gold, { LayoutOrder = 2, Parent = coinBox })
	coinValue.Changed:Connect(function(v)
		coinsLabel.Text = Format.Number(math.floor(v + 0.5))
	end)
	local _, bagBox = glassPill(150, top, 2)
	icon("fish", 24, C.Accent, { LayoutOrder = 1, Parent = bagBox })
	bagLabel = text("0 / " .. Config.InventoryCap, 20, F.Black, C.Text, { LayoutOrder = 2, Parent = bagBox })

	toastHolder = make("Frame", { Size = UDim2.fromOffset(700, 220), Position = UDim2.new(0.5, 0, 0, 70), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui }, {
		UIKit.list(nil, 8, Enum.HorizontalAlignment.Center),
	})

	hintFrame = make("Frame", {
		Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0.5, 0, 1, -190), AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.Bg, BackgroundTransparency = 0.3, Visible = false, Parent = gui,
	}, { UIKit.round(), UIKit.pad(0, 20), UIKit.stroke(Color3.new(1, 1, 1), 1, 0.9) })
	hintLabel = text("", 16, F.Bold, C.Text, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = hintFrame })

	-- Side navigation rail
	local railHolder = make("Frame", { Size = UDim2.fromOffset(84, 4 * 76 + 16), Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui })
	UIKit.shadow(railHolder, 24, 3, 0)
	local rail = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08, ZIndex = 1, Parent = railHolder }, {
		UIKit.corner(24),
		UIKit.stroke(Color3.new(1, 1, 1), 1, 0.88),
		UIKit.pad(8, 8),
		UIKit.list(nil, 4, Enum.HorizontalAlignment.Center),
	})
	buildBag()
	buildShop()
	buildIndex()
	buildGear()
	for i, nav in NAV do
		local b = make("TextButton", { Size = UDim2.fromOffset(68, 72), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = rail })
		local bg = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = b }, {
			UIKit.corner(16),
			UIKit.gradient(C.Accent, C.AccentDeep, 135),
		})
		local bar = make("Frame", { Size = UDim2.fromOffset(4, 0), Position = UDim2.new(0, -8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = C.Accent, Parent = b }, { UIKit.round() })
		local ic = icon(nav.Icon, 28, C.Sub, { Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), Parent = b })
		local icActive = icon(nav.Icon, 28, C.Bg, { Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = b })
		local label = text(string.upper(nav.Name), 11, F.Black, C.Sub, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.None, Parent = b })
		local key = make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -4, 0, 4), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = C.PanelLo, Parent = b }, { UIKit.corner(5) })
		text(nav.Key.Name, 10, F.Black, C.Faint, { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, Parent = key })
		b.MouseEnter:Connect(function()
			if openName ~= nav.Name then
				tween(bg, 0.12, { BackgroundTransparency = 0.85 })
			end
		end)
		b.MouseLeave:Connect(function()
			if openName ~= nav.Name then
				tween(bg, 0.12, { BackgroundTransparency = 1 })
			end
		end)
		UIKit.juice(b, 0.04)
		b.Activated:Connect(function()
			setOpen(if openName == nav.Name then nil else nav.Name)
		end)
		navButtons[nav.Name] = { Bg = bg, Bar = bar, Icon = ic, IconActive = icActive, Label = label }
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for _, nav in NAV do
			if input.KeyCode == nav.Key then
				setOpen(if openName == nav.Name then nil else nav.Name)
			end
		end
	end)

	Remotes.DataChanged.OnClientEvent:Connect(refreshAll)
	Remotes.Notify.OnClientEvent:Connect(UIController.Notify)
	Remotes.OpenPanel.OnClientEvent:Connect(function(name)
		if panels[name] then
			setOpen(name)
		end
	end)
	Remotes.Announce.OnClientEvent:Connect(function(name, fishId, rarityName, kg)
		UIController.Notify(string.format("%s speared a %s %s (%s)!", name, rarityName, fishId, Format.Kg(kg)), "success")
	end)
	task.spawn(function()
		local data = Remotes.GetData:InvokeServer()
		if data and not hasData then
			refreshAll(data)
		end
	end)
end

return UIController
