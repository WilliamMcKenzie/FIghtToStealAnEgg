-- A white trail off the rider while their mount sprints (QM, Oct 9), built just like
-- VIP's gold one (Shared/RiderTrail), as long as it is fast: its Lifetime is
-- Config.SprintTrail.Life at a horse's sprint (a short streak) and grows with the speed
-- (up to MaxLife).
--
--   SprintTrail.update(character, on, speed) -- every frame: the rider (or nil)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RiderTrail = require(ReplicatedStorage.Shared.RiderTrail)
local SprintCam = require(script.Parent.SprintCam)

local SprintTrail = {}

local NAME = "SprintTrail"
local WHITE = Color3.new(1, 1, 1)
local current -- { hrp, trail }

function SprintTrail.update(character, on, speed)
	local cfg = Config.SprintTrail
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if current and (current.hrp ~= hrp or not current.trail.Parent) then
		if current.hrp.Parent then
			RiderTrail.remove(current.hrp, NAME)
		end
		current = nil
	end
	if not hrp or not cfg.On then
		return
	end
	if not current then
		local trail = RiderTrail.make(hrp, NAME, { WHITE, WHITE }, cfg.Life, cfg.Transparency)
		trail.Enabled = false
		current = { hrp = hrp, trail = trail }
	end
	current.trail.Enabled = on
	if on then
		current.trail.Lifetime = math.clamp(cfg.Life * (speed or 0) / SprintCam.horseSprint(), cfg.Life * 0.5, cfg.MaxLife)
	end
end

return SprintTrail
