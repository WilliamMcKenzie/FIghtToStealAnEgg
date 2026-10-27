-- The cactus vendor's stall (QM, Oct 27): LassoAPet's Carl stall, copied from its
-- src/shared/CarlStallModel.luau (made by its tools/carl_stall.py from QM's
-- designs/stall/CarlStall.bbmodel), with weapons piled behind it instead of Lasso's eggs.
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
	-- behind him, his stock (QM, Oct 27: weapons, not Lasso's eggs): two wooden crates, and
	-- weapons stuck in the ground, leaning on the crates and lying on top of them. Each
	-- weapon: { id, x, z, yaw, tiltX, tiltZ, down?, base? } in radians: tiltX leans its top
	-- toward +z, tiltZ toward -x; down sticks it point first into the ground; base is the
	-- height it rests on (a crate's top), else the ground. Server/Map builds them once,
	-- static (Shared/Weapons' drawn models, anchored).
	crates = {
		{ size = Vector3.new(5, 2.6, 3.4), cframe = CFrame.new(-3.5, 1.3, 9.5), color = Color3.fromRGB(150, 100, 62) },
		{ size = Vector3.new(4, 2, 3), cframe = CFrame.new(3.8, 1, 10.5) * CFrame.Angles(0, math.rad(12), 0), color = Color3.fromRGB(186, 132, 82) },
	},
	weaponScale = 1.3, -- times a held weapon's size
	weapons = {
		{ "Longsword", -7.4, 8, 0.3, 0, 0.25, true },
		{ "Longsword", 7.4, 8, -0.4, 0, -0.3, true },
		{ "Shortsword", -0.6, 12.8, 0.2, -0.2, 0.1, true },
		{ "Axe", 4, 8.4, 0.2, 0.35, 0 },
		{ "Waraxe", -3, 12.4, 2.8, -0.35, 0 },
		{ "Staff", -6.8, 10.6, 0, 0, -0.3 },
		{ "WindStaff", -6.6, 8.9, 1, 0, -0.22 },
		{ "LightningStaff", 6.4, 11.6, 0, 0, 0.3 },
		{ "FireStaff", 3, 12.8, 0.4, -0.35, 0 },
		{ "Longbow", -3.5, 9.5, 0.25, math.pi / 2, 0, false, 2.6 },
		{ "Shortbow", 3.8, 10.5, -0.5, math.pi / 2, 0, false, 2 },
		{ "KendoStick", 0.6, 14.2, 1, math.pi / 2, 0 },
	},
}
