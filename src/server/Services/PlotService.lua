-- Gives each player one of the bases, spawns them on it, paints their name on its sign,
-- and tells clients which fish to show in its aquarium.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local FishData = require(Shared.FishData)
local DataService = require(script.Parent.DataService)

local PlotService = {}

local plots: { Instance } = {}
local ownerOf: { [Instance]: Player } = {}

local function findPlots()
	local found = CollectionService:GetTagged(Config.PlotTag)
	if #found == 0 then
		local folder = workspace:FindFirstChild(Config.PlotFolderName)
		if folder then
			found = folder:GetChildren()
		end
	end
	if #found == 0 then
		warn("[PlotService] No plots found. Run map/BuildMap.lua in the Command Bar (see README).")
	end
	table.sort(found, function(a, b)
		return (a:GetAttribute("BaseIndex") or 0) < (b:GetAttribute("BaseIndex") or 0)
	end)
	return found
end

local function mainPart(plot: Instance): BasePart?
	if plot:IsA("BasePart") then
		return plot
	end
	return (plot :: Model).PrimaryPart or plot:FindFirstChildWhichIsA("BasePart", true)
end

local function spawnCFrame(plot: Instance): CFrame
	local marker = plot:FindFirstChild("Spawn", true)
	if marker and marker:IsA("BasePart") then
		return marker.CFrame + Vector3.new(0, 4, 0)
	end
	local part = mainPart(plot)
	return (part and part.CFrame or CFrame.new()) + Vector3.new(0, 5, 0)
end

local SIGN_FONT = Font.fromEnum(Enum.Font.LuckiestGuy)

-- Paints the owner's headshot and name onto the plot's "Sign" board (both faces).
local function paintSign(part: BasePart, player: Player?, index: number?)
	for _, old in part:GetChildren() do
		if old:IsA("SurfaceGui") then
			old:Destroy()
		end
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.4
		gui.Parent = part

		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.FontFace = SIGN_FONT
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.fromRGB(255, 236, 190)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(60, 38, 22)
		stroke.Thickness = 2.5
		stroke.Parent = nameLabel

		if player then
			local photo = Instance.new("ImageLabel")
			photo.Size = UDim2.fromScale(0.26, 0.8)
			photo.Position = UDim2.fromScale(0.04, 0.1)
			photo.BackgroundColor3 = Color3.fromRGB(60, 38, 22)
			photo.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId)
			photo.Parent = gui
			local aspect = Instance.new("UIAspectRatioConstraint")
			aspect.Parent = photo
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = photo
			nameLabel.Size = UDim2.fromScale(0.62, 0.7)
			nameLabel.Position = UDim2.fromScale(0.34, 0.15)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Text = player.DisplayName
		else
			nameLabel.Size = UDim2.fromScale(0.9, 0.62)
			nameLabel.Position = UDim2.fromScale(0.05, 0.08)
			nameLabel.Text = if index then "BASE " .. index else "FREE BASE"
			local sub = Instance.new("TextLabel")
			sub.BackgroundTransparency = 1
			sub.Size = UDim2.fromScale(0.9, 0.26)
			sub.Position = UDim2.fromScale(0.05, 0.68)
			sub.FontFace = SIGN_FONT
			sub.TextScaled = true
			sub.TextColor3 = Color3.fromRGB(150, 230, 140)
			sub.Text = "FREE"
			sub.Parent = gui
		end
		nameLabel.Parent = gui
	end
end

local function setSign(plot: Instance, player: Player?)
	local index = plot:GetAttribute("BaseIndex")
	local board = plot:FindFirstChild("Sign", true)
	if board and board:IsA("BasePart") then
		paintSign(board, player, index)
		return
	end
	-- No sign board on this plot: fall back to a floating label.
	local gui = plot:FindFirstChild("OwnerSign")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "OwnerSign"
		gui.Size = UDim2.fromOffset(240, 56)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
		gui.MaxDistance = 200
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = SIGN_FONT
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
		gui.Parent = plot
	end
	gui.Adornee = mainPart(plot)
	gui.Label.Text = if player then player.DisplayName .. "'s Base" else (if index then "Base " .. index else "Free Base")
end

-- Tank ----------------------------------------------------------------------
-- The client draws the owner's best fish swimming in their aquarium from this attribute.
local function updateTank(player: Player, data)
	local plot = PlotService.GetPlot(player)
	if not plot then
		return
	end
	local items = table.clone(data.Inventory)
	table.sort(items, function(a, b)
		return FishData.GetValue(a.Id, a.Kg) > FishData.GetValue(b.Id, b.Kg)
	end)
	local ids = {}
	for i = 1, math.min(#items, Config.TankMaxFish) do
		table.insert(ids, items[i].Id)
	end
	plot:SetAttribute("TankFish", table.concat(ids, ","))
end

-- Public API ----------------------------------------------------------------
function PlotService.GetPlot(player: Player)
	for plot, owner in ownerOf do
		if owner == player then
			return plot
		end
	end
	return nil
end

function PlotService.OwnerOf(plot: Instance): Player?
	return ownerOf[plot]
end

local function assign(player: Player)
	for _, plot in plots do
		if not ownerOf[plot] then
			ownerOf[plot] = player
			plot:SetAttribute("OwnerUserId", player.UserId)
			setSign(plot, player)
			local data = DataService.Get(player)
			if data then
				task.defer(updateTank, player, data)
			end
			return plot
		end
	end
	return nil
end

function PlotService.Init()
	plots = findPlots()
	for _, plot in plots do
		setSign(plot, nil)
	end

	local function onPlayer(player: Player)
		local plot = assign(player)
		if not plot then
			warn("[PlotService] No free base for", player.Name)
		end
		local function onCharacter(char: Model)
			local current = PlotService.GetPlot(player)
			if not current then
				return
			end
			if char:WaitForChild("HumanoidRootPart", 5) then
				task.wait() -- let the default spawn finish first
				char:PivotTo(spawnCFrame(current))
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		for plot, owner in ownerOf do
			if owner == player then
				ownerOf[plot] = nil
				plot:SetAttribute("OwnerUserId", nil)
				setSign(plot, nil)
				plot:SetAttribute("TankFish", nil)
			end
		end
	end)
	DataService.OnChanged:Connect(updateTank)
end

return PlotService
