-- The sword swing's keyframes, hand-authored in code (no animation asset to upload, so
-- it works the same in Studio and live, and it stays locked to the slash arc).
--
-- Upper body only (Waist, Neck, both arms), so the legs keep walking underneath.
-- Keys are in phases, not seconds, so the arm sweeps exactly with the arc:
--   0 -> 1   wind-up (Config.Slash.Windup seconds, before the arc starts)
--   1 -> 2   strike: phase follows the arc's leading edge (its ease-out), 1.5 = middle
--   2 -> 3   hold (Hold seconds)
--   3 -> 4   recover (Recover seconds) back toward the Animator's own pose
--
-- Written for the forehand: the arc sweeping right to left (dir = -1). The backhand
-- (dir = 1) is the mirror image: SwingPose negates every MIRROR axis.
-- Angles are degrees about the joint's parent-part axes: x pitch (+ = back / forward
-- raise for arms), y yaw (+ = turn left), z roll. Each key is { phase, x, y, z }.
-- Arms: pitch 90 = held straight out in front, yaw swings it round. The sword comes out
-- of the top of the fist (Weapons.makeTool's Grip), so the wrist's pitch aims the blade.
--
-- idle: the guard stance held while the sword is out, a two-handed grip low in front with
-- the blade angled up and across (QM's katana reference). The arm angles were solved with
-- IK on the default R15 rig so the hands meet on the grip; `breathe` adds a slow sway
-- (degrees on x, per joint) at `speed` radians a second.

return {
	MIRROR = { x = false, y = true, z = true },

	-- how much of the pose is ours (vs the Animator's) at each phase
	weight = { smooth = true, keys = { { 0, 0, 0, 0 }, { 0.6, 1, 0, 0 }, { 3, 1, 0, 0 }, { 4, 0, 0, 0 } } },

	idle = {
		speed = 1.7,
		blendTime = 0.12, -- seconds to ease into / out of the stance on equip / unequip
		joints = {
			Waist = { order = "YXZ", x = -6, y = -25, z = 0, breathe = 2 }, -- side-on, leaning in
			Neck = { order = "YXZ", x = 4, y = 18, z = 0, breathe = -1 }, -- eyes back on the target
			RightShoulder = { order = "YXY", x = 40, y = 63, z = -2, breathe = 1.5 },
			RightElbow = { order = "YXZ", x = 35, y = 0, z = 0, breathe = 1 },
			RightWrist = { order = "YXZ", x = -19, y = -9, z = 6, breathe = 0 },
			LeftShoulder = { order = "YXZ", x = 40, y = -66, z = 0, breathe = 1.5 },
			LeftElbow = { order = "YXZ", x = 15, y = 0, z = 0, breathe = 1 },
		},
	},

	joints = {
		Waist = { -- pitch, yaw, roll: coil right, unwind hard through, lean into it
			order = "YXZ",
			keys = {
				{ 0, 0, -10, 0 },
				{ 1, 6, -42, 7 },
				{ 1.5, -10, 0, 0 },
				{ 2, -15, 42, -7 },
				{ 3, -11, 36, -5 },
				{ 4, 0, 10, 0 },
			},
		},
		Neck = { -- keeps the eyes on the target: counter-turns the waist
			order = "YXZ",
			keys = {
				{ 0, 0, 5, 0 },
				{ 1, -4, 24, 0 },
				{ 1.5, 4, 0, 0 },
				{ 2, 7, -26, 0 },
				{ 3, 5, -22, 0 },
				{ 4, 0, -5, 0 },
			},
		},
		RightShoulder = { -- pitch, yaw, twist (about the arm): cocked high and back, then across
			order = "YXY",
			keys = {
				{ 0, 90, -30, 0 },
				{ 1, 108, -68, -35 },
				{ 1.5, 92, -5, 0 },
				{ 2, 80, 62, 28 },
				{ 3, 74, 56, 22 },
				{ 4, 88, 20, 0 },
			},
		},
		RightElbow = { -- bent on the wind-up, snapped straight through the middle
			order = "YXZ",
			keys = {
				{ 0, 15, 0, 0 },
				{ 1, 72, 0, 0 },
				{ 1.5, 6, 0, 0 },
				{ 2, 18, 0, 0 },
				{ 3, 30, 0, 0 },
				{ 4, 15, 0, 0 },
			},
		},
		RightWrist = { -- x -90 lays the blade out along the arm; cocked back, then flicked through
			order = "YXZ",
			keys = {
				{ 0, -40, 0, 0 },
				{ 1, -35, 0, -32 },
				{ 1.5, -90, 0, 0 },
				{ 2, -100, 0, 26 },
				{ 3, -90, 0, 20 },
				{ 4, -55, 0, 0 },
			},
		},
		LeftShoulder = { -- counterweight: reaches forward on the wind-up, pulls back on the strike
			order = "YXZ",
			keys = {
				{ 0, 10, 0, 0 },
				{ 1, 48, -22, 0 },
				{ 1.5, 20, 0, 0 },
				{ 2, -28, -16, 0 },
				{ 3, -18, -10, 0 },
				{ 4, 5, 0, 0 },
			},
		},
		LeftElbow = {
			order = "YXZ",
			keys = {
				{ 0, 20, 0, 0 },
				{ 1, 62, 0, 0 },
				{ 1.5, 30, 0, 0 },
				{ 2, 38, 0, 0 },
				{ 3, 30, 0, 0 },
				{ 4, 20, 0, 0 },
			},
		},
	},
}
