-- The interface (simulator style): coin + bag counters, big 3D navigation buttons, and the
-- Bag / Shop / Index / Pearl Shop panels, plus toasts, the hint line, big "slam" words,
-- the carry banner and the catch popup with a live 3D creature.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureModels = require(Shared.CreatureModels)
local FishData = require(Shared.FishData)
local Format = require(Shared.Format)
local GunData = require(Shared.GunData)
local GunModels = require(Shared.GunModels)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)
local UIKit = require(script.Parent.Parent:WaitForChild("UIKit"))

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
local toastHolder, hintFrame, hintLabel, slamHolder, carryBanner, carryLabel
local coinsLabel, bagLabel, coinPill, bagPill
local coinValue = Instance.new("NumberValue")
local shownCoins, hasData = 0, false
local panelListeners = {}

local NAV = {
	{ Name = "Bag", Icon = "bag", Swatch = "green", Key = Enum.KeyCode.B, Title = "Fish Bag", IconColor = Color3.fromRGB(255, 196, 80) },
	{ Name = "Shop", Icon = "trident", Swatch = "orange", Key = Enum.KeyCode.V, Title = "Gear Shop", IconColor = Color3.fromRGB(230, 240, 255) },
	{ Name = "Index", Icon = "book", Swatch = "purple", Key = Enum.KeyCode.X, Title = "Sea Index", IconColor = Color3.fromRGB(255, 120, 120) },
	{ Name = "Store", Icon = "gem", Swatch = "pink", Key = Enum.KeyCode.P, Title = "Pearl Shop", IconColor = Color3.fromRGB(120, 230, 255) },
}

local function clearChildren(container)
	for _, c in container:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function coinRow(parent, amount, size, order, color)
	local row = make("Frame", { Size = UDim2.fromOffset(0, size + 6), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = order or 0, Parent = parent }, {
		UIKit.list(Enum.FillDirection.Horizontal, 5, nil, Enum.VerticalAlignment.Center),
	})
	icon("coin", size + 4, nil, { LayoutOrder = 1, Parent = row })
	local label = text(Format.Number(amount), size, F.Title, color or C.Text, { LayoutOrder = 2, Parent = row })
	return row, label
end

-- Live 3D previews --------------------------------------------------------------------------
local spinners = {}

local function viewport(parent, props)
	props = props or {}
	props.BackgroundTransparency = 1
	props.Ambient = Color3.fromRGB(170, 180, 200)
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

-- A creature in a ViewportFrame. Spins gently unless opts.Static is set (cheaper, for grids).
function UIController.CreatureViewport(parent, speciesId, opts, props)
	opts = opts or {}
	local vf, cam = viewport(parent, props)
	local rig = CreatureModels.Build(speciesId, { Mutation = opts.Mutation, Simple = opts.Static })
	rig.Model.Parent = vf
	local L = rig.L
	local dist = if rig.Kind == "flat" then 1.35 elseif rig.Kind == "squid" then 1.25 else 1.15
	cam.CFrame = CFrame.lookAt(Vector3.new(L * dist * 1.25, L * 0.35, -L * 0.2), Vector3.new(0, 0, L * 0.05))
	local phase, angle = math.random() * 6, math.random() * 3
	local parts, cframes = {}, {}
	local function pose(dt)
		phase += dt * 6
		angle += dt * 0.7
		table.clear(parts)
		table.clear(cframes)
		CreatureModels.Pose(rig, CFrame.Angles(0, math.sin(angle) * 0.6 + 0.35, 0), phase, 1, parts, cframes)
		for i, p in parts do
			p.CFrame = cframes[i]
		end
	end
	pose(0)
	if not opts.Static then
		spinners[vf] = pose
	end
	return vf
end

local function gunViewport(parent, gun, props)
	local vf, cam = viewport(parent, props)
	local model = GunModels.Build(gun, false)
	model.Parent = vf
	local center = Vector3.new(0, 0.5, -2.3)
	cam.CFrame = CFrame.lookAt(center + Vector3.new(8.5, 2.2, 0.5), center)
	local angle = math.random() * 6
	local function spin(dt)
		angle += dt * 0.9
		model:PivotTo(CFrame.new(center) * CFrame.Angles(0.15, math.sin(angle) * 0.5, 0) * CFrame.new(-center))
	end
	spin(0)
	spinners[vf] = spin
	return vf
end

local function onScreen(obj: GuiObject)
	local node = obj
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

-- Toasts, hint, slam words -------------------------------------------------------------------
function UIController.Notify(message: string, kind: string?)
	local swatch = if kind == "error" then "red" elseif kind == "success" then "green" else "blue"
	local glyph = if kind == "error" then "alert" elseif kind == "success" then "check" else "fish"
	local sw = UIKit.Swatch[swatch]
	local toast = make("Frame", { Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = Color3.new(1, 1, 1), Parent = toastHolder }, {
		UIKit.corner(14),
		make("UIGradient", { Color = ColorSequence.new(UIKit.Swatch.navy[1], UIKit.Swatch.navy[2]), Rotation = 90 }),
		UIKit.outline(3),
		make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 18) }),
		UIKit.list(Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center),
	})
	local badge = make("Frame", { Size = UDim2.fromOffset(28, 28), BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1, Parent = toast }, {
		UIKit.corner(10),
		make("UIGradient", { Color = ColorSequence.new(sw[1], sw[2]), Rotation = 90 }),
		UIKit.outline(2.5),
	})
	icon(glyph, 16, C.Text, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = badge })
	local label = text(message, 15, F.Title, C.Text, { LayoutOrder = 2, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = toast })
	label.AutomaticSize = Enum.AutomaticSize.XY
	make("UISizeConstraint", { MaxSize = Vector2.new(330, 200), Parent = label })
	local scale = make("UIScale", { Scale = 0.3, Parent = toast })
	tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		toast:Destroy()
	end)
	-- keep at most 4 toasts on screen
	local list = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(list, c)
		end
	end
	if #list > 4 then
		list[1]:Destroy()
	end
end

UIController.HintRaised = false -- true while the dive HUD is on screen
function UIController.SetHint(message: string?)
	hintFrame.Position = UDim2.new(0.5, 0, 1, if UIController.HintRaised then -152 else -82)
	if message then
		if hintLabel.Text ~= message then
			hintLabel.Text = message
		end
		hintFrame.Visible = true
	else
		hintFrame.Visible = false
	end
end

-- Big centre-screen word that slams in (RUN!, ESCAPED!, CHOMP!)
local slamToken = 0
UIController.SlamAt = -10
function UIController.Slam(word: string, color: Color3?, sub: string?)
	UIController.SlamAt = os.clock()
	slamToken += 1
	local token = slamToken
	clearChildren(slamHolder)
	local old = slamHolder:FindFirstChildOfClass("UIScale")
	if old then
		old:Destroy()
	end
	local label = text(word, 64, F.Title, color or C.Gold, { Size = UDim2.new(1, 0, 0, 74), AutomaticSize = Enum.AutomaticSize.None, Parent = slamHolder })
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Thickness = 6
	end
	if sub then
		text(sub, 21, F.Title, C.Text, { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 74), AutomaticSize = Enum.AutomaticSize.None, Parent = slamHolder })
	end
	local scale = make("UIScale", { Scale = 2.6, Parent = slamHolder })
	slamHolder.Rotation = -6
	tween(scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(slamHolder, 0.3, { Rotation = 0 }, Enum.EasingStyle.Back)
	task.delay(1.5, function()
		if token ~= slamToken then
			return
		end
		tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		if token == slamToken then
			scale:Destroy()
			clearChildren(slamHolder)
		end
	end)
end

-- Banner shown while you carry a catch
function UIController.SetCarry(item)
	if item then
		local rarity = FishData.GetRarity(item.Id)
		carryLabel.Text = string.format("CARRYING %s!  SWIM UP!", string.upper(FishData.FullName(item.Id, item.Size, item.Mut)))
		carryLabel.TextColor3 = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.55)
		carryBanner.Visible = true
	else
		carryBanner.Visible = false
	end
end

-- Coins burst out of a button and fly into the coin counter.
local fxGui
function UIController.CoinBurst(from: GuiObject, count: number?)
	if not fxGui or not coinPill then
		return
	end
	local a = from.AbsolutePosition + from.AbsoluteSize / 2
	local b = coinPill.AbsolutePosition + Vector2.new(24, coinPill.AbsoluteSize.Y / 2)
	local scale = UIController.Scale and UIController.Scale.Scale or 1
	for i = 1, count or 14 do
		local c = icon("coin", math.floor(34 * scale), nil, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(a.X, a.Y), Parent = fxGui })
		local spread = Vector2.new(math.random(-90, 90), math.random(-110, -20)) * scale
		local mid = a + spread
		tween(c, 0.28, { Position = UDim2.fromOffset(mid.X, mid.Y) }, Enum.EasingStyle.Quad)
		task.delay(0.28 + i * 0.03, function()
			tween(c, 0.45, { Position = UDim2.fromOffset(b.X, b.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.45)
			c:Destroy()
			local s = coinPill:FindFirstChildOfClass("UIScale")
			if s then
				s.Scale = 1.12
				tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
	end
end

-- Panels -------------------------------------------------------------------------------------
local PANEL_SCALE = 0.9 -- panels are drawn a little smaller so the game stays visible around them
local function setOpen(name: string?)
	openName = name
	for n, p in panels do
		local want = n == name
		if want and not p.Root.Visible then
			p.Root.Visible = true
			p.Scale.Scale = 0.7 * PANEL_SCALE
			tween(p.Scale, 0.35, { Scale = PANEL_SCALE }, Enum.EasingStyle.Back)
			if UIController.Data and p.Refresh then
				p.Refresh(UIController.Data)
			end
		elseif not want and p.Root.Visible then
			tween(p.Scale, 0.15, { Scale = 0.8 * PANEL_SCALE }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
				if openName ~= n then
					p.Root.Visible = false
				end
			end)
		end
	end
	for n, b in navButtons do
		b.Selected.Visible = n == name
	end
	for _, fn in panelListeners do
		task.spawn(fn, name)
	end
end
UIController.Open = setOpen

function UIController.IsPanelOpen(): boolean
	return openName ~= nil
end

function UIController.OpenPanelName(): string?
	return openName
end

function UIController.OnPanel(fn)
	table.insert(panelListeners, fn)
end

local PANEL_W, PANEL_H = 780, 540

local function makePanel(nav, footerH)
	footerH = footerH or 0
	local root = make("Frame", {
		Name = nav.Name, Size = UDim2.fromOffset(PANEL_W, PANEL_H), Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = gui,
	})
	local scale = make("UIScale", { Parent = root })
	-- frees the mouse while a panel is open, even in first person underwater
	make("TextButton", { Name = "Modal", Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Text = "", Modal = true, Parent = root })
	-- depth: a soft shadow and a dark slab under the panel
	UIKit.softShadow(root, 26, 16, 0.3)
	make("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, Parent = root }, { UIKit.corner(22) })
	local sw = UIKit.Swatch[nav.Swatch]
	local body = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = root }, {
		UIKit.corner(22),
		make("UIGradient", { Color = ColorSequence.new(C.PanelTop, C.PanelBottom), Rotation = 90 }),
		UIKit.outline(4),
	})
	-- header strip: the nav colour with a checker pattern
	local header = make("Frame", { Size = UDim2.new(1, -16, 0, 64), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = body }, {
		UIKit.corner(16),
		make("UIGradient", { Color = ColorSequence.new(sw[1], sw[2]), Rotation = 90 }),
		UIKit.outline(3),
	})
	UIKit.checker(header, 20, 0.88, nil, PANEL_W, 64)
	UIKit.shine(header, 12)
	local badge = make("Frame", { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(10, 8), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = header }, {
		UIKit.corner(12),
		make("UIGradient", { Color = ColorSequence.new(UIKit.Swatch.navy[1], UIKit.Swatch.navy[2]), Rotation = 90 }),
		UIKit.outline(3),
	})
	icon(nav.Icon, 34, nav.IconColor, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = badge })
	text(string.upper(nav.Title), 32, F.Title, C.Text, { Position = UDim2.fromOffset(70, 12), ZIndex = 3, Parent = header })
	local subtitle = text("", 18, F.Title, C.Text, { Position = UDim2.new(1, -72, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 3, Parent = header })
	local close, closeFace = UIKit.button("", "red", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -56, 0, 7), Parent = header })
	close.ZIndex = 4
	icon("close", 22, C.Text, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, Parent = closeFace })
	close.Activated:Connect(function()
		setOpen(nil)
	end)

	local well = make("Frame", { Name = "Well", Size = UDim2.new(1, -16, 1, -(90 + footerH)), Position = UDim2.fromOffset(8, 80), BackgroundColor3 = C.Well, Parent = body }, {
		UIKit.corner(16),
		UIKit.outline(3),
	})
	-- halftone dots in the well for texture (atlas texture, or little frames without it)
	local fade = UIKit.sprite("halftone_fade", {
		Size = UDim2.new(1, 0, 0, 220), Position = UDim2.new(0, 0, 1, 0), AnchorPoint = Vector2.new(0, 1),
		ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.new(0, 110, 1, 0), ImageTransparency = 0.88, Parent = well,
	}, nil)
	if fade then
		make("UICorner", { CornerRadius = UDim.new(0, 16), Parent = fade })
	else
		local dots = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true, Parent = well }, { UIKit.corner(16) })
		for r = 0, 8 do
			for c = 0, 30 do
				local s = 3 + (8 - r) * 0.7
				make("Frame", {
					Size = UDim2.fromOffset(s, s), Position = UDim2.fromOffset(c * 25 + (r % 2) * 12, r * 22 + 6), AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.93, BorderSizePixel = 0, Parent = dots,
				}, { UIKit.round() })
			end
		end
	end
	local bodyScroll = make("ScrollingFrame", {
		Name = "Body", Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, ScrollBarImageColor3 = C.Sub, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = well,
	}, { UIKit.pad(10, 10) })
	local footer
	if footerH > 0 then
		footer = make("Frame", { Size = UDim2.new(1, -24, 0, footerH - 14), Position = UDim2.new(0, 12, 1, -footerH + 2), BackgroundTransparency = 1, Parent = body })
	end
	local p = { Root = root, Scale = scale, Body = bodyScroll, Well = well, Footer = footer, Subtitle = subtitle, Header = header }
	panels[nav.Name] = p
	return p
end

local function emptyState(parent, glyph, title, sub)
	local holder = make("Frame", { Name = "Empty", Size = UDim2.new(1, 0, 0, 300), BackgroundTransparency = 1, LayoutOrder = 99, Parent = parent }, {
		UIKit.list(nil, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	icon(glyph, 96, C.Faint, { LayoutOrder = 1, Parent = holder })
	text(title, 30, F.Title, C.Text, { LayoutOrder = 2, Parent = holder })
	text(sub, 18, F.Bold, C.Sub, { LayoutOrder = 3, Parent = holder })
	return holder
end

-- Tabs row (pills). Returns a function that selects a tab by name, and the row.
local function tabs(parent, names, swatches, onSelect, icons)
	local row = make("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = parent }, {
		UIKit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center),
	})
	local buttons = {}
	local function select(name)
		for n, b in buttons do
			UIKit.setSwatch(b, if n == name then swatches[n] else "gray")
		end
		onSelect(name)
	end
	for i, n in names do
		local glyph = icons and icons[n]
		local width = if glyph then math.max(100, #n * 12 + 30) + 26 else math.max(112, #n * 13 + 34)
		local b, face, label = UIKit.button(n, "gray", { Size = UDim2.fromOffset(width, 40), LayoutOrder = i, TextSize = 18, Parent = row })
		if glyph then
			icon(glyph, 26, nil, { Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 4, Parent = face })
			label.Size = UDim2.new(1, -30, 1, 0)
			label.Position = UDim2.fromOffset(28, 0)
		end
		b.Activated:Connect(function()
			select(n)
		end)
		buttons[n] = b
	end
	return select, row
end

local function grid(parent, cell, order)
	local g = make("Frame", { Name = "Grid", Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order or 2, Parent = parent })
	make("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = g })
	return g
end

local function mutColor(mut)
	if not mut then
		return nil
	end
	return if mut.Color then mut.Color:Lerp(Color3.new(0, 0, 0), 0.25) else C.Pink
end

-- Bag ----------------------------------------------------------------------------------------
local ART_LIMIT = 24 -- cards with live 3D art (the rest get an icon)

local function fishCard(parent, item, order, withArt)
	local f = FishData.ById[item.Id]
	local rarity = FishData.GetRarity(item.Id)
	local rc = UIKit.RarityColors[rarity.Name]
	local card = UIKit.card(rc[1], rc[2], { Size = UDim2.fromOffset(170, 200), LayoutOrder = order, Parent = parent })
	local mut = item.Mut and FishData.MutationByName[item.Mut]
	-- soft glow behind the art so the creature pops off the card
	UIKit.sprite("glow", { Size = UDim2.fromOffset(180, 150), Position = UDim2.new(0.5, 0, 0, 72), AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 0.45, ZIndex = 2, Parent = card })
	if withArt then
		UIController.CreatureViewport(card, item.Id, { Static = true, Mutation = item.Mut }, { Size = UDim2.fromOffset(160, 100), Position = UDim2.fromOffset(5, 22), ZIndex = 2 })
	else
		local tint = if mut and mut.Color then mut.Color elseif mut and mut.Rainbow then Color3.fromHSV(math.random(), 0.7, 1) else f.Look.Body
		icon("fish", 84, tint, { Position = UDim2.new(0.5, 0, 0, 30), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 2, Parent = card })
	end
	text(item.Id, 18, F.Title, C.Text, { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 6), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = card })
	local chips = make("Frame", { Size = UDim2.new(1, -12, 0, 22), Position = UDim2.fromOffset(6, 116), BackgroundTransparency = 1, ZIndex = 3, Parent = card }, {
		UIKit.list(Enum.FillDirection.Horizontal, 4),
	})
	if item.Size and item.Size ~= "Normal" then
		UIKit.chip(string.upper(item.Size), Color3.fromRGB(60, 70, 110), { LayoutOrder = 1, ZIndex = 3, Parent = chips })
	end
	if mut then
		UIKit.chip(string.upper(item.Mut), mutColor(mut), { LayoutOrder = 2, ZIndex = 3, Parent = chips })
	end
	text(Format.Kg(item.Kg), 16, F.Title, C.Text, { Position = UDim2.fromOffset(10, 142), ZIndex = 3, Parent = card })
	local row = coinRow(card, FishData.GetValue(item.Id, item.Kg, item.Size, item.Mut), 18, 0, C.Gold)
	row.Position = UDim2.fromOffset(8, 166)
	row.ZIndex = 3
	return card
end

local function buildBag()
	local p = makePanel(NAV[1], 76)
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p.Body })
	local cards = grid(p.Body, UDim2.fromOffset(170, 200), 1)
	local summary = make("Frame", { Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, Parent = p.Footer }, {
		UIKit.list(Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center),
	})
	text("BAG VALUE", 22, F.Title, C.Text, { LayoutOrder = 1, Parent = summary })
	local _, totalLabel = coinRow(summary, 0, 26, 2, C.Gold)
	local sell = UIKit.button("SELL ALL", "green", { Size = UDim2.fromOffset(200, 54), Position = UDim2.new(1, -200, 0, 0), TextSize = 26, Parent = p.Footer })
	p.SellButton = sell
	sell.Activated:Connect(function()
		local ok, msg = Remotes.SellAll:InvokeServer()
		UIController.Notify(msg, if ok then "success" else "error")
		if ok then
			UIController.CoinBurst(sell, 16)
		end
	end)
	local lastKey = nil

	p.Refresh = function(data)
		-- only rebuild when the bag actually changed
		local key = #data.Inventory .. ":" .. tostring(data.Inventory[#data.Inventory] and data.Inventory[#data.Inventory].Kg)
		if key == lastKey and #cards:GetChildren() > 1 then
			return
		end
		lastKey = key
		clearChildren(cards)
		local items = table.clone(data.Inventory)
		table.sort(items, function(a, b)
			return FishData.GetValue(a.Id, a.Kg, a.Size, a.Mut) > FishData.GetValue(b.Id, b.Kg, b.Size, b.Mut)
		end)
		local total = 0
		for i, item in items do
			total += FishData.GetValue(item.Id, item.Kg, item.Size, item.Mut)
			fishCard(cards, item, i, i <= ART_LIMIT)
		end
		local empty = p.Body:FindFirstChild("Empty")
		cards.Visible = #items > 0
		if #items == 0 and not empty then
			emptyState(p.Body, "bag", "Your bag is empty", "Dive in, spear a creature and escape its guardian!")
		elseif #items > 0 and empty then
			empty:Destroy()
		end
		totalLabel.Text = Format.Number(total)
		local cap = if player:GetAttribute("BigBag") then 150 else Config.InventoryCap
		p.Subtitle.Text = string.format("%d / %d", #items, cap)
	end
end

-- Shop ---------------------------------------------------------------------------------------
local TIER_SWATCH = { "gray", "green", "blue", "purple", "orange", "pink" }

local function statLine(parent, label, value, y)
	text(label, 14, F.Title, C.Text, { Position = UDim2.fromOffset(12, y + 2), ZIndex = 3, TextTransparency = 0.15, Parent = parent })
	text(value, 18, F.Title, C.Text, { Position = UDim2.fromOffset(84, y), ZIndex = 3, Parent = parent })
end

local function buildShop()
	local p = makePanel(NAV[2])
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = p.Body })
	local content = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = p.Body })
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })
	local current = "SPEARGUNS"
	local select, tabRow = tabs(p.Body, { "SPEARGUNS", "UPGRADES" }, { SPEARGUNS = "orange", UPGRADES = "blue" }, function(name)
		current = name
		if UIController.Data then
			p.Refresh(UIController.Data)
		end
	end, { SPEARGUNS = "shop", UPGRADES = "flippers" })
	tabRow.LayoutOrder = 1

	local function gunsTab(data)
		local g = grid(content, UDim2.fromOffset(350, 176), 1)
		for _, gun in GunData.List do
			local owned = data.OwnedGuns[gun.Id]
			local equipped = data.Gun == gun.Id
			local sw = UIKit.Swatch[TIER_SWATCH[gun.Order]]
			local card = UIKit.card(sw[1], sw[2], { Size = UDim2.fromOffset(350, 176), LayoutOrder = gun.Order, Parent = g })
			text(gun.Name, 22, F.Title, C.Text, { Position = UDim2.fromOffset(12, 8), ZIndex = 3, Parent = card })
			gunViewport(card, gun, { Size = UDim2.fromOffset(190, 112), Position = UDim2.new(1, -194, 0, 14), ZIndex = 2 })
			statLine(card, "DAMAGE", tostring(gun.Damage), 44)
			statLine(card, "RANGE", tostring(gun.Range), 68)
			statLine(card, "RELOAD", string.format("%.2fs", gun.Reload), 92)
			local b
			local size, pos = UDim2.fromOffset(150, 42), UDim2.new(1, -160, 1, -54)
			if equipped then
				b = UIKit.button("EQUIPPED", "gray", { Size = size, Position = pos, Parent = card })
			elseif owned then
				b = UIKit.button("EQUIP", "blue", { Size = size, Position = pos, Parent = card })
			else
				b = UIKit.button("BUY", if data.Coins >= gun.Price then "green" else "gray", { Size = size, Position = pos, Parent = card })
				local price = coinRow(card, gun.Price, 20, 0, C.Gold)
				price.Position = UDim2.new(0, 12, 1, -46)
				price.ZIndex = 3
			end
			b.ZIndex = 3
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

	local function upgradeCard(data, which, levelKey, cfg, swatch, glyph, statName, values, unit, order)
		local level = data[levelKey] or 1
		local sw = UIKit.Swatch[swatch]
		local card = UIKit.card(sw[1], sw[2], { Size = UDim2.fromOffset(734, 170), LayoutOrder = order, Parent = content })
		local badge = make("Frame", { Size = UDim2.fromOffset(110, 110), Position = UDim2.fromOffset(18, 30), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = card }, {
			UIKit.corner(22),
			make("UIGradient", { Color = ColorSequence.new(UIKit.Swatch.navy[1], UIKit.Swatch.navy[2]), Rotation = 90 }),
			UIKit.outline(3),
		})
		UIKit.shine(badge, 18)
		icon(glyph, 78, C.Text, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = badge })
		text(string.upper(cfg.Name), 30, F.Title, C.Text, { Position = UDim2.fromOffset(146, 12), ZIndex = 3, Parent = card })
		text("LEVEL " .. level .. " / " .. cfg.MaxLevel, 18, F.Title, C.Text, { Position = UDim2.fromOffset(146, 50), ZIndex = 3, Parent = card })
		local pips = make("Frame", { Size = UDim2.fromOffset(320, 18), Position = UDim2.fromOffset(148, 80), BackgroundTransparency = 1, ZIndex = 3, Parent = card }, {
			UIKit.list(Enum.FillDirection.Horizontal, 6),
		})
		for i = 1, cfg.MaxLevel do
			make("Frame", { Size = UDim2.fromOffset(54, 16), BackgroundColor3 = if i <= level then C.Gold else UIKit.Swatch.navy[3], LayoutOrder = i, ZIndex = 3, Parent = pips }, {
				UIKit.round(),
				UIKit.outline(2),
			})
		end
		local maxed = level >= cfg.MaxLevel
		local statText = if maxed then string.format("%s  %s%s", statName, tostring(values[level]), unit)
			else string.format("%s  %s%s  >  %s%s", statName, tostring(values[level]), unit, tostring(values[level + 1]), unit)
		text(statText, 22, F.Title, C.Text, { Position = UDim2.fromOffset(146, 112), ZIndex = 3, Parent = card })
		if maxed then
			local b = UIKit.button("MAXED", "gray", { Size = UDim2.fromOffset(180, 56), Position = UDim2.new(1, -198, 0.5, -28), Parent = card })
			b.ZIndex = 3
		else
			local cost = cfg.Costs[level]
			local b, face = UIKit.button("", if data.Coins >= cost then "green" else "gray", { Size = UDim2.fromOffset(180, 56), Position = UDim2.new(1, -198, 0.5, -28), Parent = card })
			b.ZIndex = 3
			local row = coinRow(face, cost, 22, 0, C.Text)
			row.Position = UDim2.fromScale(0.5, 0.5)
			row.AnchorPoint = Vector2.new(0.5, 0.5)
			row.ZIndex = 4
			b.Activated:Connect(function()
				local ok, msg = Remotes.Upgrade:InvokeServer(which)
				UIController.Notify(msg, if ok then "success" else "error")
			end)
		end
	end

	p.Refresh = function(data)
		clearChildren(content)
		if current == "SPEARGUNS" then
			gunsTab(data)
			p.Subtitle.Text = "Hit harder, reach further"
		else
			upgradeCard(data, "Tank", "TankLevel", Config.Tank, "blue", "tank", "AIR", Config.Tank.Air, "s", 1)
			upgradeCard(data, "Fins", "FinLevel", Config.Fins, "green", "flippers", "SPEED", Config.Fins.Speed, "", 2)
			p.Subtitle.Text = "Outswim the guardians"
		end
	end
	UIController.ShopTab = select
	select("SPEARGUNS")
end

-- Index --------------------------------------------------------------------------------------
local function buildIndex()
	local p = makePanel(NAV[3], 64)
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p.Body })
	local zoneNames, zoneSwatch, zoneByLabel, zoneIcons = {}, {}, {}, {}
	local glyphs = { "sun", "coral", "angler", "tentacle", "serpent" }
	local palette = { "blue", "green", "purple", "navy", "pink" }
	for i, z in Zones.List do
		local label = string.upper(z.Name)
		table.insert(zoneNames, label)
		zoneSwatch[label] = palette[i]
		zoneByLabel[label] = z
		zoneIcons[label] = glyphs[i]
	end
	local currentZone = Zones.List[1]
	local cards = grid(p.Body, UDim2.fromOffset(170, 200), 2)
	local select, tabRow = tabs(p.Body, zoneNames, zoneSwatch, function(label)
		currentZone = zoneByLabel[label]
		if UIController.Data then
			p.Refresh(UIController.Data)
		end
	end, zoneIcons)
	tabRow.LayoutOrder = 1
	-- footer: progress for this zone + its reward
	local track = make("Frame", { Size = UDim2.new(0.58, 0, 0, 26), Position = UDim2.new(0, 0, 0.5, -13), BackgroundColor3 = C.WellLo, Parent = p.Footer }, { UIKit.round(), UIKit.outline(3) })
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track }, {
		UIKit.round(),
		UIKit.gradient(UIKit.Swatch.green[1], UIKit.Swatch.green[2]),
	})
	local progressText = text("", 17, F.Title, C.Text, { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 2, Parent = track })
	local rewardText = text("", 18, F.Title, C.Gold, { Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = p.Footer })

	-- Detail overlay
	local detail = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20, Parent = p.Well }, { UIKit.corner(16) })
	local detailCard
	local function closeDetail()
		detail.Visible = false
		if detailCard then
			detailCard:Destroy()
			detailCard = nil
		end
	end
	detail.Activated:Connect(closeDetail)
	local function openDetail(f, entry)
		closeDetail()
		detail.Visible = true
		local rarity = FishData.GetRarity(f.Id)
		local rc = UIKit.RarityColors[rarity.Name]
		detailCard = UIKit.card(rc[1], rc[2], { Size = UDim2.fromOffset(660, 340), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 21, Parent = detail })
		UIController.CreatureViewport(detailCard, f.Id, {}, { Size = UDim2.fromOffset(310, 270), Position = UDim2.fromOffset(10, 56), ZIndex = 22 })
		text(f.Id, 34, F.Title, C.Text, { Position = UDim2.fromOffset(16, 8), ZIndex = 23, Parent = detailCard })
		UIKit.chip(string.upper(rarity.Name), rc[2]:Lerp(Color3.new(0, 0, 0), 0.2), { Position = UDim2.fromOffset(340, 62), ZIndex = 23, Parent = detailCard })
		text(f.Blurb or "", 18, F.Bold, C.Text, { Size = UDim2.fromOffset(300, 50), Position = UDim2.fromOffset(340, 94), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23, Parent = detailCard })
		local lines = {
			"LIVES IN  " .. string.upper(Zones.ByName[f.Zone].Display),
			"CAUGHT  " .. entry.Count,
			"BEST  " .. Format.Kg(entry.Best),
		}
		for i, line in lines do
			text(line, 18, F.Title, C.Text, { Position = UDim2.fromOffset(340, 152 + (i - 1) * 26), ZIndex = 23, Parent = detailCard })
		end
		text("FOUND", 14, F.Title, C.Text, { Position = UDim2.fromOffset(340, 234), ZIndex = 23, Parent = detailCard })
		local found = make("Frame", { Size = UDim2.fromOffset(310, 76), Position = UDim2.fromOffset(340, 254), BackgroundTransparency = 1, ZIndex = 23, Parent = detailCard }, {
			make("UIGridLayout", { CellSize = UDim2.fromOffset(98, 22), CellPadding = UDim2.fromOffset(4, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for i, s in FishData.Sizes do
			local has = entry.Sizes and entry.Sizes[s.Name]
			local chip = UIKit.chip(string.upper(s.Name), if has then Color3.fromRGB(60, 70, 110) else Color3.fromRGB(40, 44, 60), { LayoutOrder = i, ZIndex = 23, Parent = found })
			if not has then
				chip.BackgroundTransparency = 0.5
			end
		end
		for i, m in FishData.Mutations do
			if entry.Muts and entry.Muts[m.Name] then
				UIKit.chip(string.upper(m.Name), mutColor(m), { LayoutOrder = 10 + i, ZIndex = 23, Parent = found })
			end
		end
		local back = UIKit.button("BACK", "red", { Size = UDim2.fromOffset(120, 42), Position = UDim2.new(1, -134, 0, 10), Parent = detailCard })
		back.ZIndex = 24
		back.Activated:Connect(closeDetail)
		local s = make("UIScale", { Scale = 0.6, Parent = detailCard })
		tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	end

	p.Refresh = function(data)
		clearChildren(cards)
		local total, found = 0, 0
		for i, f in FishData.Fish do
			if f.Zone == currentZone.Name then
				total += 1
				local entry = data.Discovered[f.Id]
				local rarity = FishData.GetRarity(f.Id)
				local rc = UIKit.RarityColors[rarity.Name]
				local top, bottom = rc[1], rc[2]
				if not entry then
					top, bottom = Color3.fromRGB(70, 80, 110), Color3.fromRGB(46, 54, 80)
				else
					found += 1
				end
				local card = UIKit.card(top, bottom, { Size = UDim2.fromOffset(170, 200), LayoutOrder = FishData.RarityIndex[f.Rarity] * 100 + i, Parent = cards })
				if entry then
					UIKit.sprite("glow", { Size = UDim2.fromOffset(180, 150), Position = UDim2.new(0.5, 0, 0, 76), AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 0.45, ZIndex = 2, Parent = card })
				end
				local vf = UIController.CreatureViewport(card, f.Id, { Static = true }, { Size = UDim2.fromOffset(160, 104), Position = UDim2.fromOffset(5, 24), ZIndex = 2 })
				if not entry then
					-- undiscovered: a dark silhouette
					vf.ImageColor3 = Color3.fromRGB(14, 18, 34)
					vf.Ambient = Color3.new(0, 0, 0)
					vf.LightColor = Color3.new(0, 0, 0)
				end
				text(if entry then f.Id else "???", 18, F.Title, C.Text, { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 6), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3, Parent = card })
				UIKit.chip(string.upper(rarity.Name), rc[2]:Lerp(Color3.new(0, 0, 0), 0.25), { Position = UDim2.fromOffset(8, 134), ZIndex = 3, Parent = card })
				text(if entry then ("x" .. entry.Count .. "   " .. Format.Kg(entry.Best)) else "NOT FOUND", 15, F.Title, C.Text, { Position = UDim2.fromOffset(10, 166), ZIndex = 3, Parent = card })
				if entry then
					local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = card })
					UIKit.juice(hit, 0.03)
					hit.Activated:Connect(function()
						openDetail(f, entry)
					end)
				end
			end
		end
		fill.Size = UDim2.fromScale(math.max(found / math.max(total, 1), 0.04), 1)
		progressText.Text = string.format("%s  %d / %d", string.upper(currentZone.Display), found, total)
		local reward = 1000 * currentZone.Index ^ 2
		rewardText.Text = if data.ZoneRewards[currentZone.Name] then "REWARD CLAIMED!" else ("FIND ALL: +" .. Format.Number(reward) .. " COINS")
		local all = 0
		for _ in data.Discovered do
			all += 1
		end
		p.Subtitle.Text = string.format("%d / %d found", all, #FishData.Fish)
	end
	select(zoneNames[1])
end

-- Pearl Shop (Robux) -------------------------------------------------------------------------
local function buildStore()
	local p = makePanel(NAV[4])
	p.Subtitle.Text = "Support the game!"
	make("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = p.Body })
	local function section(title, order)
		text(title, 26, F.Title, C.Text, { LayoutOrder = order, Parent = p.Body })
		return grid(p.Body, UDim2.fromOffset(350, 150), order + 1)
	end
	local function item(g, it, isPass, order, glyph)
		local card = UIKit.card(it.Color:Lerp(Color3.new(1, 1, 1), 0.2), it.Color:Lerp(Color3.new(0, 0, 0), 0.15), { Size = UDim2.fromOffset(350, 150), LayoutOrder = order, Parent = g })
		-- art: a big glossy sticker on a halo
		local halo = make("Frame", { Size = UDim2.fromOffset(104, 104), Position = UDim2.new(1, -116, 0, 10), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, ZIndex = 2, Parent = card }, { UIKit.round() })
		icon(glyph, 80, Color3.new(1, 1, 1), { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = halo })
		text(it.Name, 24, F.Title, C.Text, { Position = UDim2.fromOffset(12, 8), ZIndex = 3, Parent = card })
		local blurb = it.Blurb or (if it.Coins then ("+" .. Format.Number(it.Coins) .. " coins") else "")
		text(blurb, 16, F.Bold, C.Text, { Size = UDim2.fromOffset(210, 50), Position = UDim2.fromOffset(12, 42), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3, Parent = card })
		local owned = isPass and player:GetAttribute(it.Key)
		local label = if owned then "OWNED" else ("R$ " .. it.Price)
		local b = UIKit.button(label, if owned then "gray" else "green", { Size = UDim2.fromOffset(140, 44), Position = UDim2.new(0, 12, 1, -56), Parent = card })
		b.ZIndex = 3
		if it.Id == 0 and not owned then
			UIKit.chip("COMING SOON", Color3.fromRGB(40, 50, 90), { Position = UDim2.new(0, 162, 1, -44), ZIndex = 3, Parent = card })
		end
		b.Activated:Connect(function()
			if owned then
				return
			end
			if it.Id == 0 then
				UIController.Notify(it.Name .. " is coming soon!", "info")
			elseif isPass then
				MarketplaceService:PromptGamePassPurchase(player, it.Id)
			else
				MarketplaceService:PromptProductPurchase(player, it.Id)
			end
		end)
	end
	p.Refresh = function(data)
		clearChildren(p.Body)
		local passGrid = section("GAME PASSES", 1)
		for i, it in Config.Store.Passes do
			item(passGrid, it, true, i, ({ "crown", "coins", "sprint", "sack" })[i] or "gem")
		end
		local prodGrid = section("COINS & BOOSTS", 3)
		for i, it in Config.Store.Products do
			item(prodGrid, it, false, i, if it.Coins then ({ "coin", "coins", "chest" })[i] or "coins" else "bite")
		end
		if data and data.Repellent and data.Repellent > 0 then
			p.Subtitle.Text = "Repellent charges: " .. data.Repellent
		end
	end
end

-- Catch popup --------------------------------------------------------------------------------
UIController.CatchUntil = 0
function UIController.ShowCatch(info)
	UIController.CatchUntil = os.clock() + 3.9
	local rarity = FishData.GetRarity(info.Id)
	local rc = UIKit.RarityColors[rarity.Name]
	local root = make("Frame", { Size = UDim2.fromOffset(580, 236), Position = UDim2.fromScale(0.5, 0.63), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 8, Parent = gui })
	local scale = make("UIScale", { Scale = 0.2, Parent = root })
	UIKit.softShadow(root, 24, 14, 0.3)
	make("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, Parent = root }, { UIKit.corner(22) })
	local card = UIKit.card(rc[1], rc[2], { Size = UDim2.fromOffset(580, 236), Parent = root })
	-- rotating light rays behind the creature
	local rays = UIKit.sprite("burst", { Size = UDim2.fromOffset(330, 330), Position = UDim2.fromOffset(130, 118), AnchorPoint = Vector2.new(0.5, 0.5), ImageTransparency = 0.45, ZIndex = 2, Parent = card })
	if not rays then
		rays = make("Frame", { Size = UDim2.fromOffset(300, 300), Position = UDim2.fromOffset(130, 118), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2, Parent = card })
		for i = 0, 5 do
			make("Frame", { Size = UDim2.fromOffset(34, 300), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = i * 30, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 2, Parent = rays }, {
				make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90 }),
			})
		end
	end
	local stroke = card:FindFirstChildOfClass("UIStroke")
	local shimmer
	if stroke then
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Thickness = 4
		shimmer = make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.Ink), ColorSequenceKeypoint.new(0.5, rarity.Color:Lerp(Color3.new(1, 1, 1), 0.4)), ColorSequenceKeypoint.new(1, C.Ink) }), Parent = stroke })
	end
	UIController.CreatureViewport(card, info.Id, { Mutation = info.Mut }, { Size = UDim2.fromOffset(260, 210), Position = UDim2.fromOffset(4, 16), ZIndex = 3 })
	text(if info.Stolen then "STOLEN!" else "SECURED!", 24, F.Title, C.Gold, { Position = UDim2.fromOffset(280, 14), ZIndex = 4, Parent = card })
	text(FishData.FullName(info.Id, info.Size, info.Mut), 30, F.Title, C.Text, { Size = UDim2.fromOffset(290, 72), Position = UDim2.fromOffset(280, 42), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4, Parent = card })
	local tags = make("Frame", { Size = UDim2.fromOffset(290, 24), Position = UDim2.fromOffset(280, 120), BackgroundTransparency = 1, ZIndex = 4, Parent = card }, {
		UIKit.list(Enum.FillDirection.Horizontal, 6),
	})
	if info.New then
		UIKit.chip("NEW!", UIKit.Swatch.green[2], { LayoutOrder = 1, ZIndex = 4, Parent = tags })
	elseif info.Record then
		UIKit.chip("RECORD!", UIKit.Swatch.orange[2], { LayoutOrder = 1, ZIndex = 4, Parent = tags })
	end
	UIKit.chip(string.upper(rarity.Name), rc[2]:Lerp(Color3.new(0, 0, 0), 0.2), { LayoutOrder = 2, ZIndex = 4, Parent = tags })
	text(Format.Kg(info.Kg), 22, F.Title, C.Text, { Position = UDim2.fromOffset(282, 156), ZIndex = 4, Parent = card })
	local row = coinRow(card, info.Value, 26, 0, C.Gold)
	row.Position = UDim2.fromOffset(280, 188)
	row.ZIndex = 4
	tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local spinRays = tween(rays, 4, { Rotation = 180 }, Enum.EasingStyle.Linear)
	local spin = shimmer and tween(shimmer, 3.4, { Rotation = 360 }, Enum.EasingStyle.Linear)
	task.delay(3.6, function()
		spinRays:Cancel()
		if spin then
			spin:Cancel()
		end
		tween(scale, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		root:Destroy()
	end)
end

function UIController.GetGui()
	return gui
end

-- Things the tutorial points at
function UIController.GetAnchor(name: string): GuiObject?
	if name == "Coins" then
		return coinPill
	elseif name == "BagPill" then
		return bagPill
	elseif navButtons[name] then
		return navButtons[name].Button
	elseif name == "SellAll" then
		return panels.Bag and panels.Bag.SellButton
	elseif panels[name] then
		return panels[name].Root
	end
	return nil
end

-- HUD ----------------------------------------------------------------------------------------
local function refreshAll(data)
	UIController.Data = data
	if not hasData then
		coinValue.Value = data.Coins
	else
		tween(coinValue, 0.6, { Value = data.Coins })
		if data.Coins > shownCoins then
			local pop = text("+" .. Format.Number(data.Coins - shownCoins), 26, F.Title, C.Gold, { Position = UDim2.new(0.5, 0, 1, 6), AnchorPoint = Vector2.new(0.5, 0), Parent = coinPill })
			tween(pop, 1, { Position = UDim2.new(0.5, 0, 1, 40), TextTransparency = 1 })
			local st = pop:FindFirstChildOfClass("UIStroke")
			if st then
				tween(st, 1, { Transparency = 1 })
			end
			task.delay(1, function()
				pop:Destroy()
			end)
			local s = coinPill:FindFirstChildOfClass("UIScale")
			if s then
				s.Scale = 1.15
				tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
	end
	shownCoins = data.Coins
	hasData = true
	local cap = if player:GetAttribute("BigBag") then 150 else Config.InventoryCap
	bagLabel.Text = string.format("%d/%d", #data.Inventory, cap)
	bagLabel.TextColor3 = if #data.Inventory >= cap then C.Danger else C.Text
	for _, p in panels do
		if p.Root.Visible and p.Refresh then
			p.Refresh(data)
		end
	end
end

local function hudPill(width, parent, order)
	local holder = make("Frame", { Size = UDim2.fromOffset(width, 40), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
	make("UIScale", { Parent = holder })
	UIKit.softShadow(holder, 12, 8, 0.45)
	make("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.3, Parent = holder }, { UIKit.round() })
	local pill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = holder }, {
		UIKit.round(),
		make("UIGradient", { Color = ColorSequence.new(UIKit.Swatch.navy[1], UIKit.Swatch.navy[2]), Rotation = 90 }),
		UIKit.outline(3),
	})
	return holder, pill
end

function UIController.Init()
	gui = make("ScreenGui", { Name = "SpearfishingUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
	UIController.Root = gui
	-- Everything sits in a screen-sized frame scaled to the window (designed at 1400x820).
	local screen = make("Frame", { Name = "Screen", BackgroundTransparency = 1, Parent = gui })
	local uiScale = make("UIScale", { Parent = screen })
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(vp.X / 1400, vp.Y / 820), 0.5, 1.2)
		uiScale.Scale = s
		screen.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	gui = screen
	UIController.Scale = uiScale
	fxGui = make("ScreenGui", { Name = "CoinFX", ResetOnSpawn = false, DisplayOrder = 6, Parent = player:WaitForChild("PlayerGui") })

	-- Top bar: coins (+ opens the Pearl Shop) and bag
	local top = make("Frame", { Size = UDim2.fromOffset(340, 40), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Parent = gui }, {
		UIKit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center),
	})
	local coinHolder, coinBox = hudPill(180, top, 1)
	coinPill = coinHolder
	icon("coin", 34, nil, { Position = UDim2.new(0, -6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = coinBox })
	coinsLabel = text("0", 22, F.Title, C.Gold, { Size = UDim2.new(1, -72, 1, 0), Position = UDim2.fromOffset(32, 0), AutomaticSize = Enum.AutomaticSize.None, Parent = coinBox })
	coinValue.Changed:Connect(function(v)
		coinsLabel.Text = Format.Number(math.floor(v + 0.5))
	end)
	local plus, plusFace = UIKit.button("", "green", { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -36, 0.5, -18), Parent = coinBox })
	icon("plus", 18, C.Text, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = plusFace })
	plus.Activated:Connect(function()
		setOpen("Store")
	end)
	local bagHolder, bagBox = hudPill(132, top, 2)
	bagPill = bagHolder
	icon("bag", 32, nil, { Position = UDim2.new(0, -4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = bagBox })
	bagLabel = text("0/" .. Config.InventoryCap, 19, F.Title, C.Text, { Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(32, 0), AutomaticSize = Enum.AutomaticSize.None, Parent = bagBox })

	-- toasts stack down the right side so they never cover an open panel
	toastHolder = make("Frame", { Size = UDim2.fromOffset(380, 300), Position = UDim2.new(1, -14, 0, 60), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, ZIndex = 9, Parent = gui }, {
		UIKit.list(nil, 8, Enum.HorizontalAlignment.Right),
	})
	slamHolder = make("Frame", { Size = UDim2.fromOffset(900, 140), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 9, Parent = gui })

	-- Carry banner
	carryBanner = make("Frame", { Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 0, 58), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = gui }, {
		UIKit.round(),
		make("UIGradient", { Color = ColorSequence.new(UIKit.Swatch.red[1], UIKit.Swatch.red[2]), Rotation = 90 }),
		UIKit.outline(3),
		UIKit.pad(0, 22),
		UIKit.list(Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center),
	})
	icon("fish", 26, nil, { LayoutOrder = 1, Parent = carryBanner })
	carryLabel = text("", 17, F.Title, C.Text, { LayoutOrder = 2, Parent = carryBanner })
	local carryScale = make("UIScale", { Parent = carryBanner })
	task.spawn(function()
		local big = false
		while true do
			task.wait(0.35)
			if carryBanner.Visible then
				big = not big
				tween(carryScale, 0.3, { Scale = if big then 1.06 else 1 })
			end
		end
	end)

	hintFrame = make("Frame", {
		Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0.5, 0, 1, -82), AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = gui,
	}, {
		UIKit.round(),
		make("UIGradient", { Color = ColorSequence.new(UIKit.Swatch.navy[1], UIKit.Swatch.navy[2]), Rotation = 90 }),
		UIKit.outline(3),
		UIKit.pad(0, 22),
	})
	hintLabel = text("", 16, F.Title, C.Text, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = hintFrame })

	-- Big 3D navigation buttons
	local nav = make("Frame", { Size = UDim2.fromOffset(80, 4 * 76), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = gui }, {
		UIKit.list(nil, 10, Enum.HorizontalAlignment.Center),
	})
	buildBag()
	buildShop()
	buildIndex()
	buildStore()
	for i, n in NAV do
		local b, face = UIKit.button("", n.Swatch, { Size = UDim2.fromOffset(66, 66), LayoutOrder = i, Parent = nav })
		icon(n.Icon, 38, nil, { Position = UDim2.new(0.5, 0, 0, 5), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3, Parent = face })
		text(string.upper(n.Name), 13, F.Title, C.Text, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -19), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 3, Parent = face })
		local key = make("Frame", { Size = UDim2.fromOffset(19, 19), Position = UDim2.new(1, 5, 0, -6), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = C.Ink, ZIndex = 5, Parent = b }, { UIKit.corner(6) })
		text(n.Key.Name, 12, F.Title, C.Text, { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 6, Outline = false, Parent = key })
		-- white arrow pointing at the open panel
		local selected = make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, 12, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = b }, {
			UIKit.corner(3),
			UIKit.outline(3),
		})
		b.Activated:Connect(function()
			setOpen(if openName == n.Name then nil else n.Name)
		end)
		navButtons[n.Name] = { Button = b, Selected = selected }
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			if openName then
				setOpen(nil)
			end
			return
		end
		for _, n in NAV do
			if input.KeyCode == n.Key then
				setOpen(if openName == n.Name then nil else n.Name)
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
	Remotes.Announce.OnClientEvent:Connect(function(name, fullName, rarityName, kg)
		UIController.Notify(string.format("%s banked a %s %s (%s)!", name, rarityName, fullName, Format.Kg(kg)), "success")
	end)
	task.spawn(function()
		local data = Remotes.GetData:InvokeServer()
		if data and not hasData then
			refreshAll(data)
		end
	end)
end

return UIController
