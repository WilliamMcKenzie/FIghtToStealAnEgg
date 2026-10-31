-- A boss arriving (QM, Oct 25): when one appears in workspace.Bosses for the fight you're
-- locked into (you, or someone with you, stole one of its eggs), the camera jumps to the
-- fight camera's view of the whole arena (client/FightCam), zooms straight in on the boss
-- in the middle as it rises there (client/BossView) while the screen's edges pulse red,
-- and zooms back out to the arena (QM, Oct 31: it used to start from behind you, where
-- trees and rocks got in the way). The fight starts once it's back (the server holds the boss
-- still and unhittable till then: Server/Bosses). Timings and looks: Config.BossIntro.
--
-- The camera isn't taken over: each frame this blends whatever camera is active toward
-- the shot of the boss, after every other camera script, so handing back is seamless.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FightCam = require(script.Parent:WaitForChild("FightCam"))

local INTRO = Config.BossIntro

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- the red round the screen's edges: four strips, each fading toward the middle
local gui = Instance.new("ScreenGui")
gui.Name = "BossIntro"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local strips = {}
for _, side in { { 0, 90 }, { 1, 270 }, { 2, 0 }, { 3, 180 } } do
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = INTRO.VignetteColor
	local w = INTRO.VignetteWidth
	if side[1] == 0 then -- top
		frame.Size = UDim2.fromScale(1, w)
	elseif side[1] == 1 then -- bottom
		frame.Size, frame.Position = UDim2.fromScale(1, w), UDim2.fromScale(0, 1 - w)
	elseif side[1] == 2 then -- left
		frame.Size = UDim2.fromScale(w, 1)
	else -- right
		frame.Size, frame.Position = UDim2.fromScale(w, 1), UDim2.fromScale(1 - w, 0)
	end
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = side[2] -- (opaque end at the screen's edge)
	gradient.Parent = frame
	frame.Parent = gui
	table.insert(strips, gradient)
end

local function vignette(strength)
	gui.Enabled = strength > 0.01
	-- (strength 1: VignetteAlpha at the edge, clear by the strip's inner end)
	local edge = 1 - (1 - INTRO.VignetteAlpha) * strength
	local sequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, edge),
		NumberSequenceKeypoint.new(0.5, 1 - (1 - edge) * 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, gradient in strips do
		gradient.Transparency = sequence
	end
end

local function smooth(k)
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local showing = nil -- { body, start }

-- the shot of the boss: the arena shot's angle, moved in until it's close on the boss
local function shot(body, arena)
	local size = math.max(body.Size.Y, (body:GetAttribute("Radius") or 4) * 2)
	local distance = size * INTRO.Distance + 10
	local look = arena.LookVector
	return CFrame.lookAt(body.Position - look * distance, body.Position)
end

local function play(body, start, biome)
	FightCam.snap() -- (straight to the arena view, no easing in from behind you)
	showing = { body = body, start = start, biome = biome, from = camera.CFrame }
end

RunService:BindToRenderStep("BossIntro", Enum.RenderPriority.Camera.Value + 5, function()
	if not showing then
		return
	end
	local t = os.clock() - showing.start
	local total = INTRO.PanIn + INTRO.Hold + INTRO.PanOut
	if t >= total or not showing.body.Parent then
		showing = nil
		vignette(0)
		return
	end
	local w = if t < INTRO.PanIn
		then smooth(t / INTRO.PanIn)
		elseif t < INTRO.PanIn + INTRO.Hold then 1
		else 1 - smooth((t - INTRO.PanIn - INTRO.Hold) / INTRO.PanOut)
	-- (from the fight camera's arena shot, so both ends match it exactly; without one,
	-- from wherever the camera was)
	local arena = FightCam.shot(showing.biome) or showing.from
	camera.CFrame = arena:Lerp(shot(showing.body, arena), w)
	camera.Focus = CFrame.new(showing.body.Position)
	-- red pulses once it's in view, as it rises
	local p = (t - INTRO.PanIn) / INTRO.PulseTime
	if p > 0 and p < INTRO.Pulses then
		vignette(math.sin((p % 1) * math.pi))
	else
		vignette(0)
	end
end)

task.spawn(function()
	local folder = workspace:WaitForChild("Bosses")
	folder.ChildAdded:Connect(function(body)
		if not body:IsA("BasePart") or not body:GetAttribute("Intro") then
			return
		end
		local biome, arrived = body:GetAttribute("Biome"), os.clock()
		-- (yours if you're in its fight; give the lock a moment to arrive alongside it)
		for _ = 1, 10 do
			if player:GetAttribute("LockedIn") == biome then
				play(body, arrived, biome)
				return
			end
			task.wait(0.05)
		end
	end)
end)

return nil
