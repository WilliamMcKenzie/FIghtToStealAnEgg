-- The riding sounds, LassoAPet's (its client/Sounds, the riding part): the gallop loop
-- while you ride, louder and quicker the faster you go; the whoosh as you break into a
-- sprint and a speed burst on each sprint tier; a rush of wind looping while you sprint.
-- (Its ids are Creator Store sounds; one that won't load just stays silent.)
--
--   RideSounds.play(name, volume?)          -- a one-shot (IDS below)
--   RideSounds.setGallop(on, pace?)         -- pace 0..1+ (your speed over the Horse's) sets its volume and rate
--   RideSounds.setSprintWind(on, loudness?) -- loudness 1..2 (the sprint tier's step)

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local RideSounds = {}

local IDS = {
	gallop_loop = "rbxassetid://129029116650332", -- while riding
	sprint_whoosh = "rbxassetid://79833203443837", -- the sprint starts: speed woosh (compressed cloth sfx dash)
	sprint_tier = "rbxassetid://137322083927464", -- up a sprint tier: Speed Burst SFX (dash cloth)
	-- Spiraling Wind Data Tunnel Travelling 2 (ProSoundEffects): subtle, while you sprint
	sprint_wind = "rbxassetid://9119462999",
	egg_hatch = "rbxassetid://96102213526905", -- an egg in your pen hatches: LassoAPet's (Rewards, QM's pick; client/PenEggs)
}
local VOLUME = 0.5
local GALLOP_VOLUME = 0.35
local SPRINT_WIND_VOLUME = 0.15 -- (subtle; at a horse's sprint)

local folder = Instance.new("Folder")
folder.Name = "RideSounds"
folder.Parent = SoundService

local function newSound(id, volume, looped)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Looped = looped or false
	s.Parent = folder
	return s
end

-- each one loaded up front (so the first play isn't late or silent); a play is a copy
local templates = {}
for name, id in IDS do
	templates[name] = newSound(id, VOLUME)
end
task.spawn(function()
	local list = {}
	for _, t in templates do
		table.insert(list, t)
	end
	pcall(game:GetService("ContentProvider").PreloadAsync, game:GetService("ContentProvider"), list)
end)

function RideSounds.play(name, volume)
	local template = templates[name]
	if not template then
		return
	end
	local s = template:Clone()
	s.Volume = volume or VOLUME
	s.Parent = folder
	s.Ended:Once(function()
		s:Destroy()
	end)
	s:Play()
	task.delay(10, function() -- (in case Ended never comes)
		if s.Parent then
			s:Destroy()
		end
	end)
	return s
end

local gallop
function RideSounds.setGallop(on, pace)
	gallop = gallop or newSound(IDS.gallop_loop, 0, true)
	if not on then
		if gallop.IsPlaying then
			gallop:Stop()
		end
		return
	end
	pace = math.clamp(pace or 1, 0, 3)
	gallop.Volume = GALLOP_VOLUME * math.min(pace, 1)
	gallop.PlaybackSpeed = 0.8 + 0.3 * math.min(pace, 2)
	if not gallop.IsPlaying then
		gallop:Play()
	end
end

-- faded in and out; loudness x SPRINT_WIND_VOLUME (louder the faster you go, up to 2x)
local wind, windTween
local windLoud = 1
function RideSounds.setSprintWind(on, loudness)
	wind = wind or newSound(IDS.sprint_wind, 0, true)
	windLoud = loudness or windLoud
	if on == (wind:GetAttribute("On") == true) then
		if on and not (windTween and windTween.PlaybackState == Enum.PlaybackState.Playing) then
			wind.Volume = SPRINT_WIND_VOLUME * windLoud -- (following the speed once it's in)
		end
		return
	end
	wind:SetAttribute("On", on)
	if on and not wind.IsPlaying then
		wind:Play()
	end
	if windTween then
		windTween:Cancel()
	end
	windTween = TweenService:Create(wind, TweenInfo.new(if on then 0.25 else 0.5), { Volume = if on then SPRINT_WIND_VOLUME * windLoud else 0 })
	windTween:Play()
end

return RideSounds
