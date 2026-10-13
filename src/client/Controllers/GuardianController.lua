-- The guardians and the chase. Draws each zone's guardian (smoothed from the server's
-- snapshots), plays the wake-up roar, and while one is hunting you shows the danger meter,
-- a red vignette, an arrow to it when it's off screen, a heartbeat and camera shake.
-- Also handles grabbing, escaping (confetti + catch card) and getting bitten.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureModels = require(Shared.CreatureModels)
local FishData = require(Shared.FishData)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Zones = require(Shared.Zones)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GuardianController = {}

local UI, Kit, Dive, Audio
local folder = Instance.new("Folder")
folder.Name = "ClientGuardians"
folder.Parent = workspace

local guardians = {} -- [zoneIndex] = { Zone, Spec, Rig, Buffer, Phase, Pos, Dir, State, Target, ... }
local hud = {}
local closeCallBonus = nil
local coilGlow = nil -- red outline on a guardian that's about to lunge at you
local windupTips = 0
local bountyReward = nil
local INTERP_DELAY = 0.16 -- two snapshots behind (12 per second), so network jitter never runs it dry
local SWIM = { Sleep = 0.35, Wake = 1.5, Chase = 2, Return = 1 }

-- Guardian visuals ---------------------------------------------------------------------------------------
local function firstPart(rig, groupName)
	local g = rig.Groups[groupName] or rig.Groups.body or rig.Groups.seg0
	if g and g.Parts[1] then
		return g.Parts[1]
	end
	for _, grp in rig.Groups do
		if grp.Parts[1] then
			return grp.Parts[1]
		end
	end
	return nil
end

local function nameTag(g)
	local make, text = Kit.make, Kit.text
	local anchor = firstPart(g.Rig, "head")
	local bb = make("BillboardGui", {
		Size = UDim2.fromOffset(260, 80), StudsOffsetWorldSpace = Vector3.new(0, g.Spec.L * 0.35 + 3, 0), AlwaysOnTop = false,
		MaxDistance = 140, LightInfluence = 0, Adornee = anchor, Parent = anchor,
	})
	local zzz = text("Zzz", 34, Kit.Font.Title, Color3.fromRGB(190, 220, 255), { Size = UDim2.new(1, 0, 0, 40), AutomaticSize = Enum.AutomaticSize.None, Parent = bb })
	local name = text(string.upper(g.Spec.Name), 20, Kit.Font.Title, Color3.fromRGB(255, 120, 110), { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 44), AutomaticSize = Enum.AutomaticSize.None, Parent = bb })
	g.Tag = { Gui = bb, Zzz = zzz, Name = name }
end

local function build(i)
	local g = guardians[i]
	local zone = g.Zone
	local rig = CreatureModels.Build(zone.Guardian, {})
	rig.Model.Name = zone.Guardian.Name
	-- place it in its lair straight away (models are built around the world origin)
	local parts, cfs = {}, {}
	CreatureModels.Pose(rig, CFrame.new(g.Lair + Vector3.new(0, zone.Guardian.L * 0.15, 0)), 0, 0.3, parts, cfs)
	for k, part in parts do
		part.CFrame = cfs[k]
	end
	rig.Model.Parent = folder
	g.Rig = rig
	g.TailRate = math.clamp(2.2 / math.sqrt(rig.L), 0.22, 0.8)
	local headPart = firstPart(rig, "head")
	if headPart then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 60, 50)
		light.Range = math.clamp(rig.L * 0.7, 12, 40)
		light.Brightness = 3
		light.Enabled = false
		light.Parent = headPart
		g.Light = light
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(255, 40, 40)
	hl.OutlineColor = Color3.fromRGB(255, 70, 60)
	hl.FillTransparency = 0.85
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Enabled = false
	hl.Adornee = rig.Model
	hl.Parent = rig.Model
	g.Highlight = hl
	nameTag(g)
end

local function shockwave(pos: Vector3, size: number, color: Color3)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.ForceField
	p.Color = color
	p.Transparency = 0.2
	p.Size = Vector3.one * 2
	p.Position = pos
	p.Parent = folder
	TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size, Transparency = 1 }):Play()
	task.delay(0.85, function()
		p:Destroy()
	end)
end

-- Snapshot interpolation -------------------------------------------------------------------------------------
local function onState(list, serverTime)
	for i, s in list do
		local g = guardians[i]
		if g then
			local prevState = g.LastState
			table.insert(g.Buffer, { T = serverTime, Pos = s[1], Dir = s[2], State = s[3], Target = s[4] })
			if #g.Buffer > 6 then
				table.remove(g.Buffer, 1)
			end
			g.LastState = s[3]
			g.Target = s[4]
			if prevState ~= s[3] then
				g.StateSince = os.clock()
				if s[3] == "Wake" and g.Rig then
					shockwave(s[1], g.Spec.L * 2.2, Color3.fromRGB(255, 80, 70))
				end
			end
		end
	end
end

local function sample(g, t)
	local b = g.Buffer
	local n = #b
	if n == 0 then
		return nil
	end
	if t <= b[1].T then
		return b[1].Pos, b[1].Dir
	end
	for k = n - 1, 1, -1 do
		local a, c = b[k], b[k + 1]
		if t >= a.T and t <= c.T then
			local f = (t - a.T) / math.max(c.T - a.T, 1e-3)
			local dir = a.Dir:Lerp(c.Dir, f)
			return a.Pos:Lerp(c.Pos, f), if dir.Magnitude > 1e-3 then dir.Unit else c.Dir
		end
	end
	-- past the newest snapshot: extrapolate a little
	local last = b[n]
	if n >= 2 then
		local prev = b[n - 1]
		local v = (last.Pos - prev.Pos) / math.max(last.T - prev.T, 1e-3)
		return last.Pos + v * math.min(t - last.T, 0.25), last.Dir
	end
	return last.Pos, last.Dir
end

-- Chase HUD ------------------------------------------------------------------------------------------------------
local function buildHud()
	local make, text = Kit.make, Kit.text
	local C = Kit.Color
	local gui = make("ScreenGui", { Name = "ChaseFX", IgnoreGuiInset = true, DisplayOrder = 3, ResetOnSpawn = false, Parent = player:WaitForChild("PlayerGui") })
	-- red vignette: the atlas texture, or four soft edges without it
	local vignette = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local edges = {}
	local vimg = Kit.sprite("vignette", { Size = UDim2.fromScale(1, 1), ImageColor3 = Color3.fromRGB(200, 0, 20), ImageTransparency = 1, Parent = vignette })
	if vimg then
		table.insert(edges, vimg)
	end
	for _, spec in (if vimg then {} else {
		{ UDim2.new(0.28, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0 },
		{ UDim2.new(0.28, 0, 1, 0), UDim2.new(0.72, 0, 0, 0), 180 },
		{ UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0, 0), 90 },
		{ UDim2.new(1, 0, 0.3, 0), UDim2.new(0, 0, 0.7, 0), 270 },
	}) do
		local f = make("Frame", { Size = spec[1], Position = spec[2], BackgroundColor3 = Color3.fromRGB(200, 0, 20), BorderSizePixel = 0, Parent = vignette }, {
			make("UIGradient", { Transparency = NumberSequence.new(0, 1), Rotation = spec[3] }),
		})
		table.insert(edges, f)
	end
	-- full-screen flash (bites)
	local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 30, 30), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = gui })
	-- danger meter
	-- danger meter: one pill with the hunter's icon, name, distance and a closing-in bar inside it
	local meter = make("Frame", { Size = UDim2.fromOffset(300, 44), Position = UDim2.new(0.5, 0, 0, 104), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = UI.GetGui() }, {
		Kit.corner(14),
		Kit.gradient(Color3.fromRGB(150, 40, 60), Color3.fromRGB(80, 18, 40)),
		Kit.outline(2.5),
	})
	local meterScale = make("UIScale", { Parent = meter })
	Kit.icon("shark", 30, Color3.fromRGB(255, 150, 140), { Position = UDim2.new(0, 7, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = meter })
	local label = Kit.fitText("", 14, C.Text, { Size = UDim2.new(1, -110, 0, 16), Position = UDim2.fromOffset(44, 5), TextXAlignment = Enum.TextXAlignment.Left, Parent = meter })
	local dist = Kit.fitText("", 14, Color3.fromRGB(255, 220, 120), { Size = UDim2.fromOffset(56, 16), Position = UDim2.new(1, -10, 0, 5), AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = meter })
	local face = make("Frame", { Size = UDim2.new(1, -56, 0, 12), Position = UDim2.fromOffset(44, 25), BackgroundColor3 = Color3.fromRGB(40, 10, 24), Parent = meter }, { Kit.round() })
	local fill = make("Frame", { Size = UDim2.fromScale(0.3, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = face }, {
		Kit.round(),
		Kit.gradient(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 50), 0),
	})
	-- off-screen arrow
	local arrow = make("Frame", { Size = UDim2.fromOffset(56, 56), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, Parent = gui })
	local arrowHead = make("Frame", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), Parent = arrow }, {
		Kit.corner(6), Kit.gradient(Color3.fromRGB(255, 110, 90), Color3.fromRGB(210, 40, 50)), Kit.outline(2.5),
	})
	Kit.icon("shark", 34, Color3.new(1, 1, 1), { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = arrow })
	hud = { Gui = gui, Edges = edges, Flash = flash, Meter = meter, MeterScale = meterScale, Fill = fill, Label = label, Dist = dist, Arrow = arrow, ArrowHead = arrowHead }
end

local function setVignette(a: number)
	for _, e in hud.Edges do
		if e:IsA("ImageLabel") then
			e.ImageTransparency = 1 - a
		else
			e.BackgroundTransparency = 1 - a
		end
	end
end

local function flashScreen(color: Color3, strength: number)
	hud.Flash.BackgroundColor3 = color
	hud.Flash.BackgroundTransparency = 1 - strength
	TweenService:Create(hud.Flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

-- Confetti burst on the screen
local function confetti(count: number)
	local gui = hud.Gui
	local colors = { Color3.fromRGB(255, 210, 60), Color3.fromRGB(90, 220, 90), Color3.fromRGB(80, 180, 255), Color3.fromRGB(255, 100, 170), Color3.fromRGB(190, 120, 255) }
	for _ = 1, count do
		local f = Instance.new("Frame")
		f.Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20))
		f.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.2, 0.42)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BackgroundColor3 = colors[math.random(#colors)]
		f.BorderSizePixel = 0
		f.Rotation = math.random(0, 360)
		f.Parent = gui
		local angle = math.random() * math.pi * 2
		local power = 0.15 + math.random() * 0.3
		local mid = UDim2.fromScale(0.5 + math.cos(angle) * power, 0.42 - math.abs(math.sin(angle)) * power * 0.9)
		TweenService:Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = mid, Rotation = f.Rotation + math.random(-200, 200) }):Play()
		task.delay(0.45, function()
			TweenService:Create(f, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = mid + UDim2.fromScale((math.random() - 0.5) * 0.1, 0.7), Rotation = f.Rotation + math.random(-300, 300), BackgroundTransparency = 0.3,
			}):Play()
			task.delay(1.15, function()
				f:Destroy()
			end)
		end)
	end
end
GuardianController.Confetti = function(n)
	confetti(n or 60)
end

-- Per frame -------------------------------------------------------------------------------------------------------
local parts, cframes = {}, {}
local heartbeatAt = 0

local function step(dt: number)
	dt = math.min(dt, 0.1)
	local t = workspace:GetServerTimeNow() - INTERP_DELAY
	local camPos = camera.CFrame.Position
	table.clear(parts)
	table.clear(cframes)
	local hunter, hunterDist = nil, math.huge
	local char = player.Character
	local myRoot = char and char:FindFirstChild("HumanoidRootPart")

	for _, g in guardians do
		if g.Rig then
			local pos, dir = sample(g, t)
			if pos then
				g.Pos, g.Dir = pos, dir
				local state = g.LastState or "Sleep"
				local swim = SWIM[state] or 1
				g.Swim += (swim - g.Swim) * math.min(1, dt * 3)
				g.Phase += dt * (3 + 5 * g.Swim) * g.TailRate
				local root = CFrame.lookAt(pos, pos + dir)
				if g.CoilUntil and os.clock() < g.CoilUntil then
					-- coiling to lunge: pull back and shudder
					local k = os.clock() * 45
					root *= CFrame.new(0, 0, g.Spec.L * 0.06) * CFrame.Angles(math.sin(k) * 0.05, math.sin(k * 1.3) * 0.1, 0)
				end
				if state == "Wake" then
					-- roaring: thrash in place
					local k = os.clock() * 30
					root *= CFrame.Angles(math.sin(k) * 0.06, math.sin(k * 0.7) * 0.12, math.sin(k * 1.3) * 0.08)
				end
				-- sleeping guardians far away (lost in the fog) only need an occasional update,
				-- but every guardian must be posed at least once or it sits where it was built
				local near = (pos - camPos).Magnitude < 170
				g.SinceUpdate = (g.SinceUpdate or math.huge) + dt
				if near or state ~= "Sleep" or g.SinceUpdate > 0.5 then
					g.SinceUpdate = 0
					CreatureModels.Pose(g.Rig, root, g.Phase, g.Swim, parts, cframes)
				end
				local awake = state ~= "Sleep"
				if g.Light then
					g.Light.Enabled = awake
				end
				local huntingMe = (state == "Chase" or state == "Wake") and g.Target == player.UserId
				g.Highlight.Enabled = huntingMe
				if g.Tag then
					g.Tag.Zzz.Text = if state == "Sleep" then string.rep("z", 1 + math.floor(os.clock() * 2) % 3) .. "Z" else "!"
					g.Tag.Zzz.TextColor3 = if state == "Sleep" then Color3.fromRGB(190, 220, 255) else Color3.fromRGB(255, 70, 60)
				end
				if huntingMe and myRoot then
					local mouth = pos + dir * g.Spec.L * 0.45
					local d = (mouth - myRoot.Position).Magnitude
					if d < hunterDist then
						hunter, hunterDist = g, d
					end
				end
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end

	-- Chase HUD
	if hunter then
		local danger = math.clamp(1 - (hunterDist - hunter.Spec.Bite) / 70, 0, 1)
		hud.Meter.Visible = true
		hud.Fill.Size = UDim2.fromScale(math.max(danger, 0.04), 1)
		hud.Label.Text = string.upper(hunter.Spec.Name) .. " IS HUNTING YOU"
		hud.Dist.Text = string.format("%d m", math.floor(hunterDist * Zones.MetersPerStud))
		hud.MeterScale.Scale = 1 + danger * 0.12 * (0.5 + 0.5 * math.sin(os.clock() * (6 + danger * 10)))
		setVignette(0.15 + danger * 0.55)
		if danger > 0.65 then
			Dive.Shake(0.15 + (danger - 0.65) * 1.2, 0.1)
		end
		local now = os.clock()
		if danger > 0.25 and now >= heartbeatAt then
			heartbeatAt = now + (0.9 - danger * 0.55)
			if Audio then
				Audio.Play("Heartbeat", 0.4 + danger * 0.8)
			end
		end
		-- arrow to the guardian when it's off screen
		local vp = camera.ViewportSize
		local sp, onScreen = camera:WorldToViewportPoint(hunter.Pos)
		if onScreen and sp.Z > 0 and sp.X > 0 and sp.X < vp.X and sp.Y > 0 and sp.Y < vp.Y then
			hud.Arrow.Visible = false
		else
			local rel = camera.CFrame:PointToObjectSpace(hunter.Pos)
			local v = Vector2.new(rel.X, -rel.Y)
			if v.Magnitude < 1e-3 then
				v = Vector2.new(0, 1)
			end
			v = v.Unit
			local center = vp / 2
			local reach = math.min(center.X, center.Y) - 70
			local p = center + v * reach
			hud.Arrow.Visible = true
			hud.Arrow.Position = UDim2.fromOffset(p.X, p.Y)
			hud.ArrowHead.Position = UDim2.new(0.5, v.X * 22, 0.5, v.Y * 22)
		end
	else
		hud.Meter.Visible = false
		hud.Arrow.Visible = false
		setVignette(0)
	end
end

-- Events ------------------------------------------------------------------------------------------------------------
local function decodeCarry(v)
	if type(v) ~= "string" or v == "" then
		return nil
	end
	local id, size, mut = string.match(v, "^([^|]+)|([^|]*)|(.*)$")
	if not id then
		return nil
	end
	return { Id = id, Size = if size ~= "" then size else "Normal", Mut = if mut ~= "" then mut else nil }
end

local function onChase(kind, info)
	local me = player.UserId
	if kind == "Grabbed" then
		if Audio then
			Audio.Play("Grab")
		end
		if info.Repelled then
			UI.Slam("GOT IT!", Color3.fromRGB(120, 230, 255), "Repellent! Swim up to bank it")
		else
			UI.Slam("RUN!", Color3.fromRGB(255, 80, 70), "The " .. info.Guardian .. " woke up! Swim up!")
			Dive.Shake(0.6, 0.6)
		end
	elseif kind == "Windup" then
		-- it coils before lunging: flash it red so you can dash out of the way
		local g = guardians[info.Index or 0]
		if g then
			g.CoilUntil = os.clock() + (info.Time or 0.45)
			if g.Rig then
				coilGlow = coilGlow or Kit.make("Highlight", {
					Name = "LungeWarning", FillColor = Color3.fromRGB(255, 40, 40), OutlineColor = Color3.fromRGB(255, 230, 120),
					FillTransparency = 0.55, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
				})
				coilGlow.Adornee = g.Rig.Model
				coilGlow.Parent = g.Rig.Model
				coilGlow.Enabled = true
				local token = g.CoilUntil
				task.delay((info.Time or 0.45) + 0.6, function()
					if coilGlow and g.CoilUntil == token then
						coilGlow.Enabled = false
					end
				end)
			end
		end
		if Audio then
			Audio.Play("Heartbeat")
		end
		if windupTips < 3 then
			windupTips += 1
			UI.Notify(if game:GetService("UserInputService").TouchEnabled then "It's about to lunge! Tap DASH and swerve to dodge it."
				else "It's about to lunge! Dash (Shift) sideways to dodge it.", "error")
		end
	elseif kind == "Lunge" then
		-- a guardian lunges at you: roar, jolt and a red flash
		if Audio then
			Audio.Play("Roar", 0.6)
		end
		Dive.Shake(0.55, 0.35)
		flashScreen(Color3.fromRGB(255, 40, 40), 0.22)
	elseif kind == "Wake" then
		local g = guardians[info.Index or 0]
		if info.Target == me then
			if Audio then
				Audio.Play("Roar")
			end
			Dive.Shake(0.8, 0.8)
			flashScreen(Color3.fromRGB(255, 40, 40), 0.35)
		elseif g and Dive.Underwater then
			local z = Zones.At(camera.CFrame.Position.Y)
			if z and z.Index == info.Zone then
				local who = Players:GetPlayerByUserId(info.Target)
				UI.Notify(string.format("The %s woke up and is hunting %s!", info.Guardian, if who then who.DisplayName else "someone"), "error")
			end
		end
	elseif kind == "CloseCall" then
		closeCallBonus = info.Bonus
	elseif kind == "Bounty" then
		bountyReward = info.Reward
	elseif kind == "Escaped" then
		if info.Player == me then
			if bountyReward then
				local sub = "+" .. Format.Number(bountyReward) .. " coins"
				if closeCallBonus then
					sub ..= "  (+" .. Format.Number(closeCallBonus) .. " close call!)"
				end
				UI.Slam("BOUNTY DONE!", Color3.fromRGB(255, 210, 60), sub)
				local card = UI.GetAnchor("Bounty")
				if card then
					UI.CoinBurst(card, 18)
				end
				bountyReward, closeCallBonus = nil, nil
				confetti(130)
			elseif closeCallBonus then
				UI.Slam("CLOSE CALL!", Color3.fromRGB(255, 210, 60), "+" .. Format.Number(closeCallBonus) .. " bonus coins")
				closeCallBonus = nil
				confetti(110)
			else
				UI.Slam("ESCAPED!", Color3.fromRGB(110, 230, 90), nil)
			end
			confetti(70)
			if Audio then
				Audio.Play("Escape")
			end
		end
	elseif kind == "Bitten" then
		if info.Player == me then
			UI.Slam("CHOMP!", Color3.fromRGB(255, 70, 60), "The " .. info.Guardian .. " got you!" .. (if info.Fish then " Your catch swam off." else ""))
			flashScreen(Color3.fromRGB(255, 20, 20), 0.6)
			Dive.Shake(1, 0.6)
			if Audio then
				Audio.Play("Bite")
			end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and typeof(info.Push) == "Vector3" then
				root.AssemblyLinearVelocity = info.Push
				Dive.Knock(info.Push)
			end
		end
		local victim = Players:GetPlayerByUserId(info.Player)
		local vRoot = victim and victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
		if vRoot then
			shockwave(vRoot.Position, 14, Color3.fromRGB(255, 255, 255))
		end
	end
end

local function onCatchResult(success, info)
	if success then
		task.delay(0.45, function()
			UI.ShowCatch(info)
			if Audio then
				Audio.Play("Coins")
			end
		end)
	end
end

-- "Sleep" if every guardian in the zone is asleep, otherwise the state of an awake one.
function GuardianController.StateOf(zoneIndex: number): string
	for _, g in guardians do
		if g.Zone.Index == zoneIndex and g.LastState ~= "Sleep" then
			return g.LastState
		end
	end
	return "Sleep"
end

function GuardianController.Init(ui, dive, audio)
	UI = ui
	Kit = ui.Kit
	Dive = dive
	Audio = audio
	buildHud()
	for i, info in Zones.Guardians do
		local zone = info.Zone
		local home = info.Lair + Vector3.new(0, zone.Guardian.L * 0.15, 0)
		local inward = Vector3.new(-info.Lair.X, 0, -info.Lair.Z)
		guardians[i] = {
			Zone = zone, Lair = info.Lair, Spec = zone.Guardian,
			Buffer = { { T = 0, Pos = home, Dir = if inward.Magnitude > 0.1 then inward.Unit else Vector3.new(1, 0, 0), State = "Sleep", Target = 0 } },
			Phase = math.random() * 6, Swim = 0.35, TailRate = 0.5, LastState = "Sleep", Target = 0,
		}
	end
	-- build the big models over a few frames
	task.spawn(function()
		for i in Zones.Guardians do
			build(i)
			task.wait()
		end
	end)
	Remotes.GuardianState.OnClientEvent:Connect(onState)
	Remotes.ChaseEvent.OnClientEvent:Connect(onChase)
	Remotes.CatchResult.OnClientEvent:Connect(onCatchResult)
	local function onCarry()
		UI.SetCarry(decodeCarry(player:GetAttribute("Carrying")))
	end
	player:GetAttributeChangedSignal("Carrying"):Connect(onCarry)
	onCarry()
	RunService.RenderStepped:Connect(step)
end

return GuardianController
