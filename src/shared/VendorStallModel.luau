-- The cactus vendor's stall (QM, Oct 27): LassoAPet's Carl stall, copied from its
-- src/shared/CarlStallModel.luau (made by its tools/carl_stall.py from QM's
-- designs/stall/CarlStall.bbmodel). The egg heap's LassoAPet-only eggs are swapped for ones
-- this game has, each about the same size (Kraken -> Cactus, Loong -> Boar, RoboShark ->
-- Rhino, BlueCrab -> Penguin).
-- Studs, ground at Y = 0, the counter facing -Z (a Vendor object's yaw turns it).

return {
	parts = {
		{ name = "Post", size = Vector3.new(0.6, 10.8, 1.2), cframe = CFrame.new(8.1, 5.4, 4.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(112, 74, 46) },
		{ name = "Post", size = Vector3.new(0.6, 10.8, 1.2), cframe = CFrame.new(8.1, 5.4, -4.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(112, 74, 46) },
		{ name = "Post", size = Vector3.new(0.6, 10.8, 1.2), cframe = CFrame.new(-8.1, 5.4, 4.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(112, 74, 46) },
		{ name = "Post", size = Vector3.new(0.6, 10.8, 1.2), cframe = CFrame.new(-8.1, 5.4, -4.2, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(112, 74, 46) },
		{ name = "Beam", size = Vector3.new(1.8, 2.4, 12.6), cframe = CFrame.new(8.65, 10.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(150, 100, 62) },
		{ name = "Beam", size = Vector3.new(1.8, 2.4, 12.6), cframe = CFrame.new(-8.65, 10.8, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(150, 100, 62) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(-3.8575, 13.8779, 4.08, 0.9239, -0.3827, 0, 0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(3.8575, 13.8779, 4.08, 0.9239, 0.3827, 0, -0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(-3.8575, 13.8779, 2.04, 0.9239, -0.3827, 0, 0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(250, 246, 236) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(3.8575, 13.8779, 2.04, 0.9239, 0.3827, 0, -0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(250, 246, 236) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(-3.8575, 13.8779, 0, 0.9239, -0.3827, 0, 0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(3.8575, 13.8779, 0, 0.9239, 0.3827, 0, -0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(-3.8575, 13.8779, -2.04, 0.9239, -0.3827, 0, 0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(250, 246, 236) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(3.8575, 13.8779, -2.04, 0.9239, 0.3827, 0, -0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(250, 246, 236) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(-3.8575, 13.8779, -4.08, 0.9239, -0.3827, 0, 0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Cloth", size = Vector3.new(9, 0.6, 2.04), cframe = CFrame.new(3.8575, 13.8779, -4.08, 0.9239, 0.3827, 0, -0.3827, 0.9239, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Ridge", size = Vector3.new(1.8, 1.2, 11.4), cframe = CFrame.new(0, 15.9, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(150, 100, 62) },
		{ name = "Counter", size = Vector3.new(14.4, 3.3, 2.4), cframe = CFrame.new(0, 1.65, -2.1, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(186, 132, 82) },
		{ name = "CounterTop", size = Vector3.new(15.6, 0.9, 3.3), cframe = CFrame.new(0, 3.75, -2.25, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(150, 100, 62) },
		{ name = "CactusArm", size = Vector3.new(2.52, 1.44, 1.44), cframe = CFrame.new(8.34, 4.22, 1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(118, 204, 64) },
		{ name = "CactusArm", size = Vector3.new(1.44, 2.76, 1.44), cframe = CFrame.new(8.88, 6.32, 1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(118, 204, 64) },
		{ name = "Flower", size = Vector3.new(1.44, 0.84, 1.44), cframe = CFrame.new(6, 8.12, 1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(255, 110, 170) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2), cframe = CFrame.new(-9, 11.5, -4.1, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2), cframe = CFrame.new(-9, 11.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2), cframe = CFrame.new(-9, 11.5, 4.1, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2.1), cframe = CFrame.new(-9, 11.5, 2.05, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(250, 246, 236) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2.1), cframe = CFrame.new(-9, 11.5, -2.05, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(250, 246, 236) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2.1), cframe = CFrame.new(9, 11.5, 2.05, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(250, 246, 236) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2), cframe = CFrame.new(9, 11.5, 4.1, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2), cframe = CFrame.new(9, 11.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2.1), cframe = CFrame.new(9, 11.5, -2.05, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(250, 246, 236) },
		{ name = "Beam", size = Vector3.new(2.4, 2.2, 2), cframe = CFrame.new(9, 11.5, -4.1, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(226, 60, 72) },
		{ name = "Cactus", size = Vector3.new(2.16, 8, 2.16), cframe = CFrame.new(6, 3.7, 1.7, 1, 0, 0, 0, 1, 0, 0, 0, 1), color = Color3.fromRGB(118, 204, 64) },
	},
	carl = Vector3.new(0, 0, 2.1), -- his feet
	pile = { -- the egg heap behind him: each egg's pivot (Egg.new's model, its real size)
		{ kind = "Cactus", cframe = CFrame.new(0, 5.4, 11, 0.9801, 0, 0.1987, 0, 1, 0, -0.1987, 0, 0.9801) },
		{ kind = "Snake", cframe = CFrame.new(-7.3154, 3.582, 8.6723, 0.8732, -0.0876, 0.4794, 0.0998, 0.995, 0, -0.477, 0.0479, 0.8776) },
		{ kind = "Icebringer", cframe = CFrame.new(7.3154, 3.582, 8.6723, 0.8732, 0.0876, -0.4794, -0.0998, 0.995, 0, 0.477, 0.0479, 0.8776) },
		{ kind = "SnackYak", cframe = CFrame.new(-8.4, 2.4, 13.6, 0.6967, 0, 0.7174, 0, 1, 0, -0.7174, 0, 0.6967) },
		{ kind = "Penguin", cframe = CFrame.new(8.4, 2.4, 13.6, 0.7648, 0, -0.6442, 0, 1, 0, 0.6442, 0, 0.7648) },
		{ kind = "Boar", cframe = CFrame.new(8.6, 1.6, 5.4, 0.9553, 0, -0.2955, 0, 1, 0, 0.2955, 0, 0.9553) },
		{ kind = "Rhino", cframe = CFrame.new(-8.6, 1.6, 5.4, 0.9211, 0, 0.3894, 0, 1, 0, -0.3894, 0, 0.9211) },
		{ kind = "Unicorn", cframe = CFrame.new(-5.5973, 9.5611, 8.9085, 0.8602, -0.4155, 0.2955, 0.435, 0.9004, 0, -0.2661, 0.1285, 0.9553) },
		{ kind = "Penguin", cframe = CFrame.new(5.3714, 10.0105, 9.5277, 0.7602, 0.3214, -0.5646, -0.3894, 0.9211, 0, 0.5201, 0.2199, 0.8253) },
		{ kind = "Icebringer", cframe = CFrame.new(-4.3855, 12.0392, 14.3916, 0.3462, -0.1071, 0.932, 0.2955, 0.9553, 0, -0.8904, 0.2754, 0.3624) },
		{ kind = "Snake", cframe = CFrame.new(4.7748, 12.2392, 14.6952, 0.5162, 0.1597, -0.8415, -0.2955, 0.9553, 0, 0.8039, 0.2487, 0.5403) },
		{ kind = "Boar", cframe = CFrame.new(-2.1902, 14.3285, 10.467, 0.7885, -0.2439, 0.5646, 0.2955, 0.9553, 0, -0.5394, 0.1669, 0.8253) },
		{ kind = "Rhino", cframe = CFrame.new(2.5646, 14.5503, 11.1541, 0.8924, 0.2279, -0.3894, -0.2474, 0.9689, 0, 0.3773, 0.0963, 0.9211) },
		{ kind = "Unicorn", cframe = CFrame.new(0.0806, 17.597, 12.612, 0.9938, -0.0497, 0.0998, 0.05, 0.9988, 0, -0.0997, 0.005, 0.995) },
	},
}
