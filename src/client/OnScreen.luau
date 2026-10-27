-- Whether something's worth animating this frame (QM, Oct 27: the game lagged in Studio):
-- close enough to the camera and somewhere on the screen, with a margin so nothing pops
-- as it walks in from the edge. Every animal's joints moved every frame cost the most,
-- most of them off screen.
--
--   OnScreen.near(position, radius?) -> bool   -- radius: the thing's size, in studs

local OnScreen = {}

local FAR = 320 -- studs from the camera: no animating past this
local MARGIN = 0.25 -- of the screen's size, all round

function OnScreen.near(position, radius)
	local camera = workspace.CurrentCamera
	if not camera then
		return true
	end
	local away = (position - camera.CFrame.Position).Magnitude
	radius = radius or 0
	if away > FAR + radius then
		return false
	end
	if away < radius + 10 then
		return true
	end
	local at = camera:WorldToViewportPoint(position)
	if at.Z < -radius then
		return false
	end
	local size = camera.ViewportSize
	local mx, my = size.X * MARGIN, size.Y * MARGIN
	return at.X > -mx and at.X < size.X + mx and at.Y > -my and at.Y < size.Y + my
end

return OnScreen
