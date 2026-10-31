-- LassoAPet's ArrowTrail, 1:1 (QM, Oct 31: for the tutorial's guide, client/Tutorial).
-- A trail of arrows on the ground (QM, Oct 12, in place of the chevron beam): QM's big
-- white down arrow (the one over your fastest pet and ready eggs) laid flat, each pointing
-- along the way, evenly spaced and drifting toward the end, a little over the ground.
-- A pool of flat parts per trail, reused (no Highlight, nothing made per frame).
--
--   local trail = ArrowTrail.new()  -- one per user (Ride's guide, the tutorial's)
--   trail.draw(from, to)  -- from and to: Vector3s (their Y is the trail's height)
--   trail.draw()          -- hides it

local RunService = game:GetService("RunService")

local ArrowTrail = {}

local ARROW = "rbxassetid://127821178410489" -- assets/ui/TutorialArrow.png (pointing down the image)
local SIZE = 4.5 -- studs across each arrow
local GAP = 7 -- studs from one arrow to the next
local SPEED = 6 -- studs a second the arrows drift toward the end
local FADE = 5 -- studs: arrows fade in at the start and out at the end over this
local MAX = 60 -- arrows at most (a long trail is cut short)

local folder
local function make()
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ArrowTrail"
		folder.Parent = workspace
	end
	local p = Instance.new("Part")
	p.Name = "Arrow"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(SIZE, 0.05, SIZE)
	local decal = Instance.new("Decal")
	decal.Face = Enum.NormalId.Top
	decal.Texture = ARROW
	decal.Parent = p
	return { part = p, decal = decal }
end

local shift = 0 -- (every trail drifts together)
RunService.RenderStepped:Connect(function(dt)
	shift = (shift + SPEED * dt) % GAP
end)

function ArrowTrail.new()
	local pool = {}
	local shown = 0
	local trail = {}
	function trail.draw(from, to)
		local used = 0
		if from and to then
			local path = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			local length = path.Magnitude
			if length > 0.5 then
				local along = path.Unit
				-- (the image's down, its arrow's point, comes out along the part's -Z: faced along the trail)
				local turn = CFrame.lookAt(Vector3.zero, along)
				local d = shift
				while d <= length and used < MAX do
					used += 1
					pool[used] = pool[used] or make()
					local a = pool[used]
					local at = from + along * d
					a.part.CFrame = CFrame.new(at.X, from.Y + (to.Y - from.Y) * d / length, at.Z) * turn
					a.decal.Transparency = 1 - math.clamp(math.min(d, length - d) / FADE, 0, 1)
					a.part.Parent = folder
					d += GAP
				end
			end
		end
		for i = used + 1, shown do
			pool[i].part.Parent = nil
		end
		shown = used
	end
	return trail
end

return ArrowTrail
