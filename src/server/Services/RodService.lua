-- Builds the fishing rod Tool. Uses your imported rod model when there is one
-- (see Config.Rod), otherwise builds a rod out of parts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RodData = require(ReplicatedStorage.Shared.RodData)
local DataService = require(script.Parent.DataService)

local RodService = {}

local template: Tool? = nil -- built once from the imported model

local function newHandle(cf: CFrame)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = cf
	return handle
end

local function attach(handle: BasePart, part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
end

local function findAsset()
	for _, container in { ServerStorage, ReplicatedStorage, workspace } do
		for _, name in Config.Rod.ModelNames do
			local found = container:FindFirstChild(name)
			if found and (found:IsA("Model") or found:IsA("BasePart")) then
				return found
			end
		end
	end
	return nil
end

-- Turns the imported model into a ready-to-clone Tool.
local function buildTemplate(asset: Instance): Tool?
	local model: Model
	if asset:IsA("Model") then
		model = asset:Clone()
	else
		model = Instance.new("Model")
		asset:Clone().Parent = model
	end
	if asset:IsDescendantOf(workspace) then
		asset.Parent = ServerStorage -- don't leave the original standing in the map
	end

	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		elseif d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	if #parts == 0 then
		warn("[RodService] Rod model has no parts, using the built-in rod")
		return nil
	end

	-- Scale so the longest side is Config.Rod.Length
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest <= 0 then
		return nil
	end
	model:ScaleTo(model:GetScale() * Config.Rod.Length / longest)
	local box, boxSize = model:GetBoundingBox()

	-- The rod runs along the longest axis; the reel sticks out along the second longest.
	local dims = { { boxSize.X, box.XVector }, { boxSize.Y, box.YVector }, { boxSize.Z, box.ZVector } }
	table.sort(dims, function(a, b)
		return a[1] > b[1]
	end)
	local length, axis, side = dims[1][1], dims[1][2], dims[2][2]

	-- Volume-weighted centre: the butt (grip + reel) is the heavy end.
	local total, along, across = 0, 0, 0
	for _, p in parts do
		local v = p.Size.X * p.Size.Y * p.Size.Z
		local offset = p.Position - box.Position
		total += v
		along += v * offset:Dot(axis)
		across += v * offset:Dot(side)
	end
	along /= total
	across /= total
	local toTip
	if math.abs(along) > length * 0.01 then
		toTip = if along > 0 then -axis else axis
	else
		toTip = if axis.Y >= 0 then axis else -axis -- assume it was modelled standing up
	end
	if Config.Rod.Flip then
		toTip = -toTip
	end
	local reelDir = if across < 0 then -side else side

	local butt = box.Position - toTip * (length / 2)
	local tip = box.Position + toTip * (length / 2)
	local grip = butt + toTip * (length * Config.Rod.GripAt)
	-- Handle frame: +Y runs up the rod, -Z points at the reel (it hangs under the rod).
	local up = toTip
	local back = -(reelDir - up * reelDir:Dot(up)).Unit
	local right = up:Cross(back)
	local handleCF = CFrame.fromMatrix(grip, right, up, back) * CFrame.Angles(0, math.rad(Config.Rod.Spin), 0)

	local tool = Instance.new("Tool")
	local handle = newHandle(handleCF)
	handle.Parent = tool
	for _, p in parts do
		attach(handle, p)
	end
	model.Name = "RodModel"
	model.Parent = tool
	local tipAtt = Instance.new("Attachment")
	tipAtt.Name = "Tip"
	tipAtt.Position = handleCF:PointToObjectSpace(tip)
	tipAtt.Parent = handle
	return tool
end

-- A rod made of parts, for when there is no imported model.
local function buildFallback(rod): Tool
	local tool = Instance.new("Tool")
	local handle = newHandle(CFrame.new())
	handle.Parent = tool

	local function piece(name, size, cf, color, material, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		attach(handle, p)
		p.Parent = tool
		return p
	end
	local function upright(name, d, h, y, color, material)
		return piece(name, Vector3.new(h, d, d), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
	end
	local metal = Color3.fromRGB(170, 172, 180)
	upright("ButtCap", 0.42, 0.2, -1.0, Color3.fromRGB(40, 40, 45))
	upright("Grip", 0.38, 1.8, 0, Color3.fromRGB(196, 156, 108), Enum.Material.Sand)
	upright("ReelSeat", 0.3, 0.8, 1.3, metal, Enum.Material.Metal)
	upright("Blank", 0.22, 2.2, 2.8, rod.Color)
	upright("Blank", 0.17, 2.2, 5.0, rod.Color)
	upright("Blank", 0.12, 2.0, 7.1, rod.Color)
	-- Spinning reel hanging under the rod (-Z)
	piece("ReelFoot", Vector3.new(0.12, 0.5, 0.35), CFrame.new(0, 1.3, -0.3), metal, Enum.Material.Metal)
	piece("ReelSpool", Vector3.new(0.5, 0.7, 0.7), CFrame.new(0, 1.3, -0.75), Color3.fromRGB(60, 62, 70), Enum.Material.Metal, Enum.PartType.Cylinder)
	piece("ReelHandle", Vector3.new(0.5, 0.1, 0.1), CFrame.new(0.45, 1.3, -0.75), metal, Enum.Material.Metal)
	piece("ReelKnob", Vector3.new(0.18, 0.18, 0.18), CFrame.new(0.72, 1.3, -0.6), Color3.fromRGB(40, 40, 45), nil, Enum.PartType.Ball)
	for i, y in { 2.4, 3.9, 5.3, 6.6, 7.9 } do
		local s = 0.16 - i * 0.015
		piece("Guide", Vector3.new(s, s, s), CFrame.new(0, y, -0.14), metal, Enum.Material.Metal)
	end
	local tipAtt = Instance.new("Attachment")
	tipAtt.Name = "Tip"
	tipAtt.Position = Vector3.new(0, 8.1, -0.05)
	tipAtt.Parent = handle
	return tool
end

local function buildTool(rod)
	local tool
	if template then
		tool = template:Clone()
	else
		tool = buildFallback(rod)
	end
	tool.Name = rod.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click the water to cast"
	tool:SetAttribute("RodId", rod.Id)
	tool.Grip = CFrame.Angles(math.rad(Config.Rod.Tilt), 0, 0)
	-- Fancy rods sparkle at the tip
	if rod.Order >= 4 then
		local tip = tool.Handle:FindFirstChild("Tip")
		if tip then
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Color = ColorSequence.new(rod.Color)
			sparkle.LightEmission = 1
			sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
			sparkle.Lifetime = NumberRange.new(0.4, 0.8)
			sparkle.Rate = 6
			sparkle.Speed = NumberRange.new(0.5, 1.5)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Parent = tip
		end
	end
	return tool
end

function RodService.Give(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local rod = RodData.ById[data.Rod] or RodData.ById.Basic
	for _, container in { player:FindFirstChild("Backpack"), player.Character } do
		if container then
			for _, item in container:GetChildren() do
				if item:IsA("Tool") and item:GetAttribute("RodId") then
					item:Destroy()
				end
			end
		end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		buildTool(rod).Parent = backpack
	end
end

function RodService.Init()
	local asset = findAsset()
	if asset then
		local ok, result = pcall(buildTemplate, asset)
		if ok and result then
			template = result
			print("[RodService] Using rod model:", asset.Name)
		else
			warn("[RodService] Couldn't use rod model, using the built-in rod:", result)
		end
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			DataService.WaitFor(player)
			player:WaitForChild("Backpack")
			RodService.Give(player)
		end)
		if player.Character then
			task.spawn(function()
				DataService.WaitFor(player)
				RodService.Give(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayer, p)
	end
end

return RodService
