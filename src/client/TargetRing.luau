-- The ring under whatever your auto-attack is aiming at (QM, Oct 26): LassoAPet's
-- selection ring (its client/Outline: a dashed ring on the ground, slowly turning), in
-- pure red at 60% opacity. It sits on the floor under the target's body (a boss's, or a
-- training mob's or dummy's) and goes round its Radius.
--
--   TargetRing.set(body) -- ring this body; nil hides it

local RunService = game:GetService("RunService")

local COLOR = Color3.fromRGB(255, 0, 0) -- pure red (QM)
local TRANSPARENCY = 0.4 -- 60% opacity (QM)
local DASHES = 10
local DASH_SHARE = 0.6 -- of each dash's slot round the ring; the rest is the gap
local SPIN = 0.8 -- radians a second
local LIFT = 0.2 -- studs above the bottom of the body (its feet)
local PAD = 1.5 -- studs past the body's Radius

local dashes = {}
for _ = 1, DASHES do
	local dash = Instance.new("CylinderHandleAdornment")
	dash.Name = "TargetRingDash"
	dash.Color3 = COLOR
	dash.Transparency = TRANSPARENCY
	dash.Height = 0.1
	dash.Angle = 360 / DASHES * DASH_SHARE
	dash.AlwaysOnTop = false
	dash.Visible = false
	dash.Parent = workspace
	table.insert(dashes, dash)
end

local target = nil
local spin = 0

local TargetRing = {}

function TargetRing.set(body)
	if body == target then
		return
	end
	target = body
	local radius = body and (body:GetAttribute("Radius") or 0.5 * math.max(body.Size.X, body.Size.Z)) + PAD
	for _, dash in dashes do
		dash.Adornee = body
		dash.Visible = body ~= nil
		if body then
			dash.Radius = radius
			dash.InnerRadius = radius - math.clamp(radius * 0.12, 0.5, 2)
		end
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
	for k, dash in dashes do
		dash.CFrame = base * CFrame.Angles(0, 0, spin + (k - 1) * 2 * math.pi / DASHES)
	end
end)

return TargetRing
