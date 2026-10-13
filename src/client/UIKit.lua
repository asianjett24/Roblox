-- Design kit, simulator style: chunky white text with ink outlines, 3D buttons with a darker
-- "lip" underneath, checkered pattern overlays, glossy shine, saturated rarity cards and
-- outlined sticker icons drawn from shapes.
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Font = {
	Title = Font.fromEnum(Enum.Font.FredokaOne),
	Black = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold),
	Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Medium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
}

local rgb = Color3.fromRGB
UIKit.Color = {
	Ink = rgb(22, 26, 48),
	Text = rgb(255, 255, 255),
	Sub = rgb(200, 220, 255),
	Faint = rgb(120, 140, 190),
	PanelTop = rgb(66, 152, 255),
	PanelBottom = rgb(38, 110, 232),
	Header = rgb(92, 178, 255),
	Well = rgb(30, 50, 104),
	WellLo = rgb(22, 38, 84),
	Card = rgb(46, 74, 140),
	Gold = rgb(255, 208, 60),
	Good = rgb(110, 220, 70),
	Danger = rgb(255, 84, 84),
	Accent = rgb(80, 190, 255),
	Pink = rgb(255, 96, 160),
	Orange = rgb(255, 150, 40),
	Purple = rgb(170, 100, 255),
	-- legacy names used by older code
	Bg = rgb(22, 38, 84),
	Panel = rgb(38, 110, 232),
	PanelLo = rgb(22, 38, 84),
	CardHi = rgb(60, 92, 170),
	Muted = rgb(120, 128, 150),
	GoodDeep = rgb(60, 160, 40),
	AccentDeep = rgb(30, 110, 230),
	DangerDeep = rgb(200, 40, 40),
	GoldDeep = rgb(230, 140, 20),
}
local C = UIKit.Color

-- Button colour sets: { top, bottom, lip }
UIKit.Swatch = {
	green = { rgb(140, 235, 70), rgb(70, 190, 40), rgb(40, 130, 30) },
	yellow = { rgb(255, 225, 70), rgb(255, 170, 20), rgb(200, 115, 10) },
	blue = { rgb(100, 200, 255), rgb(40, 135, 245), rgb(25, 85, 185) },
	red = { rgb(255, 110, 100), rgb(230, 50, 50), rgb(160, 30, 35) },
	pink = { rgb(255, 130, 190), rgb(240, 70, 140), rgb(170, 40, 100) },
	purple = { rgb(190, 130, 255), rgb(140, 80, 240), rgb(90, 50, 170) },
	orange = { rgb(255, 190, 80), rgb(255, 130, 30), rgb(190, 80, 15) },
	gray = { rgb(190, 196, 210), rgb(140, 146, 162), rgb(92, 98, 116) },
	navy = { rgb(70, 100, 170), rgb(44, 68, 130), rgb(26, 40, 86) },
}

-- Rarity card colours: { top, bottom }
UIKit.RarityColors = {
	Common = { rgb(170, 182, 204), rgb(118, 130, 156) },
	Uncommon = { rgb(130, 220, 90), rgb(60, 168, 60) },
	Rare = { rgb(90, 175, 255), rgb(40, 115, 235) },
	Epic = { rgb(190, 120, 255), rgb(130, 60, 225) },
	Legendary = { rgb(255, 200, 70), rgb(245, 130, 20) },
	Mythic = { rgb(255, 110, 170), rgb(220, 40, 100) },
}

-- Basics -----------------------------------------------------------------------------------
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
-- Thick ink outline around a frame
function UIKit.outline(thickness, color, transparency)
	return make("UIStroke", {
		Color = color or C.Ink,
		Thickness = thickness or 3,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end
UIKit.stroke = function(color, thickness, transparency)
	return UIKit.outline(thickness or 1, color or C.Ink, transparency or 0)
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
function UIKit.tween(inst, time, goals, style, dir)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goals)
	t:Play()
	return t
end

-- Text. Title-font text gets a thick ink outline automatically (the simulator look).
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
	local outline = props.Outline
	props.Outline = nil
	local label = make("TextLabel", props)
	if outline ~= false and (font == UIKit.Font.Title or outline) then
		make("UIStroke", { Color = C.Ink, Thickness = math.max(1.5, size / 9), LineJoinMode = Enum.LineJoinMode.Round, Parent = label })
	end
	return label
end

-- Checkered overlay (light squares) filling a frame. The frame should clip its children.
function UIKit.checker(parent, cell, transparency, color, w, h)
	cell = cell or 18
	local holder = make("Frame", { Name = "Checker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = parent.ZIndex, Parent = parent })
	-- Size of the area to cover: given, or the parent's pixel size, or a modest default
	w = w or (if parent.Size.X.Offset > 0 then parent.Size.X.Offset else parent.AbsoluteSize.X)
	h = h or (if parent.Size.Y.Offset > 0 then parent.Size.Y.Offset else parent.AbsoluteSize.Y)
	if w < 1 or h < 1 then
		w, h = 320, 140
	end
	local cols, rows = math.ceil(w / cell) + 1, math.ceil(h / cell) + 1
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			if (r + c) % 2 == 0 then
				make("Frame", {
					Size = UDim2.fromOffset(cell, cell),
					Position = UDim2.fromOffset(c * cell, r * cell),
					BackgroundColor3 = color or Color3.new(1, 1, 1),
					BackgroundTransparency = transparency or 0.9,
					BorderSizePixel = 0,
					ZIndex = parent.ZIndex,
					Parent = holder,
				})
			end
		end
	end
	return holder
end

-- Glossy highlight across the top half of a frame.
function UIKit.shine(parent, radius)
	return make("Frame", {
		Name = "Shine",
		Size = UDim2.new(1, -8, 0.45, 0),
		Position = UDim2.fromOffset(4, 3),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		ZIndex = parent.ZIndex,
		Parent = parent,
	}, {
		make("UICorner", { CornerRadius = UDim.new(0, radius or 10) }),
		make("UIGradient", { Transparency = NumberSequence.new(0.72, 0.97), Rotation = 90 }),
	})
end

-- Hover / press feedback for any GuiButton.
function UIKit.juice(button: GuiButton, amount)
	amount = amount or 0.05
	local scale = button:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.14, { Scale = 1 + amount }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.14, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.08, { Scale = 1 - amount })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.18, { Scale = 1 + amount }, Enum.EasingStyle.Back)
	end)
end

local clickSound
local function playClick()
	local SoundService = game:GetService("SoundService")
	if not clickSound then
		clickSound = Instance.new("Sound")
		clickSound.SoundId = "rbxasset://sounds/button.wav"
		clickSound.Volume = 0.35
		clickSound.Parent = SoundService
	end
	SoundService:PlayLocalSound(clickSound)
end

-- 3D button: a darker lip underneath, a gradient face with checker + shine, outlined title text.
-- Returns holder (position/size this), the clickable face, and the label.
function UIKit.button(text, swatch, props)
	props = props or {}
	local sw = UIKit.Swatch[swatch or "green"] or UIKit.Swatch.green
	local holder = make("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(140, 46),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = props.Parent,
	})
	local lip = make("Frame", { Name = "Lip", Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 5), BackgroundColor3 = sw[3], Parent = holder }, {
		UIKit.corner(12),
		UIKit.outline(3),
	})
	local face = make("Frame", { Name = "Face", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = holder }, {
		UIKit.corner(12),
		make("UIGradient", { Name = "Fill", Color = ColorSequence.new(sw[1], sw[2]), Rotation = 90 }),
		UIKit.outline(3),
	})
	local sz = props.Size or UDim2.fromOffset(140, 46)
	UIKit.checker(face, 14, 0.9, nil, if sz.X.Offset > 0 then sz.X.Offset else 220, if sz.Y.Offset > 0 then sz.Y.Offset else 56)
	UIKit.shine(face, 9)
	local label = UIKit.text(text, props.TextSize or 20, UIKit.Font.Title, C.Text, {
		Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 3, Parent = face,
	})
	local scale = make("UIScale", { Parent = holder })
	holder.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.14, { Scale = 1.05 }, Enum.EasingStyle.Back)
	end)
	holder.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.14, { Scale = 1 })
		UIKit.tween(face, 0.08, { Position = UDim2.fromOffset(0, 0) })
	end)
	holder.MouseButton1Down:Connect(function()
		UIKit.tween(face, 0.06, { Position = UDim2.fromOffset(0, 4) })
	end)
	holder.MouseButton1Up:Connect(function()
		UIKit.tween(face, 0.1, { Position = UDim2.fromOffset(0, 0) })
	end)
	holder.Activated:Connect(playClick)
	holder:SetAttribute("Swatch", swatch or "green")
	return holder, face, label
end

function UIKit.setSwatch(holder, swatch)
	local sw = UIKit.Swatch[swatch] or UIKit.Swatch.green
	holder.Lip.BackgroundColor3 = sw[3]
	holder.Face.Fill.Color = ColorSequence.new(sw[1], sw[2])
	holder:SetAttribute("Swatch", swatch)
end

-- Rounded "pill" tag with outline, e.g. rarity names.
function UIKit.chip(text, color, props)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(0, 22)
	props.AutomaticSize = Enum.AutomaticSize.X
	props.BackgroundColor3 = color
	local chip = make("Frame", props, { UIKit.round(), UIKit.pad(0, 9), UIKit.outline(2) })
	UIKit.text(text, 13, UIKit.Font.Title, C.Text, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Parent = chip })
	return chip
end

-- Saturated gradient card with checker pattern and outline.
function UIKit.card(top, bottom, props)
	props = props or {}
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	props.ClipsDescendants = true
	local card = make("Frame", props, {
		UIKit.corner(14),
		make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 120 }),
		UIKit.outline(3),
	})
	local sz = props.Size or UDim2.fromOffset(300, 140)
	UIKit.checker(card, 20, 0.92, nil, if sz.X.Offset > 0 then sz.X.Offset else 320, if sz.Y.Offset > 0 then sz.Y.Offset else 180)
	return card
end

-- Icons -------------------------------------------------------------------------------------
-- Sticker icons drawn on a 24x24 grid: two-tone fills, ink outlines, a white highlight.
local INK = C.Ink
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
	elseif opts.ink ~= false and opts.inkPx then
		make("UIStroke", { Color = INK, Thickness = opts.inkPx, Parent = f })
	end
	return f
end

local ICONS = {}
function ICONS.bag(f, c, px)
	local ink = px * 1.6
	shape(f, 7.5, 2, 9, 9, INK, { radius = 4.5, ring = px * 3.4 })
	shape(f, 8.2, 2.7, 7.6, 7.6, c, { radius = 3.8, ring = px * 1.6, z = 2 })
	shape(f, 3, 8, 18, 14, c, { radius = 4, inkPx = ink, z = 3 })
	shape(f, 3, 8, 18, 5, Color3.new(1, 1, 1), { radius = 4, transparency = 0.75, z = 4, ink = false })
	shape(f, 9, 13.5, 6, 4.5, Color3.new(0, 0, 0), { radius = 1.5, transparency = 0.7, z = 4, ink = false })
end
function ICONS.trident(f, c, px)
	local o = { radius = 1.2, inkPx = px * 1.4 }
	shape(f, 10.8, 6, 2.4, 16, c, o)
	shape(f, 4, 8.2, 16, 2.6, c, o)
	shape(f, 4, 2.5, 2.6, 8, c, o)
	shape(f, 17.4, 2.5, 2.6, 8, c, o)
	shape(f, 10.8, 1, 2.4, 9, c, o)
	shape(f, 9.6, 19.5, 4.8, 3.6, c, { round = true, inkPx = px * 1.4 })
end
function ICONS.book(f, c, px)
	shape(f, 2, 4.5, 10, 15.5, c, { radius = 2, inkPx = px * 1.5 })
	shape(f, 12, 4.5, 10, 15.5, Color3.new(1, 1, 1), { radius = 2, inkPx = px * 1.5 })
	for i, y in { 8.5, 11.5, 14.5 } do
		shape(f, 4, y, if i == 3 then 4 else 6, 1.4, Color3.new(1, 1, 1), { transparency = 0.3, z = 2, ink = false })
		shape(f, 14, y, if i == 1 then 4 else 6, 1.4, c, { transparency = 0.2, z = 2, ink = false })
	end
end
function ICONS.bubbles(f, c, px)
	shape(f, 2, 8.5, 13, 13, c, { round = true, inkPx = px * 1.6 })
	shape(f, 4.5, 11, 3.5, 3.5, Color3.new(1, 1, 1), { round = true, z = 2, ink = false })
	shape(f, 13, 2.5, 8.5, 8.5, c, { round = true, inkPx = px * 1.5 })
	shape(f, 14.6, 4.1, 2.4, 2.4, Color3.new(1, 1, 1), { round = true, z = 2, ink = false })
	shape(f, 16, 14, 5.5, 5.5, c, { round = true, inkPx = px * 1.4 })
end
function ICONS.fish(f, c, px)
	shape(f, 14.5, 7.5, 8.5, 8.5, c, { rotation = 45, radius = 1.5, inkPx = px * 1.5 })
	shape(f, 1.5, 5.5, 16, 12, c, { round = true, inkPx = px * 1.5, z = 2 })
	shape(f, 3, 6.5, 12, 4, Color3.new(1, 1, 1), { round = true, transparency = 0.7, z = 3, ink = false })
	shape(f, 4.5, 9.5, 3, 3, INK, { round = true, z = 3, ink = false })
end
function ICONS.coin(f)
	local disc = shape(f, 1.5, 1.5, 21, 21, Color3.new(1, 1, 1), { round = true, inkPx = 2 })
	make("UIGradient", { Color = ColorSequence.new(rgb(255, 236, 120), rgb(245, 160, 20)), Rotation = 90, Parent = disc })
	shape(f, 6, 6, 12, 12, rgb(255, 214, 80), { round = true, ring = 1.6, z = 2 })
	shape(f, 10.8, 8, 2.4, 8, rgb(200, 120, 15), { radius = 1.2, z = 2, ink = false })
	shape(f, 5, 4, 7, 4, Color3.new(1, 1, 1), { round = true, transparency = 0.5, z = 3, ink = false })
end
function ICONS.gem(f, c, px)
	shape(f, 5, 5, 14, 14, c, { rotation = 45, radius = 2, inkPx = px * 1.6 })
	shape(f, 8, 6.5, 6, 4, Color3.new(1, 1, 1), { rotation = 45, radius = 1, transparency = 0.45, z = 2, ink = false })
end
function ICONS.close(f, c, px)
	shape(f, 10.5, 2.5, 3, 19, c, { rotation = 45, radius = 1.5 })
	shape(f, 10.5, 2.5, 3, 19, c, { rotation = -45, radius = 1.5 })
end
function ICONS.plus(f, c)
	shape(f, 10.5, 4, 3, 16, c, { radius = 1.5 })
	shape(f, 4, 10.5, 16, 3, c, { radius = 1.5 })
end
function ICONS.check(f, c)
	shape(f, 5, 11.5, 3, 8, c, { rotation = -45, radius = 1.5 })
	shape(f, 12, 4, 3, 16, c, { rotation = 40, radius = 1.5 })
end
function ICONS.alert(f, c)
	shape(f, 10.5, 3, 3, 12, c, { radius = 1.5 })
	shape(f, 10.3, 17, 3.4, 3.4, c, { round = true })
end
function ICONS.depth(f, c)
	shape(f, 11, 2, 2.2, 15, c, { radius = 1 })
	shape(f, 7.5, 12.5, 2.4, 9, c, { rotation = -45, radius = 1.2 })
	shape(f, 14.1, 12.5, 2.4, 9, c, { rotation = 45, radius = 1.2 })
end
function ICONS.fin(f, c, px)
	shape(f, 4, 6, 16, 14, c, { rotation = 20, radius = 5, inkPx = px * 1.5 })
	for i = 0, 2 do
		shape(f, 8 + i * 4, 8, 1.4, 10, INK, { rotation = 20, transparency = 0.6, z = 2, ink = false })
	end
end
function ICONS.star(f, c, px)
	shape(f, 6, 6, 12, 12, c, { rotation = 45, radius = 1, inkPx = px * 1.4 })
	shape(f, 6, 6, 12, 12, c, { radius = 1, inkPx = px * 1.4, z = 2 })
end
function ICONS.shark(f, c, px)
	shape(f, 2, 9, 20, 9, c, { round = true, inkPx = px * 1.5 })
	shape(f, 9, 3, 7, 9, c, { rotation = 30, radius = 1, inkPx = px * 1.5, z = 0 })
	shape(f, 4, 11, 2.5, 2.5, INK, { round = true, z = 2, ink = false })
end
function ICONS.target(f, c, px)
	shape(f, 3, 3, 18, 18, c, { round = true, ring = px * 2.2 })
	shape(f, 9.5, 9.5, 5, 5, c, { round = true })
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
