-- Design kit, simulator style: chunky white outlined text, gradient boxes with ONE border in a
-- darker shade of their own colour (never a black outline plus a second rim), 3D buttons whose
-- lip is that same border colour, glossy shine, saturated rarity cards and sticker icons.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Atlas = require(script.Parent:WaitForChild("UIAtlas"))

local UIKit = {}

-- The UI texture atlas (assets/ui/ui_atlas.png) once it's uploaded and its ID is in Config.
-- Accepts 123456 or "rbxassetid://123456".
local atlasFailed = false
local failStatus = "unknown"
local activeId = 0
local function configId(): number
	return tonumber(string.match(tostring(Config.UIAtlasId or ""), "%d+")) or 0
end
local function atlasId(): number
	return if activeId > 0 then activeId else configId()
end

function UIKit.HasAtlas(): boolean
	return not atlasFailed and atlasId() > 0
end

-- Tries to load one image ID; true when Roblox delivered it.
local function tryLoad(id: number): boolean
	local ContentProvider = game:GetService("ContentProvider")
	local done, good = false, false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ "rbxassetid://" .. id }, function(_, status)
				good = status == Enum.AssetFetchStatus.Success
				failStatus = tostring(status)
			end)
		end)
		done = true
	end)
	local t = 0
	while not done and t < 4 do
		t += task.wait(0.1)
	end
	return good
end

-- Loads the atlas before the UI is built (a few seconds at most). The server turns a Decal ID
-- into its Image ID (a common mix-up), so that one is tried first. If nothing loads, the UI
-- uses colour emoji icons instead.
function UIKit.Preload()
	local id = configId()
	if id <= 0 then
		return
	end
	local t = 0
	while ReplicatedStorage:GetAttribute("UIAtlasImage") == nil and t < 2.5 do
		t += task.wait(0.1)
	end
	local candidates = {}
	local resolved = tonumber(ReplicatedStorage:GetAttribute("UIAtlasImage")) or 0
	if resolved > 0 and resolved ~= id then
		table.insert(candidates, resolved)
	end
	table.insert(candidates, id)
	for _, candidate in candidates do
		if tryLoad(candidate) then
			activeId = candidate
			return
		end
	end
	atlasFailed = true
	warn(string.format("[UI] Couldn't load the UI atlas image %d (%s). Using emoji icons instead. "
		.. "Check that it's the Image ID of assets/ui/ui_atlas.png (Asset Manager > Images > right-click > Copy Asset ID), "
		.. "that the place is published (File > Publish to Roblox), and give Roblox a few minutes to approve a new upload.", id, failStatus))
end

-- An ImageLabel showing one sprite from the atlas (nil if the atlas isn't set up).
function UIKit.sprite(name: string, props)
	local r = Atlas.Sprites[name]
	if not r or not UIKit.HasAtlas() then
		return nil
	end
	props = props or {}
	props.BackgroundTransparency = 1
	props.Image = "rbxassetid://" .. atlasId()
	props.ImageRectOffset = Vector2.new(r[1], r[2])
	props.ImageRectSize = Vector2.new(r[3], r[4])
	if r.Slice and not props.ScaleType then
		props.ScaleType = Enum.ScaleType.Slice
		props.SliceCenter = Rect.new(r.Slice[1], r.Slice[2], r.Slice[3], r.Slice[4])
	end
	return UIKit.make("ImageLabel", props)
end

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
-- Borders made by UIKit.outline() without a colour take a darker shade of the box they're on.
local autoStrokes = setmetatable({}, { __mode = "k" })

local function lum(c: Color3): number
	return c.R * 0.3 + c.G * 0.59 + c.B * 0.11
end

-- A darker, richer shade of a colour (borders, lips, text outlines on coloured boxes).
function UIKit.deep(c: Color3, k: number?): Color3
	return c:Lerp(Color3.fromRGB(10, 14, 38), k or 0.55)
end

-- Top and bottom colour of a box's fill (its gradient times its background colour).
function UIKit.fillColors(inst): (Color3, Color3)
	local base = inst.BackgroundColor3
	for _, ch in inst:GetChildren() do
		if ch:IsA("UIGradient") and ch.Color then
			local kps = ch.Color.Keypoints
			local a, b = kps[1].Value, kps[#kps].Value
			return Color3.new(a.R * base.R, a.G * base.G, a.B * base.B), Color3.new(b.R * base.R, b.G * base.G, b.B * base.B)
		end
	end
	return base, base
end

-- Recolours a box's automatic border to a deep shade of the box's own colour.
function UIKit.hue(inst, stroke)
	stroke = stroke or inst:FindFirstChildOfClass("UIStroke")
	if not stroke or not autoStrokes[stroke] or not inst:IsA("GuiObject") then
		return
	end
	local top, bottom = UIKit.fillColors(inst)
	local dark = if lum(top) < lum(bottom) then top else bottom
	if inst.BackgroundTransparency >= 0.9 or lum(dark) > 0.85 then
		stroke.Color = Color3.fromRGB(22, 26, 48)
	else
		stroke.Color = UIKit.deep(dark, 0.5)
	end
end

function UIKit.make(class, props, children)
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	local auto
	for _, child in children or {} do
		child.Parent = inst
		if autoStrokes[child] then
			auto = child
		end
	end
	if auto then
		UIKit.hue(inst, auto)
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
-- One border around a box. Without a colour it takes a deep shade of the box's own colour
-- (set when the box is made with UIKit.make, or by calling UIKit.hue(box)).
function UIKit.outline(thickness, color, transparency)
	local stroke = make("UIStroke", {
		Color = color or C.Ink,
		Thickness = if color then thickness or 3 else math.min(thickness or 3, 3),
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
	if not color then
		autoStrokes[stroke] = true
	end
	return stroke
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

-- Title text that always fits its box: shrinks (down to 8 px) instead of spilling out.
function UIKit.fitText(text, maxSize, color, props)
	props = props or {}
	props.AutomaticSize = Enum.AutomaticSize.None
	props.TextScaled = true
	local label = UIKit.text(text, maxSize, UIKit.Font.Title, color, props)
	make("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 8, Parent = label })
	return label
end

-- Halftone dot overlay (from the atlas) filling a frame, rounded to match it.
function UIKit.halftone(parent, transparency, cell, radius, color, name)
	cell = cell or 22
	local img = UIKit.sprite(name or "halftone", {
		Name = "Halftone",
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(cell * 8, cell * 8),
		ImageTransparency = transparency or 0.86,
		ImageColor3 = color or Color3.new(1, 1, 1),
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
	if img and radius then
		UIKit.make("UICorner", { CornerRadius = UDim.new(0, radius), Parent = img })
	end
	return img
end

-- Soft drop shadow behind a frame (atlas) for depth. Parent it to the frame's holder.
function UIKit.softShadow(parent, spread, offsetY, transparency)
	spread = spread or 14
	return UIKit.sprite("shadow", {
		Name = "SoftShadow",
		Size = UDim2.new(1, spread * 2, 1, spread * 2),
		Position = UDim2.new(0, -spread, 0, -spread + (offsetY or 8)),
		ImageTransparency = transparency or 0.35,
		ZIndex = 0,
		Parent = parent,
	})
end

-- Checkered overlay (light squares) filling a frame. The frame should clip its children.
-- With the atlas set up this becomes a halftone dot pattern instead.
function UIKit.checker(parent, cell, transparency, color, w, h)
	if UIKit.HasAtlas() then
		local corner = parent:FindFirstChildOfClass("UICorner")
		local r = if corner then corner.CornerRadius.Offset else 0
		if corner and corner.CornerRadius.Scale > 0 then
			r = 999
		end
		return UIKit.halftone(parent, math.clamp((transparency or 0.9) - 0.03, 0.6, 0.95), (cell or 18) * 0.75, r, color)
	end
	-- without the atlas: no pattern (a grid of squares looked busy); the gradient carries the box
	if true then
		return make("Frame", { Name = "Checker", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = parent.ZIndex, Parent = parent })
	end
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
	local g = UIKit.sprite("gloss", {
		Name = "Shine",
		Size = UDim2.new(1, -6, 0.6, 0),
		Position = UDim2.fromOffset(3, 2),
		ImageTransparency = 0.25,
		ZIndex = parent.ZIndex,
		Parent = parent,
	})
	if g then
		UIKit.make("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = g })
		return g
	end
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

-- 3D button: a gradient face with one border in a deep shade of its colour, sitting on a lip
-- of that same shade (so border and lip read as one shape), plus a soft top shine.
-- Returns holder (position/size this), the clickable face, and the label.
local function paintButton(holder, sw)
	local edge = UIKit.deep(sw[3], 0.25)
	holder.Lip.BackgroundColor3 = edge
	holder.Lip.UIStroke.Color = edge
	holder.Face.Fill.Color = ColorSequence.new(sw[1], sw[2])
	holder.Face.UIStroke.Color = edge
	local label = holder.Face:FindFirstChild("Label")
	local ls = label and label:FindFirstChildOfClass("UIStroke")
	if ls then
		ls.Color = UIKit.deep(sw[3], 0.5)
	end
end

function UIKit.button(text, swatch, props)
	props = props or {}
	local sw = UIKit.Swatch[swatch or "green"] or UIKit.Swatch.green
	local sz = props.Size or UDim2.fromOffset(140, 46)
	local small = sz.Y.Offset > 0 and sz.Y.Offset < 40
	local radius = if small then 9 else 12
	local depth = if small then 3 else 4
	local holder = make("TextButton", {
		Name = props.Name or "Button",
		Size = sz,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = props.Parent,
	})
	make("Frame", { Name = "Lip", Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, depth), BackgroundColor3 = sw[3], Parent = holder }, {
		UIKit.corner(radius),
		make("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }),
	})
	local face = make("Frame", { Name = "Face", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, Parent = holder }, {
		UIKit.corner(radius),
		make("UIGradient", { Name = "Fill", Color = ColorSequence.new(sw[1], sw[2]), Rotation = 90 }),
		make("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }),
	})
	UIKit.checker(face, 14, 0.92, nil, if sz.X.Offset > 0 then sz.X.Offset else 220, if sz.Y.Offset > 0 then sz.Y.Offset else 56)
	UIKit.shine(face, radius - 3)
	local label = UIKit.text(text, props.TextSize or 20, UIKit.Font.Title, C.Text, {
		Name = "Label", Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), AutomaticSize = Enum.AutomaticSize.None, ZIndex = 3, Parent = face,
	})
	if text ~= "" then
		label.TextScaled = true
		make("UITextSizeConstraint", { MaxTextSize = props.TextSize or 20, MinTextSize = 8, Parent = label })
	end
	paintButton(holder, sw)
	local scale = make("UIScale", { Parent = holder })
	holder.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.14, { Scale = 1.05 }, Enum.EasingStyle.Back)
	end)
	holder.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.14, { Scale = 1 })
		UIKit.tween(face, 0.08, { Position = UDim2.fromOffset(0, 0) })
	end)
	holder.MouseButton1Down:Connect(function()
		UIKit.tween(face, 0.06, { Position = UDim2.fromOffset(0, depth - 1) })
	end)
	holder.MouseButton1Up:Connect(function()
		UIKit.tween(face, 0.1, { Position = UDim2.fromOffset(0, 0) })
	end)
	holder.Activated:Connect(playClick)
	holder:SetAttribute("Swatch", swatch or "green")
	return holder, face, label
end

function UIKit.setSwatch(holder, swatch)
	paintButton(holder, UIKit.Swatch[swatch] or UIKit.Swatch.green)
	holder:SetAttribute("Swatch", swatch)
end

-- Rounded "pill" tag with outline, e.g. rarity names.
function UIKit.chip(text, color, props)
	props = props or {}
	props.Size = props.Size or UDim2.fromOffset(0, 22)
	props.AutomaticSize = Enum.AutomaticSize.X
	props.BackgroundColor3 = color
	local chip = make("Frame", props, { UIKit.round(), UIKit.pad(0, 9), UIKit.outline(1.5) })
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
		UIKit.outline(2.5),
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

-- Old icon names -> atlas sprite names, and each icon's own colour when none is given.
local SPRITE = {
	bag = "bag", trident = "shop", shop = "shop", book = "book", bubbles = "bubbles", fish = "fish", coin = "coin", gem = "pearl",
	close = "close", plus = "plus", check = "check", alert = "alert", depth = "down", fin = "flippers", star = "crown",
	shark = "shark", target = "fin",
}
local TINT = {
	bag = rgb(255, 176, 90), shop = rgb(255, 214, 110), book = rgb(255, 120, 120), pearl = rgb(140, 230, 255),
	coin = rgb(255, 205, 60), coins = rgb(255, 205, 60), gem = rgb(120, 230, 255), fish = rgb(255, 150, 70),
	fishes = rgb(110, 200, 255), shark = rgb(175, 190, 210), fin = rgb(120, 200, 255), bubbles = rgb(130, 225, 255),
	flippers = rgb(110, 225, 120), tank = rgb(255, 196, 70), helmet = rgb(240, 180, 90), plus = rgb(255, 255, 255),
	check = rgb(255, 255, 255), alert = rgb(255, 210, 70), crown = rgb(255, 210, 60), sprint = rgb(120, 210, 255),
	sack = rgb(215, 165, 105), chest = rgb(235, 170, 80), dash = rgb(180, 240, 255), trophy = rgb(255, 205, 60),
	lock = rgb(185, 195, 215), sun = rgb(255, 215, 80), coral = rgb(255, 125, 150), angler = rgb(130, 150, 255),
	tentacle = rgb(235, 95, 115), serpent = rgb(185, 110, 255), dragon = rgb(170, 110, 255), sparkles = rgb(255, 240, 150),
	help = rgb(255, 255, 255), bite = rgb(255, 120, 110), tag = rgb(120, 230, 160), star = rgb(255, 220, 90),
	close = rgb(255, 255, 255), down = rgb(120, 210, 255),
}
UIKit.IconTint = TINT
-- Without the atlas, picture icons use colour emoji (they look far better than shapes);
-- simple symbols (coin, plus, close, check, arrows, bubbles) keep the drawn versions.
local EMOJI = {
	bag = "🎒", trident = "🔱", shop = "🛒", book = "📖", gem = "💎", pearl = "💎", fish = "🐟", fishes = "🐠",
	shark = "🦈", bite = "🦈", fin = "🏊", flippers = "🏊", star = "👑", crown = "👑", sack = "💰", coins = "💰",
	chest = "🎁", trophy = "🏆", lock = "🔒", sun = "☀️", coral = "🐚", angler = "🐡", tentacle = "🐙",
	serpent = "🐉", dragon = "🐉", sparkles = "✨", dash = "💨", sprint = "⚡", help = "❓", alert = "⚠️",
	tag = "🏷️", helmet = "🌊",
}
-- Without the atlas, newer icon names are drawn with the closest shape icon.
local FALLBACK = {
	crown = "star", coins = "coin", sprint = "fin", sack = "bag", chest = "coin", bite = "shark", pearl = "gem",
	flippers = "fin", tank = "bubbles", helmet = "depth", down = "depth", trophy = "star", lock = "alert", dash = "fin",
	fishes = "fish", shop = "trident", tentacle = "shark", serpent = "fish", dragon = "fish", sun = "star", coral = "star",
	angler = "fish", sparkles = "star", help = "alert", tag = "coin",
}

function UIKit.icon(name, size, color, props)
	props = props or {}
	local spriteName = SPRITE[name] or name
	if UIKit.HasAtlas() and Atlas.Sprites[spriteName] then
		-- sprites have some padding around the drawing, so draw them a little bigger
		props.Size = UDim2.fromOffset(size * 1.25, size * 1.25)
		if not props.AnchorPoint then
			props.Position = (props.Position or UDim2.new()) + UDim2.fromOffset(-size * 0.125, -size * 0.125)
		end
		props.ImageColor3 = color or TINT[spriteName] or Color3.new(1, 1, 1)
		local img = UIKit.sprite(spriteName, props)
		if img then
			return img
		end
	end
	local emoji = EMOJI[name]
	if emoji then
		props.Size = UDim2.fromOffset(size, size)
		props.BackgroundTransparency = 1
		props.Text = emoji
		props.TextSize = math.floor(size * 0.86)
		props.TextScaled = false
		props.FontFace = UIKit.Font.Bold
		props.TextColor3 = Color3.new(1, 1, 1)
		return make("TextLabel", props)
	end
	props.Size = UDim2.fromOffset(size, size)
	props.BackgroundTransparency = 1
	local f = make("Frame", props)
	local draw = ICONS[name] or ICONS[FALLBACK[name] or ""]
	if draw then
		draw(f, color or C.Text, size / 24)
	end
	return f
end

return UIKit
