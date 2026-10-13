-- Speargun model, shared so the server can hand out Tools and the shop can show previews.
-- Every gun is the same shape; GunData decides colours, materials and band colour.
-- Model space: the pistol grip (Handle) is at the origin and the barrel points down -Z.
local GunModels = {}

local RUBBER = Color3.fromRGB(38, 38, 44)
local STEEL = Color3.fromRGB(196, 202, 212)
local BARREL_Y = 0.62
local SPEAR_Y = 0.9

local FACES = { "TopSurface", "BottomSurface", "FrontSurface", "BackSurface", "LeftSurface", "RightSurface" }

-- asTool = true: a Tool with welded, unanchored parts (for players).
-- asTool = false: a Model of anchored parts (for shop previews).
function GunModels.Build(gun, asTool: boolean)
	local tool
	if asTool then
		tool = Instance.new("Tool")
		tool.Name = gun.Name
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool.ToolTip = "Click a fish to fire"
		tool.Grip = CFrame.new(0, 0, 0.05)
	else
		tool = Instance.new("Model")
		tool.Name = gun.Id
	end
	tool:SetAttribute("GunId", gun.Id)

	local handle
	local function part(name, size, cf, color, material, class)
		local p = Instance.new(class or "Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		for _, f in FACES do
			p[f] = Enum.SurfaceType.Smooth
		end
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Anchored = not asTool
		if handle and asTool then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
		end
		p.Parent = tool
		return p
	end
	local function cylinder(name, d, len, cf, color, material)
		local p = part(name, Vector3.new(len, d, d), cf, color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	-- Cylinder lying along Z (front to back)
	local ALONG_Z = CFrame.Angles(0, math.rad(90), 0)
	local function rod(name, d, from: Vector3, to: Vector3, color, material)
		local mid = (from + to) / 2
		return cylinder(name, d, (to - from).Magnitude, CFrame.lookAt(mid, to) * ALONG_Z, color, material)
	end

	local trim = gun.Trim
	local metal = if gun.BodyMaterial == Enum.Material.Metal then Enum.Material.Metal else Enum.Material.SmoothPlastic

	-- Pistol grip (this is the Handle the hand holds)
	handle = part("Handle", Vector3.new(0.3, 1.0, 0.46), CFrame.new(), RUBBER)
	if not asTool then
		tool.PrimaryPart = handle
	end
	part("GripBack", Vector3.new(0.32, 0.9, 0.12), CFrame.new(0, -0.02, 0.24) * CFrame.Angles(math.rad(-8), 0, 0), trim, metal)

	-- Barrel and rails
	part("Barrel", Vector3.new(0.32, 0.34, 4.4), CFrame.new(0, BARREL_Y, -1.55), gun.Body, gun.BodyMaterial)
	part("BarrelBelly", Vector3.new(0.3, 0.08, 3.6), CFrame.new(0, BARREL_Y - 0.19, -1.95), gun.Body:Lerp(Color3.new(0, 0, 0), 0.25), gun.BodyMaterial)
	part("SpearTrack", Vector3.new(0.12, 0.06, 4.3), CFrame.new(0, BARREL_Y + 0.2, -1.55), STEEL, Enum.Material.Metal)
	part("ButtPad", Vector3.new(0.36, 0.38, 0.2), CFrame.new(0, BARREL_Y, 0.75), RUBBER)

	-- Trigger and guard
	part("TriggerGuard", Vector3.new(0.07, 0.34, 0.07), CFrame.new(0, 0.25, -0.62), trim, Enum.Material.Metal)
	part("TriggerGuard", Vector3.new(0.07, 0.07, 0.42), CFrame.new(0, 0.08, -0.42), trim, Enum.Material.Metal)
	part("Trigger", Vector3.new(0.06, 0.22, 0.07), CFrame.new(0, 0.3, -0.36) * CFrame.Angles(math.rad(15), 0, 0), STEEL, Enum.Material.Metal)

	-- Muzzle head with band anchors and a sight
	part("Muzzle", Vector3.new(0.5, 0.5, 0.38), CFrame.new(0, BARREL_Y + 0.05, -3.9), trim, metal)
	for _, sx in { -1, 1 } do
		cylinder("BandAnchor", 0.16, 0.1, CFrame.new(sx * 0.28, BARREL_Y + 0.12, -3.88), RUBBER)
	end
	part("Sight", Vector3.new(0.06, 0.12, 0.06), CFrame.new(0, BARREL_Y + 0.36, -3.86), trim, Enum.Material.Metal)

	-- Reel slung under the barrel
	part("ReelBracket", Vector3.new(0.06, 0.16, 0.1), CFrame.new(0, BARREL_Y - 0.25, -1.6), trim, Enum.Material.Metal)
	cylinder("Reel", 0.5, 0.22, CFrame.new(0, BARREL_Y - 0.5, -1.6), RUBBER)
	cylinder("ReelLine", 0.42, 0.24, CFrame.new(0, BARREL_Y - 0.5, -1.6), gun.Band:Lerp(Color3.new(1, 1, 1), 0.5))

	-- Loaded spear and stretched bands (the client hides these while reloading)
	local notch = Vector3.new(0, SPEAR_Y + 0.05, -1.3)
	for _, sx in { -1, 1 } do
		rod("SpearBand", 0.11, Vector3.new(sx * 0.27, BARREL_Y + 0.12, -3.86), notch + Vector3.new(sx * 0.07, 0, 0), gun.Band)
	end
	part("SpearWishbone", Vector3.new(0.2, 0.05, 0.05), CFrame.new(notch), STEEL, Enum.Material.Metal)
	local spearColor = if gun.Glow then gun.Trim else STEEL
	rod("SpearShaft", 0.09, Vector3.new(0, SPEAR_Y, 0.45), Vector3.new(0, SPEAR_Y, -4.85), spearColor, Enum.Material.Metal)
	-- Four-blade arrowhead (each blade is two mirrored wedges)
	local tipZ = -4.85 - 0.275
	part("SpearTip", Vector3.new(0.04, 0.16, 0.55), CFrame.new(0, SPEAR_Y + 0.08, tipZ), spearColor, Enum.Material.Metal, "WedgePart")
	part("SpearTip", Vector3.new(0.04, 0.16, 0.55), CFrame.new(0, SPEAR_Y - 0.08, tipZ) * CFrame.Angles(0, 0, math.pi), spearColor, Enum.Material.Metal, "WedgePart")
	part("SpearTip", Vector3.new(0.04, 0.16, 0.55), CFrame.new(0.08, SPEAR_Y, tipZ) * CFrame.Angles(0, 0, math.rad(-90)), spearColor, Enum.Material.Metal, "WedgePart")
	part("SpearTip", Vector3.new(0.04, 0.16, 0.55), CFrame.new(-0.08, SPEAR_Y, tipZ) * CFrame.Angles(0, 0, math.rad(90)), spearColor, Enum.Material.Metal, "WedgePart")

	if gun.Glow then
		for _, sx in { -1, 1 } do
			part("GlowStrip", Vector3.new(0.02, 0.06, 3.6), CFrame.new(sx * 0.165, BARREL_Y, -1.7), gun.Trim, Enum.Material.Neon)
		end
	end

	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, SPEAR_Y, -5.45)
	muzzle.Parent = handle

	if gun.Glow or gun.Order >= 5 then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(gun.Trim)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Lifetime = NumberRange.new(0.4, 0.8)
		sparkle.Rate = 5
		sparkle.Speed = NumberRange.new(0.3, 1)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = muzzle
	end
	return tool
end

return GunModels
