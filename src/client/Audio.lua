-- Sound effects, built from Roblox's built-in sounds (no uploads needed).
-- Each effect is one or more layers: { id, volume, pitch, delay }.
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Audio = {}

local S = "rbxasset://sounds/"
local EFFECTS = {
	Click = { { S .. "button.wav", 0.35, 1.1 } },
	Open = { { S .. "clickfast.wav", 0.3, 1.2 } },
	Fire = { { S .. "snap.wav", 0.6, 0.8 }, { S .. "impact_water.mp3", 0.25, 2.2 } },
	Hit = { { S .. "splat.wav", 0.7, 1.25 } },
	Grab = { { S .. "electronicpingshort.wav", 0.5, 0.8 }, { S .. "splat.wav", 0.4, 0.9, 0.05 } },
	Coins = { { S .. "electronicpingshort.wav", 0.4, 1.5 }, { S .. "electronicpingshort.wav", 0.35, 1.8, 0.08 }, { S .. "electronicpingshort.wav", 0.3, 2.1, 0.16 } },
	Dive = { { S .. "impact_water.mp3", 0.5, 1 } },
	Surface = { { S .. "impact_water.mp3", 0.35, 1.35 } },
	Dash = { { S .. "impact_water.mp3", 0.45, 1.7 } },
	Roar = { { S .. "impact_water.mp3", 1, 0.3 }, { S .. "splat.wav", 0.6, 0.4, 0.08 } },
	Bite = { { S .. "splat.wav", 1, 0.55 }, { S .. "snap.wav", 0.9, 0.6 } },
	Escape = { { S .. "electronicpingshort.wav", 0.45, 1.2 }, { S .. "electronicpingshort.wav", 0.45, 1.5, 0.1 }, { S .. "electronicpingshort.wav", 0.5, 1.8, 0.2 } },
	Heartbeat = { { S .. "button.wav", 0.5, 0.35 }, { S .. "button.wav", 0.35, 0.3, 0.16 } },
	Reload = { { S .. "clickfast.wav", 0.35, 0.9 } },
	Error = { { S .. "button.wav", 0.4, 0.6 } },
	Tick = { { S .. "clickfast.wav", 0.3, 1.4 } },
}

local folder = Instance.new("Folder")
folder.Name = "SFX"
folder.Parent = SoundService

local function playLayer(layer, pitchJitter)
	local s = Instance.new("Sound")
	s.SoundId = layer[1]
	s.Volume = layer[2] or 0.5
	s.PlaybackSpeed = (layer[3] or 1) * (1 + (math.random() - 0.5) * pitchJitter)
	s.Parent = folder
	s:Play()
	Debris:AddItem(s, 4)
end

function Audio.Play(name: string, volume: number?)
	local fx = EFFECTS[name]
	if not fx then
		return
	end
	for _, layer in fx do
		local l = layer
		if volume then
			l = { layer[1], (layer[2] or 0.5) * volume, layer[3], layer[4] }
		end
		if l[4] then
			task.delay(l[4], playLayer, l, 0.06)
		else
			playLayer(l, 0.06)
		end
	end
end

return Audio
