-- Sprinting (QM, Oct 26): ride Config.Sprint.Delay seconds without stopping and your pet
-- builds up to a sprint, Config.Sprint.Speed x its speed (1.3x; LassoAPet's is 2x), over
-- Ramp seconds. Stop (let go of the controls, or get held up against something) and
-- you're straight back to its usual speed. This sets your WalkSpeed: your pet's
-- (Shared/Pets), x the wade (client/Liquid), x the sprint.
--
-- While you sprint, LassoAPet's riding feel, as it is there: speed lines on the screen
-- (SpeedLines), the view widening and pulling in on you (SprintCam), a white trail off
-- you (SprintTrail), the whoosh and a rush of wind (RideSounds), and on each sprint tier
-- a camera bounce, a speed burst and the sky flashing white (SkyFlash). The gallop loop
-- plays whenever you ride.
--
--   Sprint.sprinting() -> true while you sprint (from the build-up on)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)
local Liquid = require(script.Parent.Liquid)
local RideSounds = require(script.Parent.RideSounds)
local SkyFlash = require(script.Parent.SkyFlash)
local SpeedLines = require(script.Parent.SpeedLines)
local SprintCam = require(script.Parent.SprintCam)
local SprintTrail = require(script.Parent.SprintTrail)

local Sprint = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local moving = 0 -- seconds ridden without stopping
local boost = 1 -- x your pet's speed: 1 .. Config.Sprint.Speed
local sprinting = false
local wasSprinting, lastTier = false, 0
local addedFov = 0 -- the sprint's degrees on the camera's field of view, last frame

function Sprint.sprinting()
	return sprinting
end

player.CharacterAdded:Connect(function()
	moving, boost, sprinting = 0, 1, false
end)

RunService:BindToRenderStep("Sprint", Enum.RenderPriority.Camera.Value + 3, function(dt)
	local cfg = Config.Sprint
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local alive = root ~= nil and humanoid ~= nil and humanoid.Health > 0
	local base = Pets.stats(player:GetAttribute("Pet") or "Horse").Speed * Liquid.slow()
	local speed = if alive then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0

	-- the build-up: riding on (pushing, and going at least StopAt of your speed) counts up;
	-- a stop drops you straight back
	local pushing = alive and humanoid.MoveDirection.Magnitude > 0.1
	local going = speed >= base * cfg.StopAt
	if cfg.On and pushing and (going or moving < 0.3) then -- (a moment to get going from a stand)
		moving += dt
	else
		moving = 0
	end
	if moving >= cfg.Delay then
		boost = math.min(boost + (cfg.Speed - 1) * dt / cfg.Ramp, cfg.Speed)
	else
		boost = 1
	end
	sprinting = boost > 1
	if alive then
		local want = base * boost
		if math.abs(humanoid.WalkSpeed - want) > 0.01 then
			humanoid.WalkSpeed = want
		end
	end

	-- the feel of it
	SpeedLines.update(if sprinting then Config.SpeedLines.Speed else 0, dt) -- (full on any sprint, whatever the pet's speed)
	SprintTrail.update(if alive then character else nil, sprinting, speed)
	local tier = if sprinting then SprintCam.tier(speed) else 0
	if sprinting and not wasSprinting then
		RideSounds.play("sprint_whoosh", 0.32)
	elseif sprinting and tier > lastTier then
		RideSounds.play("sprint_tier", 0.5)
		SkyFlash.flash()
	end
	wasSprinting, lastTier = sprinting, tier
	RideSounds.setSprintWind(sprinting, SprintCam.tierLoudness(tier))
	RideSounds.setGallop(alive, speed / Pets.stats("Horse").Speed)

	-- the camera: wider, and in closer on you (after the other cameras, like SlashCam)
	local fov, zoom = SprintCam.update(dt, sprinting, speed)
	camera.FieldOfView += fov - addedFov
	addedFov = fov
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	if math.abs(zoom - 1) > 1e-4 and offset.Magnitude > 0.1 then
		camera.CFrame = camera.CFrame + (focus + offset * zoom - camera.CFrame.Position)
	end
end)

return Sprint
