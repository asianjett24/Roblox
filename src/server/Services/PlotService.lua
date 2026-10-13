-- Gives each player one of the pads as their plot and spawns them on it.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

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
		warn("[PlotService] No plots found. Tag each pad Model 'Plot' or put them in workspace.Plots (see README).")
	end
	return found
end

local function pivotOf(plot: Instance): CFrame
	if plot:IsA("Model") then
		return plot:GetPivot()
	elseif plot:IsA("BasePart") then
		return plot.CFrame
	end
	return CFrame.new()
end

local function spawnCFrame(plot: Instance): CFrame
	local marker = plot:FindFirstChild("Spawn", true)
	if marker and marker:IsA("BasePart") then
		return marker.CFrame + Vector3.new(0, 3, 0)
	end
	local cf, size
	if plot:IsA("Model") then
		cf, size = plot:GetBoundingBox()
	else
		cf, size = pivotOf(plot), (plot :: BasePart).Size
	end
	-- Stand on the pad's edge rather than in the hole.
	return CFrame.new(cf.Position + cf.LookVector * (size.Z * 0.35) + Vector3.new(0, size.Y / 2 + 3, 0), cf.Position)
end

local function setSign(plot: Instance, player: Player?)
	local adornee = plot:IsA("Model") and (plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart", true)) or plot
	local gui = plot:FindFirstChild("OwnerSign")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "OwnerSign"
		gui.Size = UDim2.fromOffset(220, 50)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 9, 0)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 120
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.3
		label.Parent = gui
		gui.Parent = plot
	end
	gui.Adornee = adornee
	gui.Label.Text = if player then player.DisplayName .. "'s Pond" else "Empty Plot"
end

function PlotService.GetPlot(player: Player)
	for plot, owner in ownerOf do
		if owner == player then
			return plot
		end
	end
	return nil
end

-- Returns the plot a part belongs to, if any.
function PlotService.PlotOfPart(part: Instance)
	for _, plot in plots do
		if part == plot or part:IsDescendantOf(plot) then
			return plot
		end
	end
	return nil
end

function PlotService.OwnerOf(plot: Instance): Player?
	return ownerOf[plot]
end

-- Fallback when the pad hole isn't a separate part: nearest plot within its own footprint.
function PlotService.PlotAtPosition(pos: Vector3)
	for _, plot in plots do
		local cf, size
		if plot:IsA("Model") then
			cf, size = plot:GetBoundingBox()
		elseif plot:IsA("BasePart") then
			cf, size = plot.CFrame, plot.Size
		end
		if cf then
			local rel = cf:PointToObjectSpace(pos)
			if math.abs(rel.X) <= size.X / 2 and math.abs(rel.Z) <= size.Z / 2 and math.abs(rel.Y) <= size.Y / 2 + 4 then
				return plot
			end
		end
	end
	return nil
end

local function assign(player: Player)
	for _, plot in plots do
		if not ownerOf[plot] then
			ownerOf[plot] = player
			plot:SetAttribute("OwnerUserId", player.UserId)
			setSign(plot, player)
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
		local function onCharacter(char: Model)
			local current = PlotService.GetPlot(player)
			if not current then
				return
			end
			local root = char:WaitForChild("HumanoidRootPart", 5)
			if root then
				task.wait() -- let the default spawn finish first
				char:PivotTo(spawnCFrame(current))
			end
		end
		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
		if not plot then
			warn("[PlotService] No free plot for", player.Name)
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
			end
		end
	end)
end

return PlotService
