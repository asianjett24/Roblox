-- Design system for every menu: colours, type, buttons, surfaces with soft shadows,
-- and a small set of icons drawn from shapes (no emoji, so they look the same everywhere).
local TweenService = game:GetService("TweenService")

local UIKit = {}

local FAMILY = "rbxasset://fonts/families/BuilderSans.json"
UIKit.Font = {
	Black = Font.new(FAMILY, Enum.FontWeight.ExtraBold),
	Bold = Font.new(FAMILY, Enum.FontWeight.Bold),
	Medium = Font.new(FAMILY, Enum.FontWeight.Medium),
}

local rgb = Color3.fromRGB
UIKit.Color = {
	Bg = rgb(8, 17, 30),
	Panel = rgb(14, 26, 44),
	PanelLo = rgb(9, 18, 32),
	Card = rgb(22, 38, 62),
	CardHi = rgb(31, 52, 82),
	Text = rgb(236, 244, 252),
	Sub = rgb(138, 160, 190),
	Faint = rgb(84, 104, 134),
	Accent = rgb(56, 189, 248),
	AccentDeep = rgb(14, 116, 214),
	Good = rgb(52, 211, 153),
	GoodDeep = rgb(13, 148, 103),
	Gold = rgb(251, 191, 36),
	GoldDeep = rgb(217, 119, 6),
	Danger = rgb(248, 113, 113),
	DangerDeep = rgb(200, 40, 40),
	Muted = rgb(56, 72, 98),
}
local C = UIKit.Color

-- Basics ------------------------------------------------------------------------
function UIKit.make(class, props, children)
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end
local make = UIKit.make

function UIKit.corner(r)
	return make("UICorner", { CornerRadius = UDim.new(0, r or 12) })
end

function UIKit.round()
	return make("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function UIKit.stroke(color, thickness, transparency)
	return make("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 1,
		Transparency = transparency or 0.9,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.gradient(top, bottom, rotation)
	return make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 })
end

function UIKit.pad(vertical, horizontal)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, vertical),
		PaddingBottom = UDim.new(0, vertical),
		PaddingLeft = UDim.new(0, horizontal or vertical),
		PaddingRight = UDim.new(0, horizontal or vertical),
	})
end

function UIKit.list(dir, gap, hAlign, vAlign)
	return make("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
	})
end

-- Text label. size = pixel text size. Auto-sizes unless props.Size is given.
function UIKit.text(text, size, font, color, props)
	props = props or {}
	props.Text = text
	props.TextSize = size
	props.FontFace = font or UIKit.Font.Bold
	props.TextColor3 = color or C.Text
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	if props.Size == nil then
		props.AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.XY
		props.Size = UDim2.new()
	end
	return make("TextLabel", props)
end

function UIKit.tween(inst, time, goals, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

-- Soft drop shadow: stacked translucent layers behind a surface.
function UIKit.shadow(parent, radius, depth, zIndex)
	depth = depth or 3
	for i = depth, 1, -1 do
		make("Frame", {
			Name = "Shadow",
			Size = UDim2.new(1, i * 4, 1, i * 4),
			Position = UDim2.new(0.5, 0, 0.5, i * 2 + 2),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.82 + i * 0.04,
			ZIndex = zIndex or 0,
			Parent = parent,
		}, { make("UICorner", { CornerRadius = UDim.new(0, (radius or 12) + i * 2) }) })
	end
end

-- Hover / press feedback for any GuiButton.
function UIKit.juice(button: GuiButton, amount)
	amount = amount or 0.04
	local scale = button:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.14, { Scale = 1 + amount })
	end)
	button.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.14, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.08, { Scale = 1 - amount })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.14, { Scale = 1 + amount })
	end)
end

-- Buttons -------------------------------------------------------------------------
local VARIANTS = {
	primary = { C.Accent, C.AccentDeep, C.Bg },
	success = { C.Good, C.GoodDeep, C.Bg },
	gold = { C.Gold, C.GoldDeep, C.Bg },
	danger = { C.Danger, C.DangerDeep, C.Text },
	ghost = { C.CardHi, C.Card, C.Text },
	disabled = { C.Muted, C.Muted, C.Sub },
}

-- Returns button, label. Call UIKit.setVariant(button, label, name) to restyle later.
function UIKit.button(text, variant, props)
	props = props or {}
	props.Text = ""
	props.AutoButtonColor = false
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	local b = make("TextButton", props, { UIKit.corner(12) })
	make("UIGradient", { Name = "Fill", Rotation = 90, Parent = b })
	make("UIStroke", { Name = "Edge", Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.75, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	local label = UIKit.text(text, 17, UIKit.Font.Black, C.Bg, { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, Parent = b })
	UIKit.setVariant(b, label, variant or "primary")
	UIKit.juice(b, 0.03)
	return b, label
end

function UIKit.setVariant(button, label, variant)
	local v = VARIANTS[variant] or VARIANTS.primary
	button.Fill.Color = ColorSequence.new(v[1], v[2])
	label.TextColor3 = v[3]
	button.Edge.Transparency = if variant == "disabled" then 1 else 0.75
	button:SetAttribute("Variant", variant)
end

-- Small rounded tag, e.g. a rarity name.
function UIKit.chip(text, color, props)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(0, 22)
	props.AutomaticSize = Enum.AutomaticSize.X
	props.BackgroundColor3 = color
	props.BackgroundTransparency = 0.82
	local chip = make("Frame", props, { UIKit.round(), UIKit.pad(0, 9), UIKit.stroke(color, 1, 0.6) })
	UIKit.text(text, 12, UIKit.Font.Black, color, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = chip })
	return chip
end

-- Icons ------------------------------------------------------------------------------
-- Drawn on a 24x24 grid so they scale cleanly.
local function shape(parent, x, y, w, h, color, opts)
	opts = opts or {}
	local f = make("Frame", {
		Position = UDim2.fromScale((x + w / 2) / 24, (y + h / 2) / 24),
		Size = UDim2.fromScale(w / 24, h / 24),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = opts.transparency or 0,
		Rotation = opts.rotation or 0,
		ZIndex = opts.z or 1,
		BorderSizePixel = 0,
		Parent = parent,
	})
	if opts.round then
		make("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
	elseif opts.radius then
		make("UICorner", { CornerRadius = UDim.new(opts.radius / math.min(w, h), 0), Parent = f })
	end
	if opts.ring then
		f.BackgroundTransparency = 1
		make("UIStroke", { Color = color, Thickness = opts.ring, Parent = f })
	end
	return f
end

local ICONS = {}
function ICONS.bag(f, c, px)
	shape(f, 8, 2.5, 8, 9, c, { radius = 4, ring = px * 2 })
	shape(f, 3.5, 8, 17, 13.5, c, { radius = 3.5, z = 2 })
	shape(f, 3.5, 12.5, 17, 1.6, Color3.new(0, 0, 0), { transparency = 0.7, z = 3 })
	shape(f, 10, 14.5, 4, 3, Color3.new(0, 0, 0), { transparency = 0.7, radius = 1, z = 3 })
end
function ICONS.trident(f, c)
	shape(f, 11, 7, 2, 15, c, { radius = 1 })
	shape(f, 4.5, 8.5, 15, 2.2, c, { radius = 1.1 })
	shape(f, 4.5, 3, 2.2, 7, c, { radius = 1.1 })
	shape(f, 17.3, 3, 2.2, 7, c, { radius = 1.1 })
	shape(f, 11, 1.5, 2, 8, c, { radius = 1 })
	shape(f, 10, 20, 4, 3, c, { round = true })
end
function ICONS.book(f, c)
	shape(f, 2.5, 5, 9, 14.5, c, { radius = 2 })
	shape(f, 12.5, 5, 9, 14.5, c, { radius = 2 })
	for i, y in { 9, 12, 15 } do
		shape(f, 4.5, y, if i == 3 then 3.5 else 5, 1.3, Color3.new(0, 0, 0), { transparency = 0.6, z = 2 })
		shape(f, 14.5, y, if i == 1 then 3.5 else 5, 1.3, Color3.new(0, 0, 0), { transparency = 0.6, z = 2 })
	end
end
function ICONS.bubbles(f, c, px)
	shape(f, 2.5, 9, 12, 12, c, { round = true, ring = px * 2 })
	shape(f, 5, 11.5, 2.6, 2.6, c, { round = true })
	shape(f, 13, 3, 8, 8, c, { round = true, ring = px * 1.8 })
	shape(f, 16, 14, 5, 5, c, { round = true, ring = px * 1.6 })
end
function ICONS.fish(f, c)
	shape(f, 15, 7.5, 8, 8, c, { rotation = 45, radius = 1.5 })
	shape(f, 1.5, 6, 16, 11, c, { round = true, z = 2 })
	shape(f, 4.5, 9.5, 2.4, 2.4, Color3.new(0, 0, 0), { round = true, transparency = 0.35, z = 3 })
end
function ICONS.coin(f, c)
	local disc = shape(f, 1.5, 1.5, 21, 21, Color3.new(1, 1, 1), { round = true })
	make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 232, 140), Color3.fromRGB(232, 150, 30)), Rotation = 90, Parent = disc })
	make("UIStroke", { Color = Color3.fromRGB(180, 105, 15), Thickness = 1.5, Parent = disc })
	shape(f, 6.5, 6.5, 11, 11, Color3.fromRGB(255, 220, 110), { round = true, ring = 1.5, z = 2 })
	shape(f, 11, 8.5, 2, 7, Color3.fromRGB(190, 115, 20), { radius = 1, z = 2 })
end
function ICONS.close(f, c)
	shape(f, 11, 3, 2.2, 18, c, { rotation = 45, radius = 1.1 })
	shape(f, 11, 3, 2.2, 18, c, { rotation = -45, radius = 1.1 })
end
function ICONS.check(f, c)
	shape(f, 5.5, 12, 2.4, 8, c, { rotation = -45, radius = 1.2 })
	shape(f, 12.5, 4.5, 2.4, 15, c, { rotation = 40, radius = 1.2 })
end
function ICONS.alert(f, c)
	shape(f, 10.8, 3, 2.4, 12, c, { radius = 1.2 })
	shape(f, 10.6, 17.5, 2.8, 2.8, c, { round = true })
end
function ICONS.depth(f, c)
	shape(f, 11, 2, 2, 15, c, { radius = 1 })
	shape(f, 7.5, 12.5, 2.2, 9, c, { rotation = -45, radius = 1.1 })
	shape(f, 14.3, 12.5, 2.2, 9, c, { rotation = 45, radius = 1.1 })
end
function ICONS.target(f, c, px)
	shape(f, 3, 3, 18, 18, c, { round = true, ring = px * 2 })
	shape(f, 9.5, 9.5, 5, 5, c, { round = true })
end
function ICONS.spark(f, c)
	shape(f, 10.8, 2, 2.4, 20, c, { radius = 1.2 })
	shape(f, 2, 10.8, 20, 2.4, c, { radius = 1.2 })
	shape(f, 7, 7, 10, 10, c, { rotation = 45, radius = 2 })
end

function UIKit.icon(name, size, color, props)
	props = props or {}
	props.Size = UDim2.fromOffset(size, size)
	props.BackgroundTransparency = 1
	local f = make("Frame", props)
	local draw = ICONS[name]
	if draw then
		draw(f, color or C.Text, size / 24)
	end
	return f
end

return UIKit
