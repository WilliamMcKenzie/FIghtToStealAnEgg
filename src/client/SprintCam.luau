-- The sprint camera (QM, Oct 9): while you sprint, the view widens (a higher
-- FieldOfView stretches the screen's edges, the nearest Roblox gets to a fisheye) and
-- the camera pulls in on you, easing in over InTime seconds and back over OutTime.
-- How much goes with your speed (QM, Oct 9): Fov / Zoom as set at a horse's sprint
-- (the Horse's speed x Config.Sprint.Speed), more the faster you go (up to MaxScale x), less if slower,
-- easing smoothly with it. A sprint ability starting (Config.SprintPets; QM, Oct 30: only
-- then, once, no longer on every sprint tier) bounces the camera's distance, animation
-- style (QM, Oct 9): in to Bounce.In x, out to Bounce.Out x, then settling back.
-- Config.SprintCam.
--
--   SprintCam.update(dt, sprinting, speed) -> degrees to add to the field of view, x the camera's distance
--   SprintCam.pulse()  -- the bounce, now

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Pets = require(Shared.Pets)

local SprintCam = {}

local t = 0 -- 0 (off) .. 1 (full sprint look)
local scale = 1 -- how much, by speed (eased, so a speed change doesn't jump the view)
local bounceT -- seconds into a bounce (nil: none)

-- a horse's sprint, studs/s (LassoAPet's Config.SprintCam.HorseSprint: its horse's 2x)
function SprintCam.horseSprint()
	return Pets.stats("Horse").Speed * Config.Sprint.Speed
end

function SprintCam.pulse()
	bounceT = 0
end

-- The bounce's x on the camera's distance, b seconds in: in (eased out), out past where
-- it was (eased in and out), then back (eased out).
local function bounce(cfg, b)
	local function out(x)
		return 1 - (1 - x) * (1 - x)
	end
	if b < cfg.InTime then
		return 1 + (cfg.In - 1) * out(b / cfg.InTime)
	end
	b -= cfg.InTime
	if b < cfg.OutTime then
		local x = b / cfg.OutTime
		return cfg.In + (cfg.Out - cfg.In) * x * x * (3 - 2 * x)
	end
	b -= cfg.OutTime
	return cfg.Out + (1 - cfg.Out) * out(math.min(b / cfg.SettleTime, 1))
end

function SprintCam.update(dt, sprinting, speed)
	local cfg = Config.SprintCam
	if not cfg.On then
		t = 0
		return 0, 1
	end
	if sprinting then
		t = math.min(t + dt / cfg.InTime, 1)
	else
		t = math.max(t - dt / cfg.OutTime, 0)
	end
	local k = t * t * (3 - 2 * t) -- (smoothstep: eased at both ends)
	if sprinting and speed then
		local full = math.clamp(speed / SprintCam.horseSprint(), cfg.MinScale, cfg.MaxScale)
		scale += (full - scale) * (1 - math.exp(-4 * dt))
	end
	k *= scale
	local zoom = math.max(1 + (cfg.Zoom - 1) * k, 0.4)
	if bounceT then
		bounceT += dt
		zoom *= bounce(cfg.Bounce, bounceT)
		if bounceT >= cfg.Bounce.InTime + cfg.Bounce.OutTime + cfg.Bounce.SettleTime then
			bounceT = nil
		end
	end
	return (cfg.Fov - 70) * k, zoom
end

return SprintCam
