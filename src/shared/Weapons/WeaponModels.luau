-- Block models for every weapon QM hasn't drawn yet (the drawn ones are designs/weapons/
-- *.bbmodel, converted to <Name>Model.luau), in the same shape Rig.fromData reads: one
-- bone, parts in studs.
-- Like the sword, each points up its +Y with the hand round the grip at y -0.5..0, so a
-- tool holds them all the same way (Weapons.makeTool). Hand-made, block by block: change
-- them here, or draw a .bbmodel and swap one for its generated module.

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local WOOD = rgb(117, 71, 34)
local GOLD = rgb(234, 212, 0)
local WHITE = rgb(255, 255, 255)
local IVORY = rgb(246, 236, 210)

-- one block: size, centre, colour, and optional tilt round Z (degrees, in the X-Y plane)
-- and spin round Y; extra flags (neon, plain, shape) go in `opts`
local function block(size, pos, color, tiltZ, opts)
	opts = opts or {}
	local cf = CFrame.new(pos)
		* CFrame.Angles(0, math.rad(opts.spinY or 0), 0)
		* CFrame.Angles(0, 0, math.rad(tiltZ or 0))
	return {
		name = "cube",
		bone = "weapon",
		class = "Part",
		size = size,
		cframe = cf,
		color = color,
		neon = opts.neon,
		plain = opts.plain or opts.neon or opts.shape ~= nil,
		shape = opts.shape,
	}
end

local function model(parts)
	return {
		bones = { { name = "weapon", parent = nil, pivot = Vector3.zero } },
		parts = parts,
		animations = {},
	}
end

local V = Vector3.new

-- the unicorn's horn: a twisting stack, each block narrower and turned a little more
local horn = { block(V(0.36, 0.5, 0.36), V(0, -0.25, 0), rgb(255, 214, 236)) }
for i = 0, 5 do
	local w = 0.5 - i * 0.07
	local color = if i % 2 == 0 then WHITE else rgb(255, 196, 228)
	table.insert(horn, block(V(w, 0.45, w), V(0, 0.2 + i * 0.42, 0), color, 0, { spinY = i * 30 }))
end
table.insert(horn, block(V(0.12, 0.3, 0.12), V(0, 2.8, 0), rgb(255, 240, 160), 0, { neon = true, spinY = 45 }))

-- the elder boar's tusk: a curving ivory blade on a fur-wrapped grip
local tusk = {
	block(V(0.22, 0.5, 0.22), V(0, -0.25, 0), rgb(92, 64, 44)),
	block(V(0.8, 0.3, 0.5), V(0, 0.1, 0), rgb(120, 98, 82)),
}
for _, s in {
	{ 0.5, 0.7, 0, 0.6, 0 },
	{ 0.45, 0.7, 0.07, 1.2, -8 },
	{ 0.38, 0.65, 0.2, 1.78, -16 },
	{ 0.3, 0.6, 0.4, 2.28, -26 },
	{ 0.2, 0.5, 0.65, 2.68, -38 },
} do
	table.insert(tusk, block(V(s[1], s[2], 0.3), V(s[3], s[4], 0), IVORY, s[5]))
end

-- the flytrap: a stem, two jaws open in a V, red insides and white teeth
local flytrap = {
	block(V(0.22, 0.5, 0.22), V(0, -0.25, 0), rgb(60, 120, 50)),
	block(V(0.2, 1.1, 0.2), V(0, 0.45, 0), rgb(90, 170, 60)),
	block(V(1.0, 0.3, 0.7), V(0.25, 1.05, 0), rgb(110, 200, 70), -18),
	block(V(1.0, 0.3, 0.7), V(0.25, 1.6, 0), rgb(110, 200, 70), 28),
	block(V(0.9, 0.06, 0.6), V(0.28, 1.21, 0), rgb(235, 60, 80), -18, { neon = true }),
	block(V(0.9, 0.06, 0.6), V(0.3, 1.45, 0), rgb(235, 60, 80), 28, { neon = true }),
}
for i = 0, 2 do
	local x = 0.0 + i * 0.3
	table.insert(flytrap, block(V(0.1, 0.22, 0.1), V(x + 0.1, 1.3 - x * 0.33, 0.22), WHITE, -18))
	table.insert(flytrap, block(V(0.1, 0.22, 0.1), V(x + 0.1, 1.38 + x * 0.53, 0.22), WHITE, 28))
end

-- the cactus needler: a cactus on a handle, spines sticking out
local cactus = {
	block(V(0.22, 0.5, 0.22), V(0, -0.25, 0), WOOD),
	block(V(0.55, 1.6, 0.55), V(0, 0.8, 0), rgb(84, 168, 74)),
	block(V(0.3, 0.6, 0.3), V(0.45, 1.0, 0), rgb(84, 168, 74)),
	block(V(0.3, 0.5, 0.3), V(-0.45, 1.3, 0), rgb(84, 168, 74)),
	block(V(0.3, 0.3, 0.3), V(0.45, 1.45, 0), rgb(84, 168, 74)),
	block(V(0.3, 0.3, 0.3), V(-0.45, 1.7, 0), rgb(84, 168, 74)),
	block(V(0.3, 0.25, 0.3), V(0, 1.7, 0), rgb(255, 120, 160), 45, { neon = true }),
}
for i = 0, 3 do
	table.insert(cactus, block(V(0.06, 0.06, 0.3), V(0.2 - (i % 2) * 0.4, 0.3 + i * 0.35, 0.36), IVORY, 0, { plain = true }))
end

return {
	GoldenEgg = model({
		block(V(0.8, 0.8, 0.8), V(0, 0.15, 0), rgb(255, 205, 60), 0, { shape = "Ball" }),
		block(V(0.64, 0.64, 0.64), V(0, 0.48, 0), rgb(255, 214, 90), 0, { shape = "Ball" }),
		block(V(0.2, 0.2, 0.2), V(0.22, 0.4, -0.25), rgb(255, 250, 220), 0, { neon = true, shape = "Ball" }),
	}),
	UnicornHorn = model(horn),
	VenusFlytrap = model(flytrap),
	CactusNeedler = model(cactus),
	ElderTusk = model(tusk),
	WyrmFangStaff = model({
		block(V(0.2, 3.0, 0.2), V(0, 0.5, 0), rgb(70, 56, 52)),
		block(V(0.16, 0.7, 0.16), V(-0.22, 2.2, 0), IVORY, 18),
		block(V(0.16, 0.7, 0.16), V(0.22, 2.2, 0), IVORY, -18),
		block(V(0.12, 0.3, 0.12), V(-0.36, 2.62, 0), IVORY, 40),
		block(V(0.12, 0.3, 0.12), V(0.36, 2.62, 0), IVORY, -40),
		block(V(0.5, 0.5, 0.5), V(0, 2.3, 0), rgb(255, 90, 30), 45, { neon = true }),
	}),
}
