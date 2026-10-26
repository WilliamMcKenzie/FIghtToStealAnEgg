-- The upper body with a weapon out: the cavalry riding pose (Config.RidePose: the weapon
-- trailing behind and low, bobbing with the pet's gallop) while any weapon is equipped,
-- the swing (SwingAnim's keyframes) on each slash or staff cast, and the archer's draw
-- and release (Config.RidePose.Archer) on each bow shot, and the bow's pulse (BowPulse).
--
-- Each joint's pose is put on its Transform in PreSimulation, after the Animator has
-- written its own: the stance blends over the Animator's pose (eased in on equip, out on
-- unequip), the archer pose over that while shooting, and a swing over it by
-- SwingAnim.weight. Transform, not C0:
-- the joints can be AnimationConstraints (Roblox's avatar joint upgrade), whose C0 is
-- read-only. A joint no animation touches keeps what was written, so our pose is taken
-- back off it first (base()).
--
-- The strike's phase follows the arc's leading edge (the same ease-out as SlashFx), so
-- the sword in the hand sweeps with the arc. A new swing starting during the last one's
-- recovery blends from the pose on screen, so alternating swings flow into each other.
--
-- Transform isn't replicated: each client poses every character with a weapon out, and
-- plays every slash and shot it hears about.
--
--   SwingPose.play(character, dir, c) -- c = Config.Slash (+ tool attributes)
--   SwingPose.shoot(character, id, yaw, interval)
--                                     -- a shot from weapon `id` at world `yaw`: a bow
--                                     -- draws and releases (in time for the next shot,
--                                     -- `interval` seconds on at most), a staff swings
--   SwingPose.aim(character, yaw)     -- turn the upper body by `yaw` radians from the
--                                     -- hips (+ = left): the waist takes AIM_WAIST of
--                                     -- it, the neck the rest. Set it every frame.
--   SwingPose.length(c)               -- seconds from the click to the end of recovery

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Rig = require(Shared.Rig)
local Weapons = require(Shared.Weapons.Weapons)
local BowPulse = require(script.Parent.BowPulse)
local Riding = require(script.Parent.Riding)
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

-- [character] = { joints = { [name] = joint }, stance = 0..1, swing = { start, dir, c, from },
--   archer = 0..1, shot = { start, interval, aim }, cycle, cast }
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
		s = { joints = joints, stance = 0, archer = 0, cycle = 0, cast = 1 }
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

function SwingPose.shoot(character, id, yaw, interval)
	local s = state(character)
	if not s then
		return
	end
	if Weapons.get(id).Type == "Magic" then
		-- (staffs swing exactly like swords, alternating, QM)
		SwingPose.play(character, s.cast, Config.Slash)
		s.cast = -s.cast
		return
	end
	local now = os.clock()
	-- (draw in time for the next shot: the gap since the last one, if that's quicker)
	local last = s.shot
	if last and now - last.start < interval then
		interval = math.max(now - last.start, 0.05)
	end
	-- (the bow arm points along the shot: where it's aimed, from the hips)
	local root = character:FindFirstChild("HumanoidRootPart")
	local aim = 0
	if root then
		local look = root.CFrame.LookVector
		local facing = math.atan2(-look.X, -look.Z)
		aim = (yaw - facing + math.pi) % (2 * math.pi) - math.pi
	end
	s.shot = { start = now, interval = interval, aim = aim }
	BowPulse.fire(character, interval)
end

local function release(joints)
	for _, joint in joints do
		if wrote[joint] then
			joint.Transform = base(joint)
			wrote[joint] = nil
		end
	end
end

-- the type of weapon out ("Melee", "Ranged", "Magic"), or nil, and its Config.WeaponPoses
local NONE = {}
local function holding(character)
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil, NONE
	end
	return tool:GetAttribute("WeaponType"), Config.WeaponPoses[tool:GetAttribute("Weapon")] or NONE
end

-- (client/PoseTuning: true holds the riding pose still, no breathing or gallop bob)
SwingPose.still = false

local function angles(j, x)
	return rotation(j.Order, x or j.X, j.Y, j.Z)
end

-- the draw hand's joint through one shot: u = time since the shot / time between shots
local function drawn(a, name, u)
	local full = angles(a.Joints[name])
	local let, nock = a.ReleaseJoints[name], a.NockJoints[name]
	if not (let and nock) then
		return full
	end
	let, nock = angles(let), angles(nock)
	if u < a.Release then
		return full:Lerp(let, smooth(u / a.Release))
	elseif u < a.Nock then
		return let:Lerp(nock, smooth((u - a.Release) / (a.Nock - a.Release)))
	elseif u < a.Draw then
		return nock:Lerp(full, smooth((u - a.Nock) / (a.Draw - a.Nock)))
	end
	return full
end

RunService.PreSimulation:Connect(function(dt)
	-- everyone with a weapon out takes the riding pose
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and not states[character] and holding(character) then
			state(character)
		end
	end

	local ride = Config.RidePose
	local archer = ride.Archer
	local now = os.clock()
	local breath = math.sin(now * ride.BreatheSpeed)
	for character, s in states do
		if not character.Parent then
			states[character] = nil
			continue
		end
		local kind, own = holding(character)
		local target = if kind then 1 else 0
		s.stance += (target - s.stance) * (1 - math.exp(-dt * 3 / ride.BlendTime))

		-- the gallop: in step with the pet's own, else a stride of our own
		local cycle, speed = Riding.gait(character)
		if not cycle then
			s.cycle = (s.cycle + dt * ride.BobRate) % 1
			cycle = s.cycle
		end
		local move = math.clamp(speed / ride.BobFull, 0, 1)
		local sway = if SwingPose.still then 0 else 1

		-- the bow up while shooting, until a little after the next shot was due
		local shot = if kind == "Ranged" then s.shot else nil
		local u = 0
		if shot then
			u = (now - shot.start) / shot.interval
			if now - shot.start > shot.interval + archer.Hold then
				shot = nil
			end
		end
		local up = if shot then 1 else 0
		local blend = if shot then archer.BlendIn else archer.BlendOut
		s.archer += (up - s.archer) * (1 - math.exp(-dt * 3 / blend))
		local drawing = smooth(s.archer)

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

		-- (other players' aim isn't known here: their bow arm points along their last shot)
		local want = s.aim or (if s.shot then s.shot.aim * drawing else 0)
		-- the turn onto a new target (or past the twist limit) is never a snap: a critically
		-- damped spring that settles in Config.Slash.AimTime, starting and stopping smoothly
		local w = 5.8 / math.max(Config.Slash.AimTime, 0.02)
		local x, v = s.aimNow or want, s.aimSpeed or 0
		local step = math.min(dt, 1 / 30) -- (a long frame mustn't overshoot)
		for _ = 1, math.ceil(dt / step) do
			v += (w * w * (want - x) - 2 * w * v) * step
			x += v * step
		end
		s.aimNow, s.aimSpeed = x, v
		local aim = x
		if not swing and target == 0 and s.stance < 0.01 and s.archer < 0.01 and math.abs(aim) < 1e-3 then
			release(s.joints)
			states[character] = nil
			continue
		end

		local stance = smooth(s.stance)
		for name, joint in s.joints do
			local under = base(joint)
			local pose = under
			local j = ride.Joints[name]
			if j then
				local bob = math.sin(2 * math.pi * (cycle - j.Lag))
				local sx = (j.Breathe * breath * (1 - move) + j.Bob * bob * move) * sway
				local v = own[name] -- (this weapon's own pose for the joint)
				local held = if v then rotation(j.Order, v.X + sx, v.Y, v.Z) else angles(j, j.X + sx)
				pose = under:Lerp(held, stance)
			end
			if drawing > 0 and archer.Joints[name] then
				pose = pose:Lerp(drawn(archer, name, u), drawing)
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
			-- (all of it on the waist while drawing a bow, so the bow arm points true)
			local share = AIM_WAIST + (1 - AIM_WAIST) * drawing
			if name == "Waist" then
				pose = CFrame.Angles(0, aim * share, 0) * pose
			elseif name == "Neck" then
				pose = CFrame.Angles(0, aim * (1 - share), 0) * pose
			end
			joint.Transform = pose
			wrote[joint] = { pose, under }
		end
	end
end)

return SwingPose
