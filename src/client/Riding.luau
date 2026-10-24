-- Everyone is always riding their horse (QM, Oct 23).
--
-- The character still walks with its normal Humanoid (so movement, collisions and the
-- sword all work as before); the horse is a client-side model under it, and the rider
-- is lifted into the saddle visually:
--   horse   anchored at the ground under the character, facing where it faces, placed so
--           its seat is under the character's centre, animated by Horse:update (idle
--           when still, gallop when moving, leaning into turns)
--   rider   the Root joint (HumanoidRootPart -> LowerTorso) puts the hips on the seat,
--           which rides on the horse's root bone, so the rider bobs and pitches with
--           the gallop,
--           and the hips and knees take a riding pose (thighs forward and apart, shins
--           back), overriding whatever the Animator plays on those joints
-- Transforms are written in PreSimulation (after the Animator), like SwingPose's. They
-- aren't replicated, so each client does this for every character.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Horse = require(Shared.Animals.Horse)

local Riding = {}

-- the rider's legs: { joint, parent part, pitch, yaw, roll } in degrees
local LEGS = {
	{ "RightHip", "RightUpperLeg", 75, 0, 22 },
	{ "LeftHip", "LeftUpperLeg", 75, 0, -22 },
	{ "RightKnee", "RightLowerLeg", -85, 0, 0 },
	{ "LeftKnee", "LeftLowerLeg", -85, 0, 0 },
	-- (the feet too: left to the Animator, the run cycle kept flexing them)
	{ "RightAnkle", "RightFoot", 0, 0, 0 },
	{ "LeftAnkle", "LeftFoot", 0, 0, 0 },
}
local HIP_UP = 0.35 -- the LowerTorso's centre sits this far above the seat

local mounts = {} -- [character] = { horse, root, humanoid, joint, legs, yaw }

local function rest(joint)
	-- (the frame the joint's Part1 hangs from, and Part1's own joint offset)
	if joint:IsA("Motor6D") then
		return joint.Part0.CFrame * joint.C0, joint.C1
	end
	return joint.Attachment0.WorldCFrame, joint.Attachment1.CFrame
end

local function mount(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local lower = character:FindFirstChild("LowerTorso")
	local joint = lower and lower:FindFirstChild("Root")
	if not (root and humanoid and joint) then
		return nil
	end
	local legs = {}
	for _, leg in LEGS do
		local part = character:FindFirstChild(leg[2])
		local j = part and part:FindFirstChild(leg[1])
		if j then
			table.insert(legs, {
				joint = j,
				pose = CFrame.Angles(0, math.rad(leg[4]), 0)
					* CFrame.Angles(math.rad(leg[3]), 0, 0)
					* CFrame.Angles(0, 0, math.rad(leg[5])),
			})
		end
	end
	-- no jumping while riding (the server also sets JumpHeight 0; this stops the jump
	-- state itself on the client that drives this character)
	if character == Players.LocalPlayer.Character then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	end
	local horse = Horse.new()
	horse.model.Name = character.Name .. "Horse"
	horse.model.Parent = workspace
	local m = { horse = horse, root = root, humanoid = humanoid, joint = joint, legs = legs, yaw = nil }
	mounts[character] = m
	return m
end

local function dismount(character)
	local m = mounts[character]
	if m then
		m.horse.model:Destroy()
		mounts[character] = nil
	end
end

local function flatYaw(cf)
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

RunService.PreSimulation:Connect(function(dt)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and not mounts[character] and character.Parent then
			mount(character)
		end
	end
	for character, m in mounts do
		if not character.Parent or m.humanoid.Health <= 0 or not m.root.Parent then
			dismount(character)
			continue
		end
		local root, horse = m.root, m.horse

		-- speed and turning, for the horse's gaits and lean
		local velocity = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local yaw = flatYaw(root.CFrame)
		local turnRate = 0
		if m.yaw then
			turnRate = (yaw - m.yaw + math.pi) % (2 * math.pi) - math.pi
			turnRate /= math.max(dt, 1e-3)
		end
		m.yaw = yaw
		horse:update(dt, velocity.Magnitude, math.clamp(-turnRate / 4, -1, 1))

		-- the horse at the ground under the character, its seat under the character
		local ground = root.Position.Y - root.Size.Y / 2 - m.humanoid.HipHeight
		local facing = CFrame.Angles(0, yaw, 0)
		local seat = horse.seat * horse.size * horse.scale
		local at = Vector3.new(root.Position.X, ground, root.Position.Z)
			- facing:VectorToWorldSpace(seat * Vector3.new(1, 0, 1))
		horse.model:PivotTo(CFrame.new(at) * facing)

		-- the rider into the saddle
		-- (worked out from the root bone's joint as it's just been posed, rather than read
		-- back from the bone part, which only moves when the joints are next solved: the
		-- rider would trail a frame behind the gallop)
		local bone = horse.bones.root
		local seatCF = horse.model.PrimaryPart.CFrame
			* bone.C0
			* bone.Transform
			* CFrame.new((horse.seat - horse.pivots.root) * horse.size * horse.scale)
		local target = seatCF * CFrame.new(0, HIP_UP, 0)
		local frame0, c1 = rest(m.joint)
		m.joint.Transform = frame0:Inverse() * target * c1
		for _, leg in m.legs do
			leg.joint.Transform = leg.pose
		end
	end
end)

-- the height of the rider's hips (for things drawn at the rider, like the slash)
function Riding.hips(character)
	local lower = character:FindFirstChild("LowerTorso")
	return lower and lower.Position
end

return Riding
