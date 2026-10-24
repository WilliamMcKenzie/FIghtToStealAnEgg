-- The camera feels each slash: it zooms in a little, and consecutive slashes keep
-- zooming in (QM, Oct 23).
--
-- z (0..1) is how zoomed in we are; the camera sits at (1 - ZoomMax * z) of its normal
-- distance from its Focus.
--   slash   z += ZoomStep * (1 - z): each slash adds less the further in you already are,
--           so z never reaches 1
--   return  all the time, dz/dt = -ZoomReturn * z ^ ZoomPower: the further in, the
--           faster it heads back out (gentle near normal, quick from deep in)
-- The camera chases z over ZoomIn seconds, so a slash zooms in quickly but not in a pop.
--
-- Runs after the camera scripts each frame (and after the T top-down camera), so it
-- layers on whatever camera is active by moving the camera toward its Focus.
--
--   SlashCam.zoom(c)  -- on each of your slashes; c = the slash's settings

local RunService = game:GetService("RunService")

local SlashCam = {}

local camera = workspace.CurrentCamera
local target = 0 -- z the slashes ask for, returning to 0
local shown = 0 -- z on screen, chasing target
local c = nil

function SlashCam.zoom(settings)
	c = settings
	target += settings.ZoomStep * (1 - target)
end

RunService:BindToRenderStep("SlashCam", Enum.RenderPriority.Camera.Value + 2, function(dt)
	if not c then
		return
	end
	target = math.max(0, target - c.ZoomReturn * target ^ c.ZoomPower * dt)
	if target < 1e-3 then
		target = 0
	end
	shown += (target - shown) * (1 - math.exp(-dt * 3 / c.ZoomIn))

	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	if shown > 1e-4 and offset.Magnitude > 0.1 then
		local pull = 1 - c.ZoomMax * shown
		camera.CFrame = camera.CFrame + (focus + offset * pull - camera.CFrame.Position)
	end
end)

return SlashCam
