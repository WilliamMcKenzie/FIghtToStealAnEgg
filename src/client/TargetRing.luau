-- The marker under whatever your auto-attack is aiming at (a boss's body, or a training
-- mob's or dummy's), flat on the floor round its Radius. QM's reference (Oct 26): three
-- lighter curved dashes round the outside, slowly turning, and inside them a thin ring
-- whose red fades inward to clear at the middle. (Handle adornments, like LassoAPet's
-- selection ring, so moving it costs next to nothing; the fade is a stack of thin bands.)
--
--   TargetRing.set(body) -- mark this body; nil hides it

local RunService = game:GetService("RunService")

local DASH_COLOR = Color3.fromRGB(255, 120, 100) -- the lighter outer dashes
local DASH_TRANSPARENCY = 0.15
local DASHES = 3
local DASH_SHARE = 0.82 -- of each dash's slot round the ring; the rest is the gap
local DASH_WIDTH = 0.16 -- of the outer radius
local RING_COLOR = Color3.fromRGB(255, 50, 35) -- the inner ring and its fade
local RING_TRANSPARENCY = 0.2
local RING_WIDTH = 0.05 -- of the outer radius
local RING_AT = 0.76 -- the inner ring's outer edge, as a share of the outer radius
local FADE_BANDS = 8 -- inside the inner ring, red to clear going in
local FADE_EDGE = 0.45 -- transparency of the band against the inner ring
local FADE_DEPTH = 0.7 -- how far in it fades out, as a share of the inner ring's radius
local SPIN = 0.6 -- radians a second (the dashes)
local LIFT = 0.2 -- studs above the bottom of the body (its feet)
local PAD = 2 -- studs past the body's Radius

local function band(color, transparency, angle)
	local a = Instance.new("CylinderHandleAdornment")
	a.Name = "TargetRing"
	a.Color3 = color
	a.Transparency = transparency
	a.Height = 0.05
	a.Angle = angle or 360
	a.AlwaysOnTop = false
	a.Visible = false
	a.Parent = workspace
	return a
end

local dashes = {}
for _ = 1, DASHES do
	table.insert(dashes, band(DASH_COLOR, DASH_TRANSPARENCY, 360 / DASHES * DASH_SHARE))
end
local ring = band(RING_COLOR, RING_TRANSPARENCY)
local fade = {}
for k = 1, FADE_BANDS do
	local t = (k - 1) / FADE_BANDS -- 0 at the ring, going in
	table.insert(fade, band(RING_COLOR, FADE_EDGE + (1 - FADE_EDGE) * t ^ 0.8))
end
local all = { ring }
table.move(dashes, 1, #dashes, #all + 1, all)
table.move(fade, 1, #fade, #all + 1, all)

local target = nil
local spin = 0

local TargetRing = {}

function TargetRing.set(body)
	if body == target then
		return
	end
	target = body
	for _, a in all do
		a.Adornee = body
		a.Visible = body ~= nil
	end
	if not body then
		return
	end
	local r = (body:GetAttribute("Radius") or 0.5 * math.max(body.Size.X, body.Size.Z)) + PAD
	for _, dash in dashes do
		dash.Radius = r
		dash.InnerRadius = r * (1 - DASH_WIDTH)
	end
	local inner = r * RING_AT
	ring.Radius = inner
	ring.InnerRadius = inner * (1 - RING_WIDTH / RING_AT)
	local step = ring.InnerRadius * FADE_DEPTH / FADE_BANDS
	for k, a in fade do
		a.Radius = ring.InnerRadius - (k - 1) * step
		a.InnerRadius = ring.InnerRadius - k * step
	end
end

RunService.RenderStepped:Connect(function(dt)
	spin = (spin + SPIN * dt) % (2 * math.pi)
	if not target then
		return
	end
	if not target.Parent then
		TargetRing.set(nil)
		return
	end
	-- (a cylinder adornment runs along its Z axis: turned to lie flat, on the body's floor)
	local base = CFrame.new(0, -target.Size.Y / 2 + LIFT, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	ring.CFrame = base
	for _, a in fade do
		a.CFrame = base
	end
	for k, dash in dashes do
		dash.CFrame = base * CFrame.Angles(0, 0, spin + (k - 1) * 2 * math.pi / DASHES)
	end
end)

return TargetRing
