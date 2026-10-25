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
local DARK_WOOD = rgb(78, 48, 26)
local GOLD = rgb(234, 212, 0)
local STEEL = rgb(214, 220, 228)
local STEEL_DARK = rgb(150, 158, 170)
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

-- a bow's limbs, curving from the grip out to tips at x = 0.5 (times `k`: a longbow is
-- taller), its string, and any extra blocks
local function bow(limb, string, k, extra)
	k = k or 1
	local parts = { block(V(0.24, 0.5, 0.24), V(0, -0.25, 0), DARK_WOOD) }
	for _, s in { 1, -1 } do
		local function at(x, y)
			return V(x, -0.25 + s * y * k, 0)
		end
		table.insert(parts, block(V(0.16, 0.6 * k, 0.16), at(0.08, 0.5), limb, s * -12))
		table.insert(parts, block(V(0.15, 0.6 * k, 0.15), at(0.24, 1.0), limb, s * -28))
		table.insert(parts, block(V(0.14, 0.5 * k, 0.14), at(0.44, 1.38), limb, s * -42))
	end
	table.insert(parts, block(V(0.04, 3.1 * k, 0.04), V(0.56, -0.25, 0), string, 0, { plain = true }))
	for _, part in extra or {} do
		table.insert(parts, part)
	end
	return parts
end

-- a staff: a long shaft, two prongs and a glowing gem (or ball) at the top
local function staff(shaft, prong, gem, ball)
	return {
		block(V(0.18, 3.0, 0.18), V(0, 0.5, 0), shaft),
		block(V(0.12, 0.5, 0.12), V(-0.18, 2.15, 0), prong, 20),
		block(V(0.12, 0.5, 0.12), V(0.18, 2.15, 0), prong, -20),
		if ball
			then block(V(0.5, 0.5, 0.5), V(0, 2.3, 0), gem, 0, { neon = true, shape = "Ball" })
			else block(V(0.4, 0.4, 0.4), V(0, 2.25, 0), gem, 45, { neon = true }),
	}
end

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

-- the rafflesia bloom: five red petals round a yellow middle
local bloom = {
	block(V(0.22, 0.5, 0.22), V(0, -0.25, 0), rgb(60, 110, 50)),
	block(V(0.16, 1.1, 0.16), V(0, 0.45, 0), rgb(80, 150, 60)),
}
for i = 0, 4 do
	local a = math.rad(i * 72)
	table.insert(
		bloom,
		block(V(0.55, 0.5, 0.12), V(math.sin(a) * 0.36, 1.2 + math.cos(a) * 0.36, 0), rgb(220, 60, 70), -i * 72)
	)
end
table.insert(bloom, block(V(0.32, 0.32, 0.16), V(0, 1.2, 0.04), rgb(255, 220, 90), 45, { neon = true }))

return {
	Shortbow = model(bow(WOOD, WHITE, 0.8)),
	Longbow = model(bow(rgb(140, 92, 50), WHITE, 1.3)),
	NatureBow = model(bow(rgb(70, 160, 90), WHITE, 1, {
		block(V(0.3, 0.12, 0.2), V(0.2, 0.55, 0.1), rgb(120, 220, 90), 30),
		block(V(0.3, 0.12, 0.2), V(0.2, -1.05, 0.1), rgb(120, 220, 90), -30),
		block(V(0.18, 0.18, 0.18), V(0, -0.25, 0.14), rgb(160, 255, 120), 45, { neon = true }),
	})),
	BloodBow = model(bow(rgb(90, 20, 30), rgb(255, 120, 130), 1.1, {
		block(V(0.2, 0.2, 0.2), V(0, -0.25, 0.14), rgb(230, 30, 50), 45, { neon = true }),
		block(V(0.12, 0.3, 0.12), V(0.62, 1.45, 0), rgb(220, 220, 220), -50),
		block(V(0.12, 0.3, 0.12), V(0.62, -1.95, 0), rgb(220, 220, 220), 50),
	})),
	Crossbow = model({
		block(V(0.24, 0.5, 0.24), V(0, -0.25, 0), DARK_WOOD),
		block(V(0.26, 1.6, 0.3), V(0, 0.75, 0), WOOD),
		block(V(1.7, 0.16, 0.16), V(0, 1.35, 0), STEEL_DARK),
		block(V(1.6, 0.04, 0.04), V(0, 1.15, 0), WHITE, 0, { plain = true }),
		block(V(0.08, 1.1, 0.08), V(0, 1.2, 0.2), rgb(200, 40, 40)),
	}),
	WindStaff = model(staff(rgb(220, 226, 230), rgb(170, 220, 210), rgb(200, 255, 240), true)),
	LightningStaff = model(staff(rgb(60, 60, 80), rgb(255, 230, 90), rgb(255, 244, 120))),
	WaterStaff = model(staff(rgb(40, 90, 150), rgb(120, 200, 255), rgb(70, 160, 255), true)),
	FireStaff = model(staff(WOOD, DARK_WOOD, rgb(255, 130, 40))),
	Bomb = model({
		block(V(1.0, 1.0, 1.0), V(0, 0.3, 0), rgb(40, 40, 48), 0, { shape = "Ball" }),
		block(V(0.3, 0.16, 0.3), V(0, 0.82, 0), rgb(90, 90, 100)),
		block(V(0.08, 0.35, 0.08), V(0.05, 1.05, 0), rgb(120, 90, 60), -15),
		block(V(0.16, 0.16, 0.16), V(0.1, 1.24, 0), rgb(255, 170, 60), 0, { neon = true, shape = "Ball" }),
	}),
	GoldenEgg = model({
		block(V(0.8, 0.8, 0.8), V(0, 0.15, 0), rgb(255, 205, 60), 0, { shape = "Ball" }),
		block(V(0.64, 0.64, 0.64), V(0, 0.48, 0), rgb(255, 214, 90), 0, { shape = "Ball" }),
		block(V(0.2, 0.2, 0.2), V(0.22, 0.4, -0.25), rgb(255, 250, 220), 0, { neon = true, shape = "Ball" }),
	}),
	RafflesiaBloom = model(bloom),
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
