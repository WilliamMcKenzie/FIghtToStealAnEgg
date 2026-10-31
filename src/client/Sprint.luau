-- Sprinting (QM, Oct 26): ride Config.Sprint.Delay seconds without stopping and your pet
-- builds up to a sprint, Config.Sprint.Speed x its speed (1.3x; LassoAPet's is 2x), over
-- Ramp seconds. Stop (let go of the controls, or get held up against something) and
-- you're straight back to its usual speed. This sets your WalkSpeed: your pet's
-- (Shared/Pets), x the wade (client/Liquid), x the sprint.
--
-- While you sprint, LassoAPet's riding feel: speed lines on the screen (SpeedLines), the
-- view widening and pulling in on you (SprintCam), a white trail off you (SprintTrail),
-- the whoosh and a rush of wind (RideSounds). The gallop loop plays whenever you ride.
-- (QM, Oct 30: no more camera bounce, speed burst and sky flash on each sprint tier.)
--
-- A pet with a sprint ability (Config.SprintPets: the Sandworm's burrow, the fliers'
-- flight, the whales' and Rhino's smash, the Volcano Tortoise's bombs) gets those once
-- instead, the moment its sprint starts, and the server's told (Server/SprintAbility),
-- which runs it till you stop, or ends it (SprintEnd: a Smash ran into something) and
-- you ride on another Sprint.Delay to start it again. client/SprintAbility draws it.
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
local FightCam = require(script.Parent.FightCam)
local SprintTrail = require(script.Parent.SprintTrail)

local Sprint = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local moving = 0 -- seconds ridden without stopping
local boost = 1 -- x your pet's speed: 1 .. Config.Sprint.Speed
local sprinting = false
local wasSprinting = false
local abilityOn = false -- told the server our sprint ability's on
local addedFov = 0 -- the sprint's degrees on the camera's field of view, last frame

local abilityRemote = ReplicatedStorage:WaitForChild("SprintAbility")

local function setAbility(on)
	if on ~= abilityOn then
		abilityOn = on
		abilityRemote:FireServer(on)
	end
end

-- (a Smash ran into something: the sprint's over, ride on to start it again)
ReplicatedStorage:WaitForChild("SprintEnd").OnClientEvent:Connect(function()
	moving, boost, sprinting = 0, 1, false
	abilityOn = false
end)

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
	local onFoot = player:GetAttribute("OnFoot") == true -- (the tutorial before its first ride: no sprinting)
	local base = (if onFoot then Config.Tutorial.WalkSpeed else Pets.stats(player:GetAttribute("Pet") or "Horse").Speed) * Liquid.slow()
	local speed = if alive then (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude else 0

	-- the build-up: riding on (pushing, and going at least StopAt of your speed) counts up;
	-- a stop drops you straight back
	local pushing = alive and humanoid.MoveDirection.Magnitude > 0.1
	local going = speed >= base * cfg.StopAt
	if cfg.On and not onFoot and pushing and (going or moving < 0.3) then -- (a moment to get going from a stand)
		moving += dt
	else
		moving = 0
	end
	if moving >= cfg.Delay then
		boost = math.min(boost + (cfg.Speed - 1) * dt / cfg.Ramp, cfg.Speed)
		-- (a charge builds on: up to Smash.MaxSpeed x the sprint over its Ramp: QM, Oct 30)
		local ability = Config.SprintPets[player:GetAttribute("Pet") or "Horse"]
		if ability == "Smash" or ability == "Crabwalk" then
			local smash = Config.SprintAbility.Smash
			local built = math.clamp((moving - cfg.Delay) / smash.Ramp, 0, 1)
			boost = math.max(boost, cfg.Speed * (1 + (smash.MaxSpeed - 1) * built))
		end
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
	local special = alive and Config.SprintPets[player:GetAttribute("Pet") or "Horse"] ~= nil
	if sprinting and not wasSprinting then
		RideSounds.play("sprint_whoosh", 0.32)
		if special then
			-- (the sprint ability kicks in: the speed burst, once)
			RideSounds.play("sprint_tier", 0.5)
			SkyFlash.flash()
			if not FightCam.active() then
				SprintCam.pulse()
			end
		end
	end
	setAbility(sprinting and special)
	wasSprinting = sprinting
	RideSounds.setSprintWind(sprinting, 1)
	RideSounds.setGallop(alive and not onFoot, speed / Pets.stats("Horse").Speed)

	-- the camera: wider, and in closer on you (after the other cameras, like SlashCam)
	-- (not in a boss fight: its camera stays put, so the sprint look eases out)
	local fov, zoom = SprintCam.update(dt, sprinting and not FightCam.active(), speed)
	camera.FieldOfView += fov - addedFov
	addedFov = fov
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	if math.abs(zoom - 1) > 1e-4 and offset.Magnitude > 0.1 then
		camera.CFrame = camera.CFrame + (focus + offset * zoom - camera.CFrame.Position)
	end
end)

return Sprint
