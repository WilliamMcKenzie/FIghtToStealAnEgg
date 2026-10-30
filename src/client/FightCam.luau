-- The boss fight camera (QM, Oct 29): while you're locked into a boss's fight (your
-- LockedIn attribute), the camera sits high above you, looking steeply down at a fixed
-- angle from a fixed side, and follows you. You can't turn or zoom it. It eases in when
-- the fight starts and, when it ends, back to exactly the angle and distance your camera
-- had before the fight. With Fixed on it holds still instead, centred on the arena and
-- zoomed so the arena's width fills the screen. Config.FightCam; tune it live in workspace.BossTuning
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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BossTuning = require(Shared:WaitForChild("BossTuning"))
local MapData = require(Shared:WaitForChild("MapData"))

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

-- Fixed (QM, Oct 30): the camera holds still over the arena instead of following you.
-- An arena is its biome's map area (Shared/MapData): its Bounds and its floor's height.
local fought = nil -- the biome you were last locked into
local areas = {}
local function areaOf(biome)
	if not biome then
		return nil
	end
	if areas[biome] == nil then
		areas[biome] = false
		for _, area in MapData.Areas do
			if area.Name == biome and area.Bounds then
				local b, floor = area.Bounds, math.huge
				for _, tile in area.Tiles do
					if not tile[4] then
						floor = math.min(floor, tile[2])
					end
				end
				floor = if floor == math.huge then 0 else floor
				areas[biome] = { Bounds = b, centre = Vector3.new((b[1] + b[3]) / 2, floor, (b[2] + b[4]) / 2) }
			end
		end
	end
	return areas[biome] or nil
end

local function smooth(k)
	return k * k * (3 - 2 * k)
end

RunService:BindToRenderStep("FightCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local cfg = BossTuning.camera() -- (Config.FightCam, with workspace.BossTuning's live values)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local on = cfg.On and root ~= nil and player:GetAttribute("LockedIn") ~= nil
	fought = player:GetAttribute("LockedIn") or fought -- (still framed while easing back out)
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
	local distance = cfg.Distance
	local area = cfg.Fixed and areaOf(player:GetAttribute("LockedIn") or fought)
	if area then
		-- Fixed: held over the arena's middle, back far enough that its width just fits
		-- across the screen (times Fit)
		local b = area.Bounds
		local width = math.abs(math.cos(yaw)) * math.abs(b[3] - b[1]) + math.abs(math.sin(yaw)) * math.abs(b[4] - b[2])
		local view = camera.ViewportSize
		local across = math.tan(math.rad(cfg.Fov) / 2) * view.X / math.max(view.Y, 1)
		at = area.centre + Vector3.new(0, cfg.Height, 0)
		distance = width / 2 * (cfg.Fit or 1) / across
	end
	local shot = CFrame.lookAt(at + back * distance, at)
	local own = camera.CFrame
	if not on and before then
		-- easing out: head back to where your camera was before the fight
		own = CFrame.new(root.Position) * before
	end
	camera.CFrame = own:Lerp(shot, smooth(w))
	camera.Focus = camera.Focus:Lerp(CFrame.new(at), smooth(w))
end)

return FightCam
