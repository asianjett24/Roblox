-- Shared look for every menu: fonts, colours and small builder helpers.
local TweenService = game:GetService("TweenService")

local UIKit = {}

UIKit.Font = {
	Black = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold),
	Bold = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold),
	Medium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium),
}

UIKit.Color = {
	Bg = Color3.fromRGB(18, 24, 36),
	Panel = Color3.fromRGB(28, 36, 52),
	Card = Color3.fromRGB(38, 48, 68),
	CardHi = Color3.fromRGB(48, 60, 84),
	Text = Color3.fromRGB(242, 246, 252),
	Sub = Color3.fromRGB(150, 165, 192),
	Accent = Color3.fromRGB(64, 176, 255),
	Good = Color3.fromRGB(66, 196, 118),
	Gold = Color3.fromRGB(255, 206, 84),
	Danger = Color3.fromRGB(232, 84, 84),
	Muted = Color3.fromRGB(78, 88, 108),
}

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
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.88,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.gradient(top, bottom, rotation)
	return make("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 })
end

function UIKit.pad(all, sides)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, sides or all),
		PaddingRight = UDim.new(0, sides or all),
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

-- Text label with sensible defaults. size = pixel text size.
function UIKit.text(text, size, font, color, props)
	props = props or {}
	props.Text = text
	props.TextSize = size
	props.FontFace = font or UIKit.Font.Bold
	props.TextColor3 = color or UIKit.Color.Text
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

-- Bouncy hover / press feedback for any GuiButton.
function UIKit.juice(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale") or make("UIScale", { Parent = button })
	button.MouseEnter:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.tween(scale, 0.08, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.12, { Scale = 1.05 })
	end)
end

-- Solid pill button. Returns the button and its label.
function UIKit.button(text, color, props)
	props = props or {}
	props.Text = ""
	props.AutoButtonColor = false
	props.BackgroundColor3 = color or UIKit.Color.Accent
	local b = make("TextButton", props, {
		UIKit.corner(10),
		UIKit.gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
		UIKit.stroke(Color3.new(0, 0, 0), 1.5, 0.75),
	})
	local label = UIKit.text(text, 18, UIKit.Font.Black, UIKit.Color.Text, {
		Size = UDim2.fromScale(1, 1),
		AutomaticSize = Enum.AutomaticSize.None,
		Parent = b,
	})
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.7, Parent = label })
	UIKit.juice(b)
	return b, label
end

return UIKit
