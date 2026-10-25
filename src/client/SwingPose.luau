-- The upper body with the sword out: the guard stance (SwingAnim.idle) while it's
-- equipped, and the swing (SwingAnim's keyframes) on each slash.
--
-- Each joint's pose is put on its Transform in PreSimulation, after the Animator has
-- written its own: the stance blends over the Animator's pose (eased in on equip, out on
-- unequip), and a swing blends over the stance by SwingAnim.weight. Transform, not C0:
-- the joints can be AnimationConstraints (Roblox's avatar joint upgrade), whose C0 is
-- read-only. A joint no animation touches keeps what was written, so our pose is taken
-- back off it first (base()).
--
-- The strike's phase follows the arc's leading edge (the same ease-out as SlashFx), so
-- the sword in the hand sweeps with the arc. A new swing starting during the last one's
-- recovery blends from the pose on screen, so alternating swings flow into each other.
--
-- Transform isn't replicated: each client poses every character with a sword out, and
-- plays every slash it hears about.
--
--   SwingPose.play(character, dir, c) -- c = Config.Slash (+ tool attributes)
--   SwingPose.aim(character, yaw)     -- turn the upper body by `yaw` radians from the
--                                     -- hips (+ = left): the waist takes AIM_WAIST of
--                                     -- it, the neck the rest. Set it every frame.
--   SwingPose.length(c)               -- seconds from the click to the end of recovery

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rig"))
local SwingAnim = require(script.Parent.SwingAnim)

local SwingPose = {}

local PARENTS = {
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
}

local tracks = {} -- [joint name] = { smooth, keys, order }
for name, joint in SwingAnim.joints do
	tracks[name] = { smooth = true, keys = joint.keys, order = joint.order }
end
local idle = SwingAnim.idle

-- [character] = { joints = { [name] = joint }, stance = 0..1, swing = { start, dir, c, from } }
local states = {}
local wrote = {} -- [joint] = { transform we wrote, the Animator's transform under it }

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function easeOut(x, power)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) ^ power
end

function SwingPose.length(c)
	return c.Windup + c.Sweep + c.Hold + c.Recover
end

-- the swing's phase (see SwingAnim) at t seconds
local function phase(t, c)
	if t < c.Windup then
		return t / c.Windup
	end
	t -= c.Windup
	if t < c.Sweep then
		return 1 + easeOut(t / c.Sweep, c.Ease)
	end
	t -= c.Sweep
	if t < c.Hold then
		return 2 + t / c.Hold
	end
	t -= c.Hold
	return 3 + math.min(t / c.Recover, 1)
end

-- the joint's Transform from the Animator (or as it was before we touched it)
local function base(joint)
	local w = wrote[joint]
	if w and joint.Transform == w[1] then
		return w[2]
	end
	return joint.Transform
end

local function rotation(order, x, y, z)
	x, y, z = math.rad(x), math.rad(y), math.rad(z)
	if order == "YXY" then
		return CFrame.Angles(0, y, 0) * CFrame.Angles(x, 0, 0) * CFrame.Angles(0, z, 0)
	end
	return CFrame.Angles(0, y, 0) * CFrame.Angles(x, 0, 0) * CFrame.Angles(0, 0, z)
end

local function findJoints(character)
	local joints = {}
	for name, parent in PARENTS do
		local part = character:FindFirstChild(parent)
		local joint = part and part:FindFirstChild(name)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			joints[name] = joint
		end
	end
	if not (joints.Waist and joints.RightShoulder) then
		return nil -- (not R15)
	end
	return joints
end

local function state(character)
	local s = states[character]
	if not s then
		local joints = findJoints(character)
		if not joints then
			return nil
		end
		s = { joints = joints, stance = 0 }
		states[character] = s
	end
	return s
end

local AIM_WAIST = 0.8

function SwingPose.aim(character, yaw)
	local s = state(character)
	if s then
		s.aim = yaw
	end
end

function SwingPose.play(character, dir, c)
	local s = state(character)
	if not s then
		return
	end
	-- carry on from the pose on screen if the last swing is still going
	local from = nil
	if s.swing then
		from = {}
		for _, joint in s.joints do
			from[joint] = joint.Transform
		end
	end
	s.swing = { start = os.clock(), dir = dir, c = c, from = from }
end

local function release(joints)
	for _, joint in joints do
		if wrote[joint] then
			joint.Transform = base(joint)
			wrote[joint] = nil
		end
	end
end

-- (any melee weapon: Ranged and Magic ones are held out in the tool pose)
local function holdingSword(character)
	local tool = character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("WeaponType") == "Melee"
end

RunService.PreSimulation:Connect(function(dt)
	-- everyone with a sword out takes the stance
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and not states[character] and holdingSword(character) then
			state(character)
		end
	end

	local now = os.clock()
	local breath = math.sin(now * idle.speed)
	for character, s in states do
		if not character.Parent then
			states[character] = nil
			continue
		end
		local target = if holdingSword(character) then 1 else 0
		s.stance += (target - s.stance) * (1 - math.exp(-dt * 3 / idle.blendTime))

		local swing = s.swing
		local p, weight, mirror
		if swing then
			local t = now - swing.start
			if t >= SwingPose.length(swing.c) then
				s.swing = nil
				swing = nil
			else
				p = phase(t, swing.c)
				weight = smooth((Rig.sample(SwingAnim.weight, p)))
				mirror = swing.dir == 1
			end
		end

		local aim = s.aim or 0
		if not swing and target == 0 and s.stance < 0.01 and math.abs(aim) < 1e-3 then
			release(s.joints)
			states[character] = nil
			continue
		end

		local stance = smooth(s.stance)
		for name, joint in s.joints do
			local under = base(joint)
			local pose = under
			local guard = idle.joints[name]
			if guard then
				local held = rotation(guard.order, guard.x + guard.breathe * breath, guard.y, guard.z)
				pose = under:Lerp(held, stance)
			end
			if swing then
				local track = tracks[name]
				local x, y, z = Rig.sample(track, p)
				if mirror then
					if SwingAnim.MIRROR.y then
						y = -y
					end
					if SwingAnim.MIRROR.z then
						z = -z
					end
				end
				-- (while blending in, a swing that interrupted another starts from where it was)
				local start = if swing.from and p < 1 then swing.from[joint] or pose else pose
				pose = start:Lerp(rotation(track.order, x, y, z), weight)
			end
			-- the aim turns the whole upper body toward the target, over everything else
			if name == "Waist" then
				pose = CFrame.Angles(0, aim * AIM_WAIST, 0) * pose
			elseif name == "Neck" then
				pose = CFrame.Angles(0, aim * (1 - AIM_WAIST), 0) * pose
			end
			joint.Transform = pose
			wrote[joint] = { pose, under }
		end
	end
end)

return SwingPose
