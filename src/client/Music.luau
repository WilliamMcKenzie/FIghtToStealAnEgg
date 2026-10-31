-- Music (QM, Oct 31): the soundtrack. Config.Music.Ambient loops everywhere; while you're
-- locked into a boss fight (your LockedIn attribute) Config.Music.Battle crossfades in over
-- it, and when the fight ends (won, lost or left) Ambient crossfades back. Ambient pauses
-- while faded out and resumes where it left off; Battle starts from the top each fight
-- (Config.Music.Restart). Flat 2D sounds in SoundService, never through Sfx.play.
-- A track with an empty id is just silent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local M = Config.Music
local player = Players.LocalPlayer

local function assetId(id)
	if id == nil or id == "" or id == 0 then
		return nil
	end
	if typeof(id) == "number" or tonumber(id) then
		return "rbxassetid://" .. tostring(id)
	end
	return id
end

local function track(name, entry)
	local id = assetId(entry.id)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Music" .. name
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	return { sound = s, volume = entry.volume or 0.4 }
end

local tracks = {
	Ambient = track("Ambient", M.Ambient),
	Battle = track("Battle", M.Battle),
}

local tweens = {}
local function fade(name, on)
	local t = tracks[name]
	if not t then
		return
	end
	local s = t.sound
	if tweens[name] then
		tweens[name]:Cancel()
	end
	if on then
		if not s.IsPlaying then
			if name == "Battle" and M.Restart then
				s.TimePosition = 0
			end
			s:Resume()
		end
		tweens[name] = TweenService:Create(s, TweenInfo.new(M.FadeIn or 1.5, Enum.EasingStyle.Sine), { Volume = t.volume })
	else
		tweens[name] = TweenService:Create(s, TweenInfo.new(M.FadeOut or 1.5, Enum.EasingStyle.Sine), { Volume = 0 })
		tweens[name].Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				s:Pause()
			end
		end)
	end
	tweens[name]:Play()
end

local fighting = nil
local function update()
	local now = player:GetAttribute("LockedIn") ~= nil
	-- with no battle track, ambient just keeps playing through fights
	if not tracks.Battle then
		now = false
	end
	if now == fighting then
		return
	end
	fighting = now
	fade("Battle", now)
	fade("Ambient", not now)
end

player:GetAttributeChangedSignal("LockedIn"):Connect(update)
update()

return {}
