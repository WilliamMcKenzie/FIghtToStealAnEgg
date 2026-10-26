-- The held bow pulses on each shot (QM, Oct 26: like Kingdom Crushers' Shoot animation,
-- which scales the weapon in the hand): it snaps to Config.Shots.Pulse.From as it fires,
-- swells to Peak by PeakAt of the gap to the next shot, and settles back to full size by
-- SettleAt. Client-side only: each client pulses every bow it sees fire.
--
-- A Tool can't be scaled as one, so each visible part's Size and each joint's offsets are
-- scaled, about the hand (the Tool.Grip point), so the bow stays in the fist. A bow is
-- 10-45 parts: a few dozen property writes a frame while it's pulsing, skipped when the
-- size hasn't moved.
--
--   BowPulse.fire(character, interval) -- the bow in `character`'s hand just shot

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local BowPulse = {}

-- [tool] = { parts = { [part] = size }, joints = { [joint] = { c0, c1, fromHandle } } }
local bases = setmetatable({}, { __mode = "k" })
-- [tool] = { start, interval, k }
local pulses = {}

local function base(tool)
	local b = bases[tool]
	if b then
		return b
	end
	local handle = tool:FindFirstChild("Handle")
	if not handle then
		return nil
	end
	b = { parts = {}, joints = {} }
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") and d ~= handle and d.Transparency < 1 then
			b.parts[d] = d.Size
		elseif d:IsA("JointInstance") and d.Part1 ~= handle then
			b.joints[d] = { d.C0, d.C1, d.Part0 == handle }
		end
	end
	bases[tool] = b
	return b
end

local function scaled(cf, k, shift)
	return cf - cf.Position + cf.Position * k + shift
end

local function apply(tool, k)
	local b = base(tool)
	if not b then
		return
	end
	-- (the joints off the Handle carry the move that keeps the grip point still)
	local shift = tool.Grip.Position * (1 - k)
	for joint, j in b.joints do
		joint.C0 = scaled(j[1], k, if j[3] then shift else Vector3.zero)
		joint.C1 = scaled(j[2], k, Vector3.zero)
	end
	for part, size in b.parts do
		part.Size = size * k
	end
end

-- the pulse's size, t shot gaps after the shot
local function size(t)
	local p = Config.Shots.Pulse
	if t < p.PeakAt then
		return p.From + (p.Peak - p.From) * (t / p.PeakAt)
	end
	return p.Peak + (1 - p.Peak) * math.min((t - p.PeakAt) / (p.SettleAt - p.PeakAt), 1)
end

function BowPulse.fire(character, interval)
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not (tool and tool:GetAttribute("WeaponType") == "Ranged") then
		return
	end
	local pulse = pulses[tool]
	pulses[tool] = { start = os.clock(), interval = math.max(interval, 0.05), k = pulse and pulse.k or 1 }
end

RunService.PreRender:Connect(function()
	local now = os.clock()
	for tool, pulse in pulses do
		local t = (now - pulse.start) / pulse.interval
		local done = t >= Config.Shots.Pulse.SettleAt or not tool.Parent
		local k = if done then 1 else size(t)
		if math.abs(k - pulse.k) > 0.003 or (done and pulse.k ~= 1) then
			apply(tool, k)
			pulse.k = k
		end
		if done then
			pulses[tool] = nil
		end
	end
end)

return BowPulse
