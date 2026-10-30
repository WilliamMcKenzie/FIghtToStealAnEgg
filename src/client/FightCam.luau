-- The boss fight camera (QM, Oct 29): while you're locked into a boss's fight (your
-- LockedIn attribute), the camera sits high above you, looking steeply down at a fixed
-- angle from a fixed side, and follows you. You can't turn or zoom it. It eases in when
-- the fight starts and, when it ends, back to exactly the angle and distance your camera
-- had before the fight. Config.FightCam; tune it live in workspace.BossTuning
-- (Shared/BossTuning).
--
-- The camera isn't taken over: each frame this blends whatever camera is active toward
-- the fight shot, after Roblox's camera scripts, so handing back is seamless. Runs
-- before SlashCam, Sprint and BossIntro, so the slash zoom still plays and the boss
-- intro still swings over to the boss. Sprint leaves the camera alone while it's on.
--
--   FightCam.active() -> true while the fight camera is on (or easing in or out)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossTuning = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BossTuning"))

local FightCam = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local w = 0 -- 0 (your own camera) .. 1 (the fight camera)
local addedFov = 0 -- what this has added to the field of view
-- your camera just before the fight, relative to you (world-aligned): Roblox's camera
-- scripts steer from the camera's last CFrame, so without this they'd stay top-down
local before = nil

function FightCam.active()
	return w > 0
end

local function smooth(k)
	return k * k * (3 - 2 * k)
end

RunService:BindToRenderStep("FightCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cfg = BossTuning.camera() -- (Config.FightCam, with workspace.BossTuning's live values)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local on = cfg.On and root ~= nil and player:GetAttribute("LockedIn") ~= nil
	if on then
		if w <= 0 and root then
			before = CFrame.new(root.Position):ToObjectSpace(camera.CFrame)
		end
		w = math.min(w + dt / cfg.InTime, 1)
	else
		w = math.max(w - dt / cfg.OutTime, 0)
	end

	local fov = (cfg.Fov - 70) * smooth(w)
	camera.FieldOfView += fov - addedFov
	addedFov = fov
	if w <= 0 or not root then
		if w <= 0 and before and root then
			camera.CFrame = CFrame.new(root.Position) * before
			before = nil
		end
		return
	end

	local at = root.Position + Vector3.new(0, cfg.Height, 0)
	local pitch, yaw = math.rad(cfg.Pitch), math.rad(cfg.Yaw)
	-- (yaw 0: the camera sits to the south, +Z, looking north)
	local back = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
	local shot = CFrame.lookAt(at + back * cfg.Distance, at)
	local own = camera.CFrame
	if not on and before then
		-- easing out: head back to where your camera was before the fight
		own = CFrame.new(root.Position) * before
	end
	camera.CFrame = own:Lerp(shot, smooth(w))
	camera.Focus = camera.Focus:Lerp(CFrame.new(at), smooth(w))
end)

return FightCam
