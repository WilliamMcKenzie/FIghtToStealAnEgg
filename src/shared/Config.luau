-- Tuning for the whole game. Slash values can also be tuned live in a Studio playtest:
-- edit the attributes on workspace.SlashTuning (see Shared/SlashTuning.luau), then tick
-- its PrintConfig to print the values to paste back here.

return {
	-- Rig.luau / Studs.luau: studs as stud Textures for now (no stud MaterialVariants yet)
	StudMaterial = false,
	FineStuds = {},
	AnimalScale = {},
	StudTransparency = 0.5, -- every stud Texture (floor, walls, sword, horse): 0.5 = half strength (QM, Oct 24)

	-- the horse everyone starts on (Animals/Horse.luau): its size, times the Blockbench drawing
	-- (every pet's speed: its rarity's, PetStats below)
	HorseSize = 0.6,

	-- every world colour, by the ColorKey attribute on the parts (and checker Textures)
	-- that wear it. Live-tunable in Play through workspace.WorldColors (Shared/WorldColors).
	WorldColors = {
		Grass = Color3.fromRGB(148, 181, 26),
		GrassChecker = Color3.fromRGB(163, 194, 15),
		Dirt = Color3.fromRGB(200, 149, 71),
		DirtChecker = Color3.fromRGB(189, 141, 67),
		WallDirt = Color3.fromRGB(133, 90, 50),
		WallDirtChecker = Color3.fromRGB(143, 98, 56),
		PineTrunk = Color3.fromRGB(120, 84, 58),
		PineNeedlesA = Color3.fromRGB(46, 125, 80),
		PineNeedlesB = Color3.fromRGB(58, 140, 88),
		PineNeedlesC = Color3.fromRGB(40, 112, 72),
		PineNeedlesD = Color3.fromRGB(66, 150, 96),
		Stone = Color3.fromRGB(214, 216, 206),
		RegionBarrier = Color3.fromRGB(0, 28, 78), -- #001C4E: a locked region's blocker and its shadow (Shared/RegionBlocker)
		StoneDark = Color3.fromRGB(176, 178, 168),

		-- the map (tools/map_gen.py lays it out, Server/Map.luau builds it). Each floor
		-- tile's Checker is its checker's colour.
		-- the base: Grass and Dirt (above, the dirt a stud lower) are its floor, WallDirt its wall
		Wood = Color3.fromRGB(150, 98, 56),
		WoodDark = Color3.fromRGB(110, 72, 42),
		Straw = Color3.fromRGB(226, 196, 110),
		NestStick = Color3.fromRGB(143, 74, 44), -- (the nests' woven sticks: LassoAPet's, QM Oct 25)
		NestStickDark = Color3.fromRGB(110, 56, 34),
		StrawDark = Color3.fromRGB(196, 164, 84),
		Egg = Color3.fromRGB(250, 246, 232),
		EggSpot = Color3.fromRGB(150, 200, 90),
		Sign = Color3.fromRGB(58, 46, 38),
		-- Meadow (QM, Oct 24: all grass, a dirt circle for the boss, a few ponds)
		MeadowWater = Color3.fromRGB(76, 156, 222),
		MeadowWaterChecker = Color3.fromRGB(90, 170, 232),
		MeadowGrass = Color3.fromRGB(148, 181, 26),
		MeadowGrassChecker = Color3.fromRGB(163, 194, 15),
		MeadowDirt = Color3.fromRGB(200, 149, 71),
		MeadowDirtChecker = Color3.fromRGB(189, 141, 67),
		MeadowWall = Color3.fromRGB(133, 90, 50),
		MeadowWallChecker = Color3.fromRGB(143, 98, 56),
		MeadowCap = Color3.fromRGB(148, 181, 26),
		MeadowCapChecker = Color3.fromRGB(163, 194, 15),
		MeadowPillar = Color3.fromRGB(168, 184, 108), -- (its pillars, ruins and stone props: QM, Oct 24, in the biome's colours)
		MeadowPillarDark = Color3.fromRGB(134, 152, 82),
		-- Desert (as LassoAPet's: dry grass a stud down, sand, sandstone a stud up)
		DesertDryGrass = Color3.fromRGB(178, 170, 76),
		DesertDryGrassChecker = Color3.fromRGB(190, 180, 86),
		DesertSand = Color3.fromRGB(232, 188, 102),
		DesertSandChecker = Color3.fromRGB(246, 208, 124),
		DesertSandstone = Color3.fromRGB(206, 146, 84),
		DesertSandstoneChecker = Color3.fromRGB(222, 164, 100),
		DesertWall = Color3.fromRGB(206, 118, 72),
		DesertWallChecker = Color3.fromRGB(226, 138, 88),
		DesertCap = Color3.fromRGB(222, 164, 100),
		DesertCapChecker = Color3.fromRGB(232, 176, 112),
		DesertPillar = Color3.fromRGB(226, 178, 112),
		DesertPillarDark = Color3.fromRGB(202, 148, 90),
		-- Ice (cold grass a stud down, snow, glacier ice a stud up)
		IceColdGrass = Color3.fromRGB(80, 160, 166),
		IceColdGrassChecker = Color3.fromRGB(96, 176, 180),
		IceSnow = Color3.fromRGB(228, 234, 242),
		IceSnowChecker = Color3.fromRGB(244, 247, 251),
		IceGlacier = Color3.fromRGB(160, 188, 244),
		IceGlacierChecker = Color3.fromRGB(178, 202, 250),
		IceWall = Color3.fromRGB(126, 164, 214),
		IceWallChecker = Color3.fromRGB(146, 182, 228),
		IceCap = Color3.fromRGB(244, 247, 251),
		IceCapChecker = Color3.fromRGB(232, 238, 246),
		IcePillar = Color3.fromRGB(204, 222, 246),
		IcePillarDark = Color3.fromRGB(164, 192, 232),
		-- Lava (glowing magma pools a stud down, light volcanic rock, dark basalt a stud up)
		LavaMagma = Color3.fromRGB(255, 116, 24),
		LavaMagmaChecker = Color3.fromRGB(255, 146, 40),
		LavaRock = Color3.fromRGB(156, 98, 66),
		LavaRockChecker = Color3.fromRGB(168, 108, 74),
		LavaBasalt = Color3.fromRGB(84, 66, 62),
		LavaBasaltChecker = Color3.fromRGB(94, 74, 68),
		LavaWall = Color3.fromRGB(170, 92, 58),
		LavaWallChecker = Color3.fromRGB(186, 104, 66),
		LavaCap = Color3.fromRGB(96, 60, 46),
		LavaCapChecker = Color3.fromRGB(106, 68, 52),
		LavaPillar = Color3.fromRGB(104, 80, 70),
		LavaPillarDark = Color3.fromRGB(76, 60, 56),
		-- past the Lava, the left fork (QM, Oct 24): the Abandoned Dungeon (green and blue tinged
		-- stone, near-black walls, green glows), then the Red Castle (crimson carpet on dark
		-- purplish grey stone)
		DungeonStone = Color3.fromRGB(74, 96, 86),
		DungeonStoneChecker = Color3.fromRGB(82, 106, 94),
		DungeonSlate = Color3.fromRGB(66, 82, 102),
		DungeonSlateChecker = Color3.fromRGB(74, 91, 112),
		DungeonWall = Color3.fromRGB(38, 40, 44),
		DungeonWallChecker = Color3.fromRGB(45, 47, 52),
		DungeonCap = Color3.fromRGB(54, 58, 60),
		DungeonCapChecker = Color3.fromRGB(61, 65, 67),
		DungeonPillar = Color3.fromRGB(84, 92, 92),
		DungeonPillarDark = Color3.fromRGB(58, 64, 66),
		CastleCarpet = Color3.fromRGB(156, 22, 42),
		CastleCarpetChecker = Color3.fromRGB(170, 30, 52),
		CastleFloor = Color3.fromRGB(78, 70, 86),
		CastleFloorChecker = Color3.fromRGB(87, 78, 95),
		CastleWall = Color3.fromRGB(112, 34, 42),
		CastleWallChecker = Color3.fromRGB(124, 40, 48),
		CastleCap = Color3.fromRGB(70, 62, 78),
		CastleCapChecker = Color3.fromRGB(78, 70, 86),
		CastlePillar = Color3.fromRGB(132, 116, 132),
		CastlePillarDark = Color3.fromRGB(100, 86, 102),
		-- the right fork's first biome (QM, Oct 24): the Magic Forest, turquoise grass and blue stone
		ForestGrass = Color3.fromRGB(56, 196, 168),
		ForestGrassChecker = Color3.fromRGB(66, 208, 178),
		ForestStone = Color3.fromRGB(96, 124, 214),
		ForestStoneChecker = Color3.fromRGB(106, 134, 224),
		ForestWall = Color3.fromRGB(112, 140, 222),
		ForestWallChecker = Color3.fromRGB(124, 152, 230),
		ForestCap = Color3.fromRGB(56, 196, 168),
		ForestCapChecker = Color3.fromRGB(66, 208, 178),
		ForestPillar = Color3.fromRGB(150, 176, 240),
		ForestPillarDark = Color3.fromRGB(112, 140, 222),
		-- after the Forest (QM, Oct 24): the Ocean Trench, pale blue sand, darker blue stone
		OceanSand = Color3.fromRGB(140, 200, 236),
		OceanSandChecker = Color3.fromRGB(152, 210, 242),
		OceanStone = Color3.fromRGB(60, 92, 188),
		OceanStoneChecker = Color3.fromRGB(68, 102, 198),
		OceanWall = Color3.fromRGB(48, 76, 170),
		OceanWallChecker = Color3.fromRGB(56, 86, 182),
		OceanCap = Color3.fromRGB(60, 92, 188),
		OceanCapChecker = Color3.fromRGB(68, 102, 198),
		OceanPillar = Color3.fromRGB(76, 110, 204),
		OceanPillarDark = Color3.fromRGB(52, 82, 176),
		-- props (tools/ruin_assets.py): ruins take their biome's Pillar colours
		CactusGreen = Color3.fromRGB(92, 168, 70),
		CactusFlower = Color3.fromRGB(255, 120, 170),
		SnowPineNeedles = Color3.fromRGB(52, 112, 96),
		Snow = Color3.fromRGB(244, 248, 252),
		DeadWood = Color3.fromRGB(70, 56, 50),
		Bone = Color3.fromRGB(232, 222, 196), -- (femur, ribcage, skull: QM, Oct 24, for the Lava zone)
		BoneDark = Color3.fromRGB(150, 136, 112), -- (eye sockets, horns, the ribcage's spine)
		-- boulders and monoliths, each biome's own (QM, Oct 24); runes are Neon and glow.
		-- Base's go unprefixed (Boulder, Monolith, Rune), the biomes' as MeadowBoulder etc.
		Boulder = Color3.fromRGB(150, 152, 146),
		BoulderDark = Color3.fromRGB(118, 120, 116),
		Monolith = Color3.fromRGB(96, 98, 106),
		MonolithDark = Color3.fromRGB(68, 70, 78),
		Rune = Color3.fromRGB(110, 200, 255),
		MeadowBoulder = Color3.fromRGB(140, 146, 124),
		MeadowBoulderDark = Color3.fromRGB(106, 116, 92),
		MeadowMonolith = Color3.fromRGB(118, 128, 104),
		MeadowMonolithDark = Color3.fromRGB(86, 98, 74),
		MeadowRune = Color3.fromRGB(120, 255, 140),
		DesertBoulder = Color3.fromRGB(198, 140, 92),
		DesertBoulderDark = Color3.fromRGB(164, 108, 70),
		DesertMonolith = Color3.fromRGB(212, 166, 106),
		DesertMonolithDark = Color3.fromRGB(176, 130, 80),
		DesertRune = Color3.fromRGB(255, 214, 90),
		IceBoulder = Color3.fromRGB(152, 178, 206),
		IceBoulderDark = Color3.fromRGB(112, 142, 178),
		IceMonolith = Color3.fromRGB(122, 160, 210),
		IceMonolithDark = Color3.fromRGB(86, 124, 178),
		IceRune = Color3.fromRGB(130, 236, 255),
		LavaBoulder = Color3.fromRGB(64, 54, 52),
		LavaBoulderDark = Color3.fromRGB(44, 38, 38),
		LavaMonolith = Color3.fromRGB(104, 80, 70),
		LavaMonolithDark = Color3.fromRGB(76, 60, 56),
		LavaRune = Color3.fromRGB(255, 120, 40),
		DungeonBoulder = Color3.fromRGB(70, 78, 78),
		DungeonBoulderDark = Color3.fromRGB(50, 56, 58),
		DungeonMonolith = Color3.fromRGB(56, 62, 66),
		DungeonMonolithDark = Color3.fromRGB(40, 44, 48),
		DungeonRune = Color3.fromRGB(90, 255, 140),
		CastleBoulder = Color3.fromRGB(96, 86, 102),
		CastleBoulderDark = Color3.fromRGB(72, 64, 78),
		CastleMonolith = Color3.fromRGB(88, 78, 96),
		CastleMonolithDark = Color3.fromRGB(64, 56, 72),
		CastleRune = Color3.fromRGB(255, 70, 90),
		ForestBoulder = Color3.fromRGB(120, 146, 224),
		ForestBoulderDark = Color3.fromRGB(90, 114, 196),
		ForestMonolith = Color3.fromRGB(128, 156, 232),
		ForestMonolithDark = Color3.fromRGB(96, 122, 204),
		ForestRune = Color3.fromRGB(110, 220, 255),
		OceanBoulder = Color3.fromRGB(64, 96, 190),
		OceanBoulderDark = Color3.fromRGB(46, 72, 160),
		OceanMonolith = Color3.fromRGB(70, 104, 198),
		OceanMonolithDark = Color3.fromRGB(50, 78, 168),
		OceanRune = Color3.fromRGB(120, 255, 230),
		-- the new biomes' decor (tools/ruin_assets.py); flames are Neon and light up
		Iron = Color3.fromRGB(84, 88, 96),
		IronDark = Color3.fromRGB(52, 54, 60),
		DungeonFlame = Color3.fromRGB(90, 255, 130),
		Gold = Color3.fromRGB(214, 168, 72),
		CandleWax = Color3.fromRGB(242, 232, 206),
		CandleFlame = Color3.fromRGB(255, 196, 92),
		ForestTrunk = Color3.fromRGB(92, 64, 82), -- (palms: LassoAPet's mesh, dark purple-brown trunks)
		ForestTrunkDark = Color3.fromRGB(74, 50, 68),
		ForestFrond = Color3.fromRGB(36, 150, 132), -- (the grass's turquoise, darker)
		ForestFrondDark = Color3.fromRGB(28, 124, 112),
		ForestFruit = Color3.fromRGB(150, 96, 200),
		ForestPodium = Color3.fromRGB(150, 176, 240),
		ForestPodiumDark = Color3.fromRGB(104, 130, 214),
		ForestCandleWax = Color3.fromRGB(226, 220, 246),
		ForestFlame = Color3.fromRGB(96, 196, 255),
		Kelp = Color3.fromRGB(60, 168, 128), -- (the Ocean's decor, after QM's reference)
		KelpDark = Color3.fromRGB(44, 136, 108),
		Starfish = Color3.fromRGB(255, 112, 64),
		Sponge = Color3.fromRGB(92, 92, 230),
		SpongeRock = Color3.fromRGB(52, 60, 108),
		Coral = Color3.fromRGB(226, 72, 170),
	},

	-- the map (Server/Map.luau builds it from Shared/MapData, made by tools/map_gen.py)
	Map = {
		HideLineup = true, -- move tools/lineup.luau's workspace.World (and a Baseplate) out of the way when the map is built (Edit: into ServerStorage.MovedByMapBaker)
		LiquidSlow = 0.8, -- walking through a biome's liquid (water, magma): this much of your speed (QM, Oct 24)
		LiquidSink = 1, -- and you sink this far into it, below its surface
	},

	-- bosses (server/Bosses.luau, client/BossView.luau). Each biome's sleeps in its arena's
	-- middle until someone steals one of its eggs or hits it (Server/Eggs); /boss spawns a
	-- Chicken in front of you. Model is a module in Shared/Animals (<Model>Model.luau),
	-- Size times its Blockbench drawing. Strength is what each hit on it trains (x the damage
	-- you dealt: Config.Training). Health (QM, Oct 25): Mother Hen is
	-- 20 Kendo Stick hits at 0 Strength and 5 at 1,000 (Config.Power); each later boss takes 20,
	-- 30, 40, 50 Kendo Stick hits at the Strength you'd have reaching it: Meadow's at 0, Cactus
	-- Boss at 2,000, Elder Boar at 18,000, Lava Wyrm at 140,000.
	Bosses = {
		Chicken = {
			Model = "Chicken",
			Size = 1, -- times the Blockbench drawing (about 10.5 studs tall)
			Health = 300,
			Speed = 9, -- studs/s, chasing the nearest player
			StopAt = 4, -- stops this far from them (studs, from its edge)
			Radius = 3, -- its body's half-width, for reach and hits
			Turn = 4, -- how fast it turns to face its target
			Strength = 1,
		},
		MotherHen = {
			Name = "Mother Hen",
			Model = "Chicken",
			Size = 3.84, -- (about 40 studs tall: QM, Oct 25, 1.6x)
			Health = 200,
			Speed = 10,
			StopAt = 1, -- (walks right into you: its Contact reaches 4)
			Radius = 11,
			Turn = 4,
			Strength = 2,
			Respawn = 20, -- (unused now: the nests' cooldown, Eggs.Cooldown, decides)
			-- (QM, Oct 24: every boss just chases you and hurts on contact for now; Server/
			-- BossAttacks also has Slam, Shot, Nova and Bombs for later)
			Attacks = {
				{ Kind = "Contact", Every = 1, Reach = 4, Damage = 10 },
			},
		},
		GiantRafflesia = {
			Name = "Giant Rafflesia",
			Model = "GiantRafflesia", -- (LassoAPet's, QM Oct 25: its meshes in ReplicatedStorage.AnimalMeshes, tools/animal_meshes.luau)
			Size = 0.6, -- (about 30 studs tall)
			Health = 200,
			Speed = 9,
			StopAt = 1,
			Radius = 9,
			Turn = 3.5,
			Strength = 2,
			Respawn = 20,
			Attacks = {
				{ Kind = "Contact", Every = 1, Reach = 4, Damage = 10 },
			},
		},
		MajesticUnicorn = {
			Name = "Majestic Unicorn",
			Model = "MajesticUnicorn", -- (LassoAPet's pet, scaled up to a boss: QM Oct 25)
			Size = 2.4, -- (about 32 studs tall)
			Health = 200,
			Speed = 10,
			StopAt = 1,
			Radius = 8,
			Turn = 4,
			Strength = 2,
			Respawn = 20,
			Attacks = {
				{ Kind = "Contact", Every = 1, Reach = 4, Damage = 10 },
			},
		},
		VenusFlytrap = {
			Name = "Venus Flytrap",
			Model = "VenusFlytrap", -- (LassoAPet's pet, scaled up to a boss: QM Oct 25)
			Size = 1.8, -- (about 31 studs tall)
			Health = 200,
			Speed = 10,
			StopAt = 1,
			Radius = 9,
			Turn = 4,
			Strength = 2,
			Respawn = 20,
			Attacks = {
				{ Kind = "Contact", Every = 1, Reach = 4, Damage = 10 },
			},
		},
		CactusBoss = {
			Name = "Cactus Boss",
			Model = "CactusBoss", -- (LassoAPet's, QM Oct 24)
			Size = 2.4, -- (about 29 studs tall)
			Health = 1300,
			Speed = 11,
			StopAt = 1, -- (walks right into you: its Contact reaches 4)
			Radius = 13,
			Turn = 3.5,
			Strength = 6,
			Respawn = 25,
			-- (QM, Oct 24: every boss just chases you and hurts on contact for now; Server/
			-- BossAttacks also has Slam, Shot, Nova and Bombs for later)
			Attacks = {
				{ Kind = "Contact", Every = 1, Reach = 4, Damage = 20 },
			},
		},
		ElderBoar = {
			Name = "Elder Boar",
			Model = "ElderBoar", -- (LassoAPet's, QM Oct 24)
			Size = 2, -- (about 27 studs tall, 40 long)
			Health = 2350,
			Speed = 9,
			StopAt = 1, -- (walks right into you: its Contact reaches 4)
			Radius = 12,
			Turn = 3,
			Strength = 20,
			Respawn = 30,
			-- (QM, Oct 24: every boss just chases you and hurts on contact for now; Server/
			-- BossAttacks also has Slam, Shot, Nova and Bombs for later)
			Attacks = {
				{ Kind = "Contact", Every = 1, Reach = 4, Damage = 35 },
			},
		},
		LavaWyrm = {
			Name = "Lava Wyrm",
			Model = "LavaWyrm", -- (LassoAPet's, QM Oct 24)
			Size = 1.4, -- (about 16 studs tall, 60 long)
			Health = 3600,
			Speed = 8,
			StopAt = 1, -- (walks right into you: its Contact reaches 4)
			Radius = 10,
			Turn = 2.5,
			Strength = 60,
			Respawn = 35,
			-- (QM, Oct 24: every boss just chases you and hurts on contact for now; Server/
			-- BossAttacks also has Slam, Shot, Nova and Bombs for later)
			Attacks = {
				{ Kind = "Contact", Every = 1, Reach = 4, Damage = 60 },
			},
		},
	},
	-- each biome's boss: one of these at random every time it (re)spawns (QM, Oct 25; /reboss
	-- re-rolls them all)
	BossPools = {
		Meadow = { "MotherHen", "GiantRafflesia", "MajesticUnicorn", "VenusFlytrap" },
		Desert = { "CactusBoss" },
		Ice = { "ElderBoar" },
		Lava = { "LavaWyrm" },
	},
	-- healing out of a fight (QM, Oct 26; Server/Regen): once you go Delay seconds without
	-- taking damage you heal Rate of your max health a second until full; any hit restarts
	-- the wait. (Replaces Roblox's default slow regen.)
	Regen = {
		Delay = 10,
		Rate = 0.1, -- 10% of max health a second
	},
	BossCalmDown = 6, -- seconds with nobody locked in its fight before a boss walks home and leaves
	-- a boss arriving (QM, Oct 25: they only appear once you steal an egg): the camera of
	-- everyone locked into its fight pans over to its dais, it pops up there while the screen's
	-- edges pulse red (it's after you), then the camera pans back and the fight starts
	-- (client/BossIntro; till then it can't be hit and does nothing: Server/Bosses)
	BossIntro = {
		PanIn = 0.8, -- seconds the camera takes to swing over to it
		Hold = 1.6, -- seconds looking at it (it appears at the start of this)
		PanOut = 0.6, -- seconds back to your own camera; the fight starts once it's back
		Appear = 0.5, -- seconds it takes to grow from nothing to full size
		Distance = 2.2, -- the shot's distance from it, in its own sizes (plus 10 studs)
		Height = 0.6, -- how high the camera sits, of that distance
		Pulses = 2, -- red pulses round the screen's edge
		PulseTime = 0.55, -- seconds each pulse takes
		VignetteColor = Color3.fromRGB(255, 30, 30),
		VignetteWidth = 0.28, -- how far in from each edge the red reaches, of the screen
		VignetteAlpha = 0.25, -- its transparency at the very edge at a pulse's peak (0 = solid)
	},
	-- a sleeping boss (client/BossView, QM Oct 25): settled low on the ground, its head
	-- swelling a little with each snore. A Model with a pose in Poses lies down in it
	-- instead (no sinking or swelling): eyes shut, breathing slowly, Zzz drifting up.
	BossSleep = {
		Sink = 0.15, -- how far into the ground it settles, of its height
		Snore = 1.1, -- its head's size at the top of a snore (1 at the bottom)
		Breath = 3, -- seconds a snore (or a breath) takes
		Settle = 0.6, -- seconds to settle down (or get up)
		-- per Model, in its Blockbench drawing's studs and radians (it scales with the boss):
		--   Bones   = { bone = { x, y, z, rx, ry, rz } } -- its pose, replacing idle's
		--   Breathe = { bone = { x, y, z, rx, ry, rz } } -- added at the top of each breath
		--   Shut    = { part names } -- eyes, squashed into a dark line
		--   Hide    = { part names } -- pupils, gone while its eyes are shut
		--   Zzz     = Vector3 -- where its Zzz start (drawing studs, from the neck bone); none without it
		Poses = {
			Chicken = {
				Bones = {
					root = { 0, -2.75, 0, -0.06, 0, 0 }, -- (sat right down on the ground, a feather loaf)
					LegL = { 0, 0.4, -0.8, -1.57, 0, 0 }, -- (legs folded flat under it)
					LegR = { 0, 0.4, -0.8, -1.57, 0, 0 },
					neck = { 0, -1.6, 0.6, -0.14, 0.08, 0.12 }, -- (head sunk into its shoulders, beak down, lolled)
					WingL = { 0.1, -0.2, 0, 0, 0, -0.06 },
					WingR = { -0.1, -0.2, 0, 0, 0, 0.06 },
					Tail = { 0, -0.3, 0, 0.35, 0, 0 }, -- (drooped back)
				},
				Breathe = {
					root = { 0, 0.14, 0, 0, 0, 0 },
					neck = { 0, 0.1, 0, -0.07, 0, 0 },
					WingL = { 0, 0.05, 0, 0, 0, -0.07 },
					WingR = { 0, 0.05, 0, 0, 0, 0.07 },
					Tail = { 0, 0, 0, -0.08, 0, 0 },
				},
				Shut = { "EyeL" },
				Hide = { "PupilL" },
				-- Zzz = Vector3.new(1.2, 4.5, -1.2), -- (no Zs on the hen: QM, Oct 25)
			},
			GiantRafflesia = {
				Bones = {
					Stem = { 0, 0, 0, -0.12, 0, 0.06 }, -- (bowed over a little)
					Flower = { 0, 0, 0, -0.9, 0, 0 }, -- (hung face down)
					-- (each petal curled up round the middle, a closed bud: about its own edge)
					Petal1 = { 0, 0, 0, -0.7, 0, 0 },
					Petal2 = { 0, 0, 0, -0.2, -0.069, 0.661 },
					Petal3 = { 0, 0, 0, 0.552, 0.112, 0.391 },
					Petal4 = { 0, 0, 0, 0.552, -0.112, -0.391 },
					Petal5 = { 0, 0, 0, -0.2, 0.069, -0.661 },
				},
				Breathe = {
					Stem = { 0, 0, 0, 0.03, 0, 0 },
					Flower = { 0, 0, 0, 0.06, 0, 0 },
					Petal1 = { 0, 0, 0, 0.1, 0, 0 }, -- (opening a touch with each breath)
					Petal2 = { 0, 0, 0, 0.031, 0.001, -0.095 },
					Petal3 = { 0, 0, 0, -0.081, -0.002, -0.059 },
					Petal4 = { 0, 0, 0, -0.081, 0.002, 0.059 },
					Petal5 = { 0, 0, 0, 0.031, -0.001, 0.095 },
				},
				Shut = {},
				Hide = {},
			},
			MajesticUnicorn = {
				Bones = {
					root = { 0, -2.9, 0, 0, 0, 0 }, -- (lying down on its belly)
					LegFL = { 0, 0.5, 0.2, -1.5, 0, 0 }, -- (front legs folded back under its chest)
					LegFR = { 0, 0.5, 0.2, -1.5, 0, 0 },
					LegHL = { 0, 0.5, -0.4, 1.5, 0, 0 }, -- (hind legs folded forward under its belly)
					LegHR = { 0, 0.5, -0.4, 1.5, 0, 0 },
					neck = { 0, -0.4, 0, -0.3, 0.25, 0.08 }, -- (head down, turned a little to one side)
					EarL = { 0, 0, 0, 0.45, 0, 0.25 }, -- (ears laid back)
					EarR = { 0, 0, 0, 0.45, 0, -0.25 },
					Tail = { 0, 0, 0, -0.3, 0, 0 }, -- (tail drooped onto the ground and curled round)
					Tail2 = { 0, 0, 0, -0.6, 0.3, 0 },
					Tail3 = { 0, 0, 0, -0.6, 0.3, 0 },
					Tail4 = { 0, 0, 0, -0.3, 0.3, 0 },
				},
				Breathe = {
					root = { 0, 0.15, 0, 0, 0, 0 },
					neck = { 0, 0, 0, -0.06, 0, 0 },
					Tail = { 0, 0, 0, 0.04, 0, 0 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = { "PupilL", "PupilR" },
			},
			VenusFlytrap = {
				Bones = {
					root = { 0, -1.3, 0, 0, 0, 0 }, -- (squatted down, its leaves splayed out flat)
					LegFL = { 0, 0, 0, 0.25, 0, -0.6 },
					LegHL = { 0, 0, 0, -0.25, 0, -0.6 },
					LegFR = { 0, 0, 0, 0.25, 0, 0.6 },
					LegHR = { 0, 0, 0, -0.25, 0, 0.6 },
					neck = { 0, 0, 0, -0.4, 0, 0.12 }, -- (stalk bowed over)
					Jaw = { 0, 0, 0, -0.55, 0, 0 }, -- (its mouth shut)
					group = { 0, 0, 0, 0.35, 0, 0 },
				},
				Breathe = {
					root = { 0, 0.12, 0, 0, 0, 0 },
					neck = { 0, 0, 0, 0.06, 0, 0 },
					Jaw = { 0, 0, 0, 0.05, 0, 0 },
				},
				Shut = { "EyeL" },
				Hide = { "PupilL" },
			},
			CactusBoss = {
				Bones = {
					root = { 0, -2.2, 0.4, 0.12, 0, 0 }, -- (sat down on the ground, leaning back)
					LegFL = { 0, 0.6, 0, 1.45, 0, 0 }, -- (stumpy legs stuck out in front)
					LegFR = { 0, 0.6, 0, 1.45, 0, 0 },
					neck = { 0, 0, 0, -0.25, 0, 0.12 }, -- (its flowery top nodding forward)
					ArmL = { 0, 0, 0, -0.15, 0, 0.35 }, -- (arms slumped at its sides)
					ArmR = { 0, 0, 0, -0.15, 0, -0.35 },
				},
				Breathe = {
					root = { 0, 0.12, 0, -0.03, 0, 0 },
					neck = { 0, 0, 0, -0.05, 0, 0 },
					ArmL = { 0, 0, 0, 0, 0, -0.06 },
					ArmR = { 0, 0, 0, 0, 0, 0.06 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = {},
			},
			ElderBoar = {
				Bones = {
					root = { 0, -3.3, 0, 0, 0, 0 }, -- (lying down on its belly)
					LegFL = { 0, 0.8, 0.3, -1.5, 0, 0 }, -- (legs folded under)
					LegFR = { 0, 0.8, 0.3, -1.5, 0, 0 },
					LegHL = { 0, 0.8, -0.3, 1.5, 0, 0 },
					LegHR = { 0, 0.8, -0.3, 1.5, 0, 0 },
					neck = { 0, 1.2, 0, 0.12, 0.2, 0 }, -- (chin resting on the ground, turned a little)
					EarL = { 0, 0, 0, 0.3, 0, 0.5 }, -- (ears drooped)
					EarR = { 0, 0, 0, 0.3, 0, -0.5 },
					Tail = { 0, 0, 0, -0.5, 0, 0 },
				},
				Breathe = {
					root = { 0, 0.2, 0, 0, 0, 0 },
					neck = { 0, -0.1, 0, -0.03, 0, 0 },
				},
				Shut = { "EyeL" },
				Hide = { "PupilL" },
			},
			LavaWyrm = {
				Bones = {
					-- (its tail curled round beside it)
					Seg2 = { 0, 0, 0, 0, 0.35, 0 },
					Seg3 = { 0, 0, 0, 0, 0.4, 0 },
					Seg4 = { 0, 0, 0, 0, 0.45, 0 },
					Seg5 = { 0, 0, 0, 0, 0.5, 0 },
					Seg6 = { 0, 0, 0, 0, 0.5, 0 },
					Seg7 = { 0, 0, 0, 0, 0.55, 0 },
					Seg8 = { 0, 0, 0, 0, 0.6, 0 },
					-- (neck curled the other way, head down on the ground)
					NeckBase = { 0, 0, 0, 0, 0.3, 0 },
					neck = { 0, 0, 0, 0, 0.35, 0 },
					NeckTop = { 0, -0.2, 0, 0.05, 0.35, 0 },
					Head = { 0, -0.3, 0, 0.06, 0.2, 0.1 },
					Jaw = { 0, 0, 0, 0.33, 0, 0 }, -- (mouth shut)
					Crest = { 0, -0.4, 0.4, 1.1, 0, 0 }, -- (its fan folded flat down its neck)
				},
				Breathe = {
					root = { 0, 0.1, 0, 0, 0, 0 },
					Seg2 = { 0, 0.08, 0, 0, 0, 0 },
					Seg3 = { 0, 0.06, 0, 0, 0, 0 },
					NeckBase = { 0, 0.08, 0, 0, 0, 0 },
					Crest = { 0, 0, 0, -0.12, 0, 0 }, -- (its fan lifting a little with each breath)
				},
				Shut = { "GlowAmber_iris_L", "GlowAmber_iris_R" },
				Hide = { "GlowSlit_pupil_L", "GlowSlit_pupil_R" },
			},
		},
		Zzz = {
			Count = 3, -- Zs in a run, one run per breath as it breathes out (each bigger than the last)
			Gap = 0.6, -- seconds between them
			Size = 2, -- the first Z's height, drawing studs (it scales with the boss)
			Rise = 5, -- drawing studs each drifts up (and Rise/2 sideways, swaying)
			Life = 2.4, -- seconds each lasts
		},
	},

	-- eggs (Server/Eggs): one in every nest round each biome's edges. Hold E to steal one:
	-- its boss wakes and red barriers (only you see them) lock you in the biome until
	-- it's dead; then carry the egg home to your pen for its Reward in cash.
	Eggs = {
		StealTime = 0.6, -- seconds holding E
		-- each biome's nests run on a cooldown (QM, Oct 26): when it's up they all refill;
		-- when the fight their eggs start is over, the ones left vanish and it starts again
		Cooldown = 60, -- seconds
		PopStagger = 0.15, -- seconds between each nest's egg popping in
		TimerRange = 45, -- studs from a nest you see its cooldown over it
		-- does a stolen egg ride on your back (and earn its reward in your pen)? Off for now
		-- (QM, Oct 25): stealing only wakes the boss and locks you into its fight
		Carry = false,
		-- (QM, Oct 25: real eggs, LassoAPet's: Shared/Eggs/<Kind>EggModel, one per animal.)
		-- Each nest lays one of its biome's kinds, by these weights (LassoAPet's spawn odds:
		-- each biome's Herd there). A new animal: its egg model, Pets above, then here.
		-- The biomes past the Tundra are still to come (QM): Horse eggs until then.
		Kinds = {
			Meadow = { Pinto = 0.35, Pig = 0.25, Bunny = 0.25, Fish = 0.13, Rhino = 0.08, Unicorn = 0.05 },
			Desert = { Cactus = 0.3, Scorpion = 0.3, Sandworm = 0.2, SpineLizard = 0.2, Snake = 0.025 },
			Ice = { Penguin = 0.3, Boar = 0.25, Snowman = 0.22, IceGolem = 0.12, Icebringer = 0.02 },
			Lava = { Horse = 1 },
			Dungeon = { Horse = 1 },
			Castle = { Horse = 1 },
			Forest = { Horse = 1 },
			Ocean = { Horse = 1 },
		},
		Scale = { Nest = 1.3, Carried = 0.6, Pen = 0.9 }, -- times the egg's drawing (about 4 studs tall)
		Twitch = { 3, 8 }, -- seconds between an egg's AFK twitches (random in this range)
		Reward = { Meadow = 100, Desert = 600, Ice = 3000, Lava = 15000, Dungeon = 60000, Forest = 60000, Castle = 250000, Ocean = 250000 },
		PenShows = 24, -- most eggs sat in a pen
	},

	-- saving (Server/Data): the DataStore's name (a new name starts everyone fresh)
	Data = {
		Store = "Players_v1",
		AutoSave = 90, -- seconds
	},

	-- rebirth (Server/Data, the Rebirth popup): cash needed is Cost x Growth ^ rebirths so far;
	-- it resets your cash, Strength and regions, and each rebirth makes every hit
	-- train StrengthBonus more (0.5: 1.5x after one, 2x after two)
	Rebirth = {
		Cost = 25000,
		Growth = 3,
		StrengthBonus = 0.5,
	},

	-- rarities (QM, Oct 25): a name's colours by its animal's rarity, a bright fill with a
	-- dark stroke of the same hue (QM picked Rare's; the rest follow it)
	Rarities = {
		Common = { Fill = Color3.fromRGB(235, 235, 235), Stroke = Color3.fromRGB(70, 70, 70) },
		Uncommon = { Fill = Color3.fromRGB(150, 255, 120), Stroke = Color3.fromRGB(28, 104, 18) },
		Rare = { Fill = Color3.fromRGB(138, 243, 255), Stroke = Color3.fromRGB(0, 88, 106) }, -- #8AF3FF, #00586A (QM)
		Epic = { Fill = Color3.fromRGB(214, 156, 255), Stroke = Color3.fromRGB(78, 20, 118) },
		Legendary = { Fill = Color3.fromRGB(255, 214, 94), Stroke = Color3.fromRGB(122, 74, 0) },
		Mythic = { Fill = Color3.fromRGB(255, 122, 156), Stroke = Color3.fromRGB(110, 10, 42) },
	},

	-- the Backpack (QM, Oct 25: client/Backpack, Server/PetInventory): the pets you own
	-- and the weapons bosses dropped you, duplicates stacked ("x5"). Pets you equip wander
	-- in your pen, up to PenSlots of them; the weapon you equip is the one you hold.
	Backpack = {
		PenSlots = 5, -- (QM, Oct 26: the Backpack's Pets tab has five)
	},

	-- hatching (QM, Oct 25, LassoAPet's): a stolen egg is yours at once, in the hotbar right
	-- of the Backpack button (player attribute EggBag; lost when you die). Click it to hold
	-- it instead of your weapon, click in your pen to put it down; it's ready after its
	-- Time (seconds, LassoAPet's PetHatchTime; Default for one not listed), then stand by
	-- it and hold E to hatch it into its pet, which goes in your Backpack (Server/Hatchery).
	Hatch = {
		PenEggs = 8, -- most eggs waiting in a pen at once
		Range = 14, -- studs from an egg you can hatch it
		HoldTime = 0.5, -- seconds holding E
		Default = 15,
		Time = {
			Horse = 15, Pinto = 15, Pig = 15, Bunny = 15, Fish = 45, Rhino = 120, Unicorn = 3600, -- Meadow
			Cactus = 15, Scorpion = 60, Sandworm = 75, SpineLizard = 90, Snake = 7200, -- Desert
			Penguin = 15, Boar = 15, Snowman = 60, IceGolem = 300, Icebringer = 7200, SnackYak = 3600, -- Tundra
		},
		Scale = { Held = 0.55 }, -- the egg in your hands, times its drawing (in the pen: Eggs.Scale.Pen)
	},

	-- pets (QM, Oct 25: LassoAPet's, with their rarity, cash a second and egg odds). The
	-- pet you ride is all your health and speed (Shared/Pets works them out, PetStats
	-- below); its name shows over you in its rarity's colours (Rarities above).
	--   Rarity  its rarity
	--   Cash    cash a second it earns (LassoAPet's PetIncome, the Tundra's after its
	--           income curve; not paid out yet: nothing hatches so far)
	--   Tier    its size tier (LassoAPet's PetTiers): 1 reads as big as the Horse, each
	--           tier PetStats.TierGrowth x bigger
	--   Lean    -1 (quick and fragile) to 1 (slow and tough), traded at PetStats.Lean
	--           (a guess from how fast each ran in LassoAPet)
	Pets = {
		Horse = { Rarity = "Common", Cash = 3, Tier = 1, Lean = 0, Speed = 1 },
		-- Meadow
		Pig = { Rarity = "Uncommon", Cash = 9, Tier = 1, Lean = 0.5, Speed = 0.8 },
		Bunny = { Rarity = "Uncommon", Cash = 12, Tier = 1, Lean = -0.6, Speed = 1.2 },
		Pinto = { Rarity = "Uncommon", Cash = 15, Tier = 1, Lean = -0.2, Speed = 1.1 },
		Fish = { Rarity = "Rare", Cash = 24, Tier = 1, Lean = 0.6, Speed = 0.6 },
		Rhino = { Rarity = "Epic", Cash = 90, Tier = 2, Lean = 0.6, Speed = 1.35 },
		Unicorn = { Rarity = "Legendary", Cash = 450, Tier = 2, Lean = -0.4, Speed = 1.8 },
		-- Desert
		Cactus = { Rarity = "Uncommon", Cash = 18, Tier = 1, Lean = 0.2, Speed = 1.31 },
		Scorpion = { Rarity = "Rare", Cash = 60, Tier = 1, Lean = 0, Speed = 1.77 },
		Sandworm = { Rarity = "Epic", Cash = 180, Tier = 2, Lean = 0.5, Speed = 1.7 },
		SpineLizard = { Rarity = "Epic", Cash = 240, Tier = 2, Lean = -0.5, Speed = 1.97 },
		Snake = { Rarity = "Legendary", Cash = 750, Tier = 3, Lean = -0.3, Speed = 2.8 },
		-- Tundra
		Penguin = { Rarity = "Uncommon", Cash = 45, Tier = 1, Lean = 0.3, Speed = 2.355 },
		Boar = { Rarity = "Uncommon", Cash = 91, Tier = 1, Lean = -0.2, Speed = 2.517 },
		Snowman = { Rarity = "Rare", Cash = 180, Tier = 1, Lean = 0.4, Speed = 2.678 },
		IceGolem = { Rarity = "Epic", Cash = 760, Tier = 2, Lean = 0.4, Speed = 2.86 },
		SnackYak = { Rarity = "Epic", Cash = 9000, Tier = 2, Lean = 0.5, Speed = 3 }, -- (a Robux pet in LassoAPet: in no egg)
		Icebringer = { Rarity = "Legendary", Cash = 2000, Tier = 3, Lean = 0.2, Speed = 3.8 },
	},
	-- a pet's health and speed (Shared/Pets): set by its rarity, not its biome (QM, Oct 25:
	-- they're mostly a status signal; later biomes' pets earn more, not fight better).
	-- Within a rarity, more health means less speed (Lean), and a bigger body is easier to
	-- hit, so it gets more health: x (its hitbox / the Horse's) ^ Hitbox. Its hitbox is
	-- half its footprint (the square root of its box's width x length), in studs.
	PetStats = {
		Rarity = {
			Common = { Health = 100, Speed = 25.6 }, -- (the Horse: Roblox's default 16 x 1.6, QM Oct 23)
			Uncommon = { Health = 115, Speed = 26.9 },
			Rare = { Health = 130, Speed = 28.2 },
			Epic = { Health = 150, Speed = 29.6 },
			Legendary = { Health = 175, Speed = 31 },
			Mythic = { Health = 200, Speed = 32.5 },
		},
		Lean = 0.25, -- Lean 1: +25% health, -25% speed (Lean -1 the other way)
		-- Speed (QM, Oct 26): each pet's own, LassoAPet's: MountSpeed studs/s x its Speed in
		-- Config.Pets (Lasso's AnimalStats Speed; its horse rides at 44). This replaces the
		-- rarity's Speed and the Lean's speed half; a pet without a Speed keeps those.
		MountSpeed = 44,
		Hitbox = 0.5, -- 0: size doesn't matter; 1: twice the hitbox, twice the health
		TierGrowth = 1.6, -- each size tier reads this much bigger than the one below (LassoAPet's)
	},

	-- Sprint (QM, Oct 26; client/Sprint): ride Delay seconds without stopping and your pet
	-- builds up to a sprint, Speed x its speed, over Ramp seconds. Stopping (letting go of
	-- the controls, or held up against something: under StopAt of your speed) drops you
	-- straight back. LassoAPet's sprint is 2x; this game's is 1.3x (QM).
	Sprint = { On = true, Speed = 1.3, Delay = 1.5, Ramp = 1.2, StopAt = 0.4 },
	-- The rest is LassoAPet's riding feel, ported as it is (its own Config values). Where it
	-- measured speeds in studs/s against "a horse's sprint", here that's the Horse's speed
	-- x Sprint.Speed (worked out in code), and the tiers are multiples of it.
	-- Speed lines while you sprint (client/SpeedLines): Rate a second at Speed studs/s (a
	-- sprint), more or fewer with your speed up to MaxScale x, none otherwise. Each starts
	-- From of the way from the middle to a corner and shoots Travel further out over Life
	-- seconds, Length by Thickness pixels (on a 1000 px tall screen), white at Opacity at
	-- its most solid. Zoom: the whole effect's size on the screen. In a Studio playtest the
	-- camera gets SpeedLines<Key> attributes to tune them live.
	SpeedLines = { On = true, Zoom = 1.2, Rate = 200, Speed = 88, MaxScale = 2, From = 0.5, Travel = 0.8, Life = 0.32, Length = 200, Thickness = 9, Opacity = 0.6 },
	-- The sprint camera (client/SprintCam): sprinting, the view widens to Fov degrees (a
	-- fisheye-like stretch at the edges) and the camera comes in to Zoom x its usual
	-- distance, easing in over InTime seconds and back over OutTime; x your speed over a
	-- horse's sprint, between MinScale and MaxScale. Breaking into a higher sprint tier
	-- bounces the camera's distance: in to Bounce.In x, out to Bounce.Out x, then settling.
	SprintCam = { On = true, Fov = 95, Zoom = 0.75, InTime = 0.3, OutTime = 0.5, MinScale = 0.5, MaxScale = 1.8, Bounce = { In = 0.7, InTime = 0.1, Out = 1.2, OutTime = 0.15, SettleTime = 0.4 } },
	-- Sprint tiers, in horse's sprints (LassoAPet's 180, 360 and 440 studs/s over its horse's
	-- 88): breaking into one replays the whoosh, bounces the camera, flashes the sky and
	-- steps the wind louder (up to 2x).
	SprintTiers = { 2.05, 4.1, 5 },
	-- A white trail off you while you sprint (client/SprintTrail): Life seconds long at a
	-- horse's sprint, longer the faster you go, up to MaxLife.
	SprintTrail = { On = true, Life = 0.12, MaxLife = 0.6, Transparency = 0.55 },
	-- The sky flashes white on each sprint tier-up, fading back over Time seconds
	-- (client/SkyFlash). Start: its see-through at the flash. Distance: studs round the camera.
	SkyFlash = { On = true, Time = 0.8, Start = 0, Distance = 1000 },

	-- regions (QM, Oct 25): each biome past the Meadow is bought with cash. Until you own
	-- it, its gate shows a blocker only you see (client/Regions: a navy wall with its name,
	-- price and a Buy button, and its shadow on the floor); Server/Regions sells it and
	-- Server/Data saves it (Region<Name>). A rebirth locks them
	-- again. Prices are placeholders.
	Regions = {
		Cost = {
			Meadow = 0,
			Desert = 2500,
			Ice = 25000,
			Lava = 250000,
			Dungeon = 2500000,
			Forest = 2500000,
			Castle = 25000000,
			Ocean = 25000000,
		},
		Names = { Ice = "Tundra", Lava = "Lava Valley", Castle = "Red Castle", Forest = "Magic Circle", Ocean = "Ocean Trench" }, -- (what players see, where it isn't the key)
		Shadow = 20, -- studs its shadow spreads across the floor before it's gone
	},

	-- what Strength does (Shared/Power, QM Oct 25): it scales your damage and, a little,
	-- your attack speed, both by log(1 + Strength / Scale), so each point counts for less
	-- the more you have. Damage = Slash.Damage x (1 + Damage x log) x the weapon's Damage;
	-- attacks come (1 + Speed x log) times faster, at most MaxSpeed.
	-- QM's targets: Mother Hen (200 health) takes 20 Kendo Stick hits at 0 Strength, 5 at 1,000.
	--   Strength      0     200   1,000   2,000   18,000   140,000   1M
	--   damage       10      30      40      45       59        72   85
	--   speed        1x   1.16x   1.25x   1.29x    1.41x     1.52x   1.62x
	Power = {
		Scale = 10,
		Damage = 0.65, -- (3 / log(101): 4x at 1,000)
		Speed = 0.054, -- (1.25x at 1,000)
		MaxSpeed = 2,
	},

	-- training (Server/Combat): Strength comes from attacking. Every hit trains the damage
	-- it dealt x the enemy's Strength x PerDamage (QM, Oct 25), so it grows with your
	-- damage, and your damage grows with it on Config.Power's log curve.
	Training = {
		PerDamage = 0.1, -- (at 0 Strength a Kendo Stick hit deals 10: Strength 2 trains 2, as before)
	},

	-- the enemies out in the biomes (Server/Mobs; QM, Oct 26: they replace the training
	-- grounds). Each biome keeps Count of its mob wandering its floor, back Respawn seconds
	-- after one falls, so you farm Strength where you fight. While a boss is out in a
	-- biome (someone stole one of its eggs) it stops sending new ones; those already there
	-- stay, and it fills up again once that boss is dead or gone home.
	-- They're a real threat (QM, Oct 26), well under a boss: each one bites for about 40%
	-- of its biome boss's damage a second, and can kill you. Walk within Aggro studs of one,
	-- or hit it, and it comes for you at Chase x its Speed (you still outrun it on any pet),
	-- until you're dead, Leash studs from where it spawned, or you've neither hit it nor
	-- stood within Aggro of it for Calm seconds.
	-- A mob's Health is about 6 Kendo Stick hits for the Strength you'd have arriving there.
	Mobs = {
		Biomes = {
			Meadow = {
				Mob = "Pig",
				Size = 0.55,
				Health = 180,
				Count = 6,
				Strength = 2,
				Speed = 4,
				Attacks = { { Kind = "Contact", Every = 1.5, Reach = 2, Damage = 6 } }, -- (boss: 10 a second)
			},
			Desert = {
				Mob = "KingCrab",
				Name = "Sand Crab",
				Tint = "Sand",
				Size = 1,
				Health = 270,
				Count = 7,
				Strength = 5,
				Speed = 2.5,
				Attacks = { { Kind = "Contact", Every = 1.5, Reach = 2, Damage = 12 } }, -- (boss: 20)
			},
			Ice = {
				Mob = "Penguin",
				Size = 0.6,
				Health = 350,
				Count = 7,
				Strength = 15,
				Speed = 3,
				Attacks = { { Kind = "Contact", Every = 1.5, Reach = 2, Damage = 20 } }, -- (boss: 35)
			},
			Lava = {
				Mob = "RockHog",
				Size = 0.5,
				Health = 430,
				Count = 8,
				Strength = 45,
				Speed = 3.5,
				Attacks = { { Kind = "Contact", Every = 1.5, Reach = 2, Damage = 35 } }, -- (boss: 60)
			},
		},
		Respawn = 6, -- seconds after one falls before its biome sends another
		Aggro = 16, -- studs: come this close (from its edge) and it notices you
		Chase = 2.5, -- an angry mob moves this many times its Speed
		Leash = 60, -- studs from where it spawned: it won't follow you further
		Calm = 6, -- seconds you're out of its Aggro and not hitting it before it forgets you
		Edge = 16, -- studs: none spawn this close to a biome's edges (its gateways)
		Clear = 24, -- studs: none spawn this close to a player
		MobRadius = 2.5, -- a mob's body half-width (hits and reach)
	},

	Slash = {
		-- shape (studs, degrees)
		Arc = 180, -- how far round the crescent reaches
		Radius = 10, -- outer edge, from the slash's centre
		Forward = 3, -- the slash's centre sits this far ahead of the player (reach)
		Width = 3, -- crescent thickness at its middle
		Belly = 0.7, -- thickness profile sin(pi u^Skew)^Belly: lower = fatter middle
		Skew = 1, -- above 1 slides the thickest point toward the end, below toward the start
		Ends = 0.35, -- thickness at the two flat ends, as a fraction of Width
		-- the faceted edges, generated fresh for every slash (SlashFx corners())
		OuterSegments = 4,
		InnerSegments = 3,
		Jitter = 0.7, -- how far each corner wanders, in segments (0 = even, 1 = up to half each way)
		RadiusJitter = 0.04, -- each corner's radius wobble, as a fraction
		MaxStrip = 0.04, -- longest strip (fraction of the arc): smoothness of the fade
		-- each slash's own look: these values are scaled by a random factor in { min, max },
		-- rolled from the slash's seed (SlashFx.roll)
		Variety = {
			Arc = { 0.85, 1.12 },
			Radius = { 0.92, 1.1 },
			Width = { 0.75, 1.3 },
			Belly = { 0.5, 1.6 },
			Skew = { 0.7, 1.45 },
			Ends = { 0.5, 1.5 },
			OuterSegments = { 0.67, 1.34 },
			InnerSegments = { 0.5, 1.2 },
			Jitter = { 0.7, 1.3 },
			RadiusJitter = { 0.5, 2 },
		},
		Height = 0.8, -- the slash plane, above the rider's hips

		-- look
		Color = Color3.fromRGB(255, 255, 255),
		Opacity = 0.2, -- at its brightest (the leading edge)
		Glow = 0.8, -- Beam.LightEmission

		-- timing (seconds)
		Sweep = 0.12, -- leading edge across the arc
		Ease = 3, -- sweep ease-out power: higher = faster start, softer stop
		Hold = 0.1, -- full arc held before it fades
		Fade = 0.2, -- the arc dissolving from the tail into the leading edge
		Trail = 1.15, -- fraction of the arc lit behind the leading edge
		Pop = 1.2, -- radius at the start of the sweep, as a fraction of Radius (above 1: it snaps in)

		-- the upper body's swing (client/SwingAnim.luau has its keyframes)
		Windup = 0.05, -- seconds the body coils before the strike (the arc starts after it)
		Recover = 0.18, -- seconds back to the normal pose after Sweep + Hold

		-- camera zoom on each of your own slashes (client/SlashCam.luau)
		ZoomStep = 0.15, -- each slash adds this share of the zoom still left (less the further in)
		ZoomMax = 0.2, -- fully zoomed in, the camera is (1 - ZoomMax) of its normal distance
		ZoomIn = 0.06, -- seconds the camera takes to catch up with a slash's zoom
		ZoomReturn = 10, -- how fast it heads back out: dz/dt = -ZoomReturn * z ^ ZoomPower
		ZoomPower = 1.6, -- above 1: gentle near normal, quicker the further in it is

		-- sound: one of these, picked by the slash's seed, played on the click from `start`
		-- seconds in, which skips the file's lead-in so the whoosh begins as you click
		-- (measured in Studio with an AudioAnalyzer: it rises from 0.05 s, loudest at 0.11 s,
		-- so the peak lands about 0.07 s after the click, with the strike)
		Sounds = {
			{ id = "rbxassetid://130345020654442", start = 0.04 }, -- Sword-Slash
		},
		Volume = 1,
		SoundCut = 0.06, -- seconds a new slash takes to fade out the last one's sound

		-- auto-attack (client/init.client.luau): no clicking
		Cooldown = 0.3, -- between slashes
		AttackRange = 12, -- slashes while a boss's edge is this close (studs)
		AimRange = 26, -- the torso starts turning toward a boss this close
		AimTime = 0.2, -- seconds the upper body takes to turn onto a new target (never a snap)
		AimTwist = 110, -- the most the upper body turns from the hips (degrees)
		Damage = 10, -- per slash that catches a boss (server checks it)
		Alternate = true, -- swing left-to-right, then right-to-left
	},

	-- the rider's upper body with a weapon out (client/SwingPose; QM, Oct 25). Every weapon
	-- rides in the one pose QM tuned (Oct 25), the torso twisted a little and leaning into
	-- the ride. Swords and staffs swing from it and settle
	-- back into it; bows snap up into the Archer pose below while shooting.
	-- Angles are degrees about the joint's parent-part axes: X pitch (arms: 90 = straight
	-- out in front, below 0 = behind; Waist: below 0 = leaning forward), Y yaw (+ = turn
	-- left), Z roll (or, for a "YXY" arm, a twist about the arm before it's raised). The
	-- weapon comes out of the top of the fist, so RightWrist's X aims it (0: forward with the
	-- arm hanging, + tips it up, -90: along the arm).
	--   Breathe  a slow sway on X when standing still (degrees)
	--   Bob      the gallop's bob on X at full speed (degrees), Lag (strides) lets it trail
	RidePose = {
		BlendTime = 0.12, -- seconds to ease in / out when a weapon is equipped / put away
		BreatheSpeed = 1.7, -- radians a second
		BobFull = 12, -- the pet's speed (studs a second) where the bob is at full strength
		BobRate = 2.2, -- strides a second, for a pet with no gallop of its own to follow
		Joints = {
			Waist = { Order = "YXZ", X = -12, Y = -18, Z = -4, Breathe = 2, Bob = 3, Lag = 0 },
			Neck = { Order = "YXZ", X = 8, Y = 14, Z = 0, Breathe = -1, Bob = -2, Lag = 0.05 },
			-- (QM tuned these in Play, Oct 25: the default for every weapon type)
			RightShoulder = { Order = "YXY", X = 45, Y = -25, Z = 45, Breathe = 1.5, Bob = 3, Lag = 0.15 },
			RightElbow = { Order = "YXZ", X = 5, Y = 0, Z = 0, Breathe = 1, Bob = 3, Lag = 0.2 },
			RightWrist = { Order = "YXZ", X = 0, Y = 0, Z = 0, Breathe = 0, Bob = 0, Lag = 0.25 },
			LeftShoulder = { Order = "YXZ", X = -25, Y = 25, Z = 0, Breathe = 1.5, Bob = 3, Lag = 0.1 },
			LeftElbow = { Order = "YXZ", X = 25, Y = 0, Z = 0, Breathe = 1, Bob = 4, Lag = 0.15 },
		},
		-- bows (every Ranged weapon) while shooting (QM's archer ref): the bow arm straight out
		-- at the target, the body side-on, and the other hand drawing to the cheek. Each shot
		-- releases it and draws again in time for the next, so fast bows look like arrow spam.
		Archer = {
			BlendIn = 0.05, -- seconds to snap up into it on the first shot
			BlendOut = 0.25, -- seconds back to the ride pose...
			Hold = 0.4, -- ...once this long has passed after the next shot was due
			-- the draw hand's cycle, as fractions of the time between shots: flung back off the
			-- string by Release, forward to the string by Nock, back at the cheek by Draw
			Release = 0.15,
			Nock = 0.45,
			Draw = 0.85,
			Joints = { -- at full draw
				Waist = { Order = "YXZ", X = -6, Y = 55, Z = 0 },
				Neck = { Order = "YXZ", X = 0, Y = -50, Z = 0 },
				RightShoulder = { Order = "YXY", X = 97, Y = -55, Z = 0 },
				RightElbow = { Order = "YXZ", X = 0, Y = 0, Z = 0 },
				RightWrist = { Order = "YXZ", X = 0, Y = 0, Z = 0 },
				LeftShoulder = { Order = "YXY", X = 105, Y = -105, Z = 75 },
				LeftElbow = { Order = "YXZ", X = 70, Y = 0, Z = 0 },
			},
			ReleaseJoints = { -- the draw hand just after letting go: flicked back past the ear
				LeftShoulder = { Order = "YXY", X = 85, Y = -70, Z = -45 },
				LeftElbow = { Order = "YXZ", X = 120, Y = 0, Z = 0 },
			},
			NockJoints = { -- the draw hand reaching forward to the string
				LeftShoulder = { Order = "YXY", X = 95, Y = -50, Z = 45 },
				LeftElbow = { Order = "YXZ", X = 10, Y = 0, Z = 0 },
			},
		},
	},

	-- how each weapon sits in the hand and rides (QM, Oct 25), over the defaults: tune them
	-- live in Play with Workspace > Pose (client/PoseTuning), tick PrintConfig there and
	-- paste the block here. Every value is optional, in degrees (Vector3 X, Y, Z) or studs:
	--   GripAngle   turns the weapon in the hand (about the hand's grip point)
	--   GripOffset  slides it in the hand (Y: along the handle)
	--   Waist, Neck, RightShoulder, RightElbow, RightWrist, LeftShoulder, LeftElbow
	--               that joint's riding pose (RidePose.Joints X, Y, Z above)
	WeaponPoses = {},
	-- how every weapon sits in the hand unless its WeaponPoses says otherwise (QM tuned it
	-- in Play, Oct 25), with a weapon type's own values over it
	WeaponGrip = {
		GripAngle = Vector3.new(0, 90, 0),
		GripOffset = Vector3.new(0, 0, -0.25),
		Ranged = { GripOffset = Vector3.new(0.5, 0, 0.25) }, -- (bows: QM)
	},

	-- weapons (QM, Oct 25): bosses drop them. Kill a boss and everyone in its fight gets a
	-- spin (client/WeaponSpin, Server/Arsenal) that lands on one of these; the weapon you
	-- won is equipped (the Backpack switches between the ones you own). Three
	-- types: Melee slashes (Config.Slash with the weapon's Slash values over it), Ranged
	-- shoots straight (arrows, bolts, thrown things), Magic fires slightly homing missiles
	-- (Shared/Projectiles, client/Shots draws them). Every weapon auto-attacks like the sword.
	--   Name     shown in the spin and the Backpack
	--   Type     "Melee", "Ranged" or "Magic"
	--   Rarity   one of Rarities (above): its colour in the spin
	--   Damage   times your Power (Server/Combat: Slash.Damage x Shared/Power's Strength curve) per hit
	--   Weight   its share of a drop (nil: never drops; the Kendo Stick is everyone's to start)
	--   Boss     a boss-only item: only that boss (a Bosses key) drops it, and the spin
	--            shows BONUS when it lands
	--   Slash    (Melee) Config.Slash values to change: Arc, Radius, Forward, Width,
	--            Cooldown, AttackRange, Color, Variety...
	--   Shot     (Ranged, Magic) values over Config.Shots.Ranged or .Magic (below: every
	--            value is listed there)
	-- Every weapon's values can be tuned live in Play: hold it and edit Workspace > Weapon
	-- (client/WeaponTuning); tick PrintConfig there for its block to paste back here.
	Weapons = {
		-- QM's weapons (Oct 25), in four tiers: Common, Uncommon, Rare, Epic. Every Ranged one
		-- shoots the same arrow (only its numbers and trail differ); Magic ones are drawn from
		-- their numbers (client/Shots). Tune any of them live: Workspace > Weapon.
		-- tier 1
		-- (everyone's to start: WeaponDrops.Start, so it never drops)
		KendoStick = {
			Name = "Kendo Stick",
			Type = "Melee",
			Rarity = "Common",
			Damage = 1,
			Slash = {
				Arc = 150,
				AttackRange = 15,
				Color = Color3.fromRGB(255, 240, 210),
				Cooldown = 0.5,
				Radius = 8,
				Width = 2.4,
			},
		},
		Shortsword = {
			Name = "Shortsword",
			Type = "Melee",
			Rarity = "Common",
			Damage = 0.5,
			Weight = 30,
			Slash = {
				Arc = 170,
				AttackRange = 10,
				Cooldown = 0.4,
				Radius = 8.5,
				Recover = 0.4,
			},
		},
		Shortbow = {
			Name = "Shortbow",
			Type = "Ranged",
			Rarity = "Common",
			Damage = 0.8,
			Weight = 30,
			Shot = { Cooldown = 0.45, Range = 45 },
		},
		Staff = { -- (a plain staff, no element: QM, Oct 25)
			Name = "Staff",
			Type = "Magic",
			Rarity = "Common",
			Damage = 0.9,
			Weight = 30,
			Shot = {
				Speed = 60,
				Homing = 220,
				Size = 0.9,
				Color = Color3.fromRGB(49, 200, 242),
			},
		},
		-- tier 2
		Axe = {
			Name = "Axe",
			Type = "Melee",
			Rarity = "Uncommon",
			Damage = 4,
			Weight = 18,
			Slash = {
				Arc = 200,
				AttackRange = 6,
				Cooldown = 1,
				Ends = 0.25,
				Fade = 1,
				Forward = 1,
				Hold = 0.2,
				InnerSegments = 4,
				OuterSegments = 5,
				Radius = 15,
				Recover = 0.8,
				Width = 3.6,
			},
		},
		Longsword = {
			Name = "Longsword",
			Type = "Melee",
			Rarity = "Uncommon",
			Damage = 2,
			Weight = 18,
			Slash = {
				Arc = 240,
				AttackRange = 20,
				Cooldown = 1,
				Ends = 0.3,
				Fade = 0.5,
				Forward = 3.5,
				OuterSegments = 6,
				Radius = 13,
				Recover = 1,
				Trail = 1,
			},
		},
		Longbow = {
			Name = "Longbow",
			Type = "Ranged",
			Rarity = "Uncommon",
			Damage = 1.6,
			Weight = 18,
			Shot = {
				Cooldown = 0.8,
				Count = 3,
				Range = 75,
				Spread = 16,
				TrailLength = 0.2,
				TrailTransparency = 0.6,
			},
		},
		WindStaff = {
			Name = "Wind Staff",
			Type = "Magic",
			Rarity = "Uncommon",
			Damage = 1.2,
			Weight = 18,
			Shot = {
				Color = Color3.fromRGB(201, 201, 201),
				Cooldown = 0.4,
				Homing = 240,
				Size = 0.9,
				Speed = 60,
			},
		},
		LightningStaff = {
			Name = "Lightning Staff",
			Type = "Magic",
			Rarity = "Uncommon",
			Damage = 1.5,
			Weight = 18,
			Shot = {
				Color = Color3.fromRGB(255, 238, 0),
				Cooldown = 0.4,
				Homing = 360,
				HomingCone = 130,
				Size = 0.85,
				Speed = 120,
				TrailLength = 0.1,
			},
		},
		-- tier 3
		WaterStaff = {
			Name = "Water Staff",
			Type = "Magic",
			Rarity = "Rare",
			Damage = 1.9,
			Weight = 9,
			Shot = {
				Color = Color3.fromRGB(49, 162, 242),
				Count = 2,
				Homing = 180,
				Size = 1.2,
				Speed = 40,
				Splash = 6,
			},
		},
		Waraxe = {
			Name = "Waraxe",
			Type = "Melee",
			Rarity = "Rare",
			Damage = 20,
			Weight = 9,
			-- (double bladed, a big sweep round you: QM)
			Slash = {
				Arc = 300,
				AttackRange = 10,
				Color = Color3.fromRGB(255, 225, 190),
				Cooldown = 2,
				Ends = 1,
				Forward = 1,
				Hold = 0.2,
				InnerSegments = 8,
				OuterSegments = 14,
				Pop = 1,
				Radius = 15,
				Recover = 1,
				Trail = 1,
				Width = 5,
			},
		},
		Club = {
			Name = "Club",
			Type = "Melee",
			Rarity = "Rare",
			Damage = 10,
			Weight = 9,
			Slash = {
				Arc = 140,
				AttackRange = 11,
				Belly = 0.4,
				Cooldown = 3,
				Forward = 5,
				Hold = 0.4,
				Jitter = 1,
				OuterSegments = 3,
				Pop = 1,
				Radius = 7,
				Recover = 1,
				Width = 5,
			},
		},
		-- tier 4
		UnholyLance = { -- (QM's, Oct 25)
			Name = "Unholy Lance",
			Type = "Melee",
			Rarity = "Epic",
			Damage = 2.8,
			Weight = 4,
			Slash = {
				Arc = 60,
				AttackRange = 19,
				Color = Color3.fromRGB(255, 0, 0),
				Cooldown = 0.45,
				Forward = 0,
				Glow = 1,
				InnerSegments = 1,
				Opacity = 1,
				OuterSegments = 2,
				Radius = 16,
			},
		},
		NatureBow = {
			Name = "Nature Bow",
			Type = "Ranged",
			Rarity = "Epic",
			Damage = 0.3,
			Weight = 4,
			Shot = {
				Cooldown = 0.2,
				Count = 2,
				Range = 60,
				Spread = 8,
				TrailColor = Color3.fromRGB(51, 255, 0),
				TrailLength = 0.3,
				TrailTransparency = 0.7,
			},
		},
		BloodBow = {
			Name = "Blood Bow",
			Type = "Ranged",
			Rarity = "Epic",
			Damage = 4,
			Weight = 4,
			Shot = {
				Cooldown = 0.4,
				Pierce = 1,
				Range = 65,
				Size = 3,
				Spread = 5,
				TrailColor = Color3.fromRGB(230, 30, 50),
				TrailLength = 0.5,
				TrailTransparency = 0.9,
			},
		},
		FireStaff = {
			Name = "Fire Staff",
			Type = "Magic",
			Rarity = "Epic",
			Damage = 7,
			Weight = 4,
			Shot = {
				Color = Color3.fromRGB(255, 61, 61),
				Cooldown = 0.8,
				Homing = 170,
				Size = 2,
				SparkleSize = 1,
				Speed = 50,
				TrailLength = 1,
			},
		},
		-- boss-only (super rare, BONUS in the spin): QM cut the rest, Oct 25, keeping only this
		RafflesiaBloom = { -- (the Flower Staff: QM renamed it, Oct 25; the id stays for saves)
			Name = "Flower Staff",
			Type = "Magic",
			Rarity = "Mythic",
			Boss = "GiantRafflesia",
			Damage = 0.8,
			Weight = 2,
			Shot = {
				Color = Color3.fromRGB(120, 186, 70),
				Color2 = Color3.fromRGB(200, 235, 170),
				Cooldown = 0.5,
				Count = 3,
				Homing = 240,
				Speed = 35,
				Spread = 30,
				TrailLength = 0.6,
			},
		},
	},
	-- merging (QM, Oct 26): Cost of one weapon make the next one up its ladder (the Backpack's
	-- MERGE button, Server/Arsenal). Into = [weapon] = what it merges into; one not here
	-- doesn't merge.
	Merge = {
		Cost = 2,
		Into = {
			Shortsword = "Longsword",
			Shortbow = "Longbow",
			Longbow = "NatureBow",
			Axe = "Waraxe",
		},
	},
	-- the spin when a boss dies (client/WeaponSpin, Server/Arsenal)
	WeaponDrops = {
		Start = "KendoStick", -- everyone owns this one (QM, Oct 25: the Sword's gone)
		RaysImage = "rbxassetid://137700902661762", -- QM's sunburst behind the weapon (assets/ui/SpinRays.png, once uploaded; "" draws rays)
		Reel = 24, -- items it flicks through before it stops
		SpinTime = 4, -- seconds from the first flick to the stop
		Show = 2.2, -- seconds the winner stays up before the spin fades out
		Equip = true, -- equip what you win as it lands
	},
	-- shots (Shared/Projectiles): what Ranged and Magic weapons fire
	Shots = {
		Height = 0.8, -- above the rider's hips, like the slash
		Radius = 0.6, -- a shot's own width for hitting (studs), times its Size
		Slack = 1.5, -- studs added to every target's width for shots (QM: more forgiving; height never counts)
		Trust = 12, -- studs: how far the shooter's own spot may be from the server's (Server/Combat)
		StillOnly = true, -- bows and staffs only shoot while you stand still (QM, Oct 26, Archero); melee always swings
		-- the held bow pulses on each shot, as in Kingdom Crushers' Shoot (QM, Oct 26): it snaps
		-- small as it fires, swells big toward the next shot, and settles if none comes.
		-- Times are in shot gaps (the Cooldown, or quicker with Strength). client/BowPulse
		Pulse = {
			From = 0.8, -- its size the moment it fires
			Peak = 1.2, -- swelled to this...
			PeakAt = 0.8, -- ...this far into the gap to the next shot
			SettleAt = 2, -- and back to 1 by here
		},
		-- every Ranged weapon's Shot starts from these (its own values go over them)
		Ranged = {
			Look = "Arrow", -- (the one arrow every Ranged weapon shoots; boss ones have their own)
			Cooldown = 0.6, -- seconds between shots
			Range = 55, -- studs it flies
			Speed = 80, -- studs a second (every bow: QM, Oct 25)
			Size = 1.8, -- the arrow's size (and how wide it hits) (QM: every bow the Shortbow's)
			Count = 1, -- shots at once...
			Spread = 0, -- ...fanned over this many degrees
			Pierce = 0, -- extra targets it goes through
			Splash = 0, -- studs: hits everything this close to where it lands (0: none)
			TrailColor = Color3.fromRGB(255, 255, 255),
			TrailLength = 0.12, -- seconds the trail lasts
			TrailTransparency = 0.6, -- where it starts, fading out (QM: half as opaque)
			-- sounds (QM, Oct 25), played where it's fired and where it lands
			FireSound = "rbxassetid://173979241", -- Bow-Fire
			HitSound = "rbxassetid://114751690910911", -- Arrowhit1
			FireVolume = 0.3, -- (QM: half)
			HitVolume = 1.2, -- (QM: double)
		},
		-- every Magic weapon's Shot starts from these. Every staff fires the same orb (QM, Oct
		-- 25, after QM's purple orb reference), only recoloured and resized, in one Color: a
		-- core that's always white inside a ring of Color, a fainter halo and haze of Color
		-- round it, wispy flares curling over it, and a trail (client/Shots)
		Magic = {
			Look = "Orb", -- Orb (every staff), Petal (boss weapons)
			Cooldown = 0.7,
			Range = 50,
			Speed = 55,
			Size = 1, -- the whole orb (and how wide it hits)
			Count = 1,
			Spread = 0,
			Pierce = 0,
			Splash = 0,
			Homing = 200, -- degrees a second it can turn toward a target: it guides, it can't loop round
			HomingCone = 135, -- it only bends toward targets this many degrees either side of its path
			Launch = 90, -- sets off up to this many degrees either side of the aim, at random (QM)
			-- the orb's look
			Color = Color3.fromRGB(150, 60, 255), -- its one colour: the ring, halo, flares and trail (the core is white)
			CoreSize = 0.88, -- studs (x Size) (QM: the orb 1.6x bigger)
			RingSize = 1.6, -- studs (x Size)
			RingTransparency = 0.3,
			HaloSize = 3.04, -- studs (x Size)
			HaloTransparency = 0.8, -- (the same Color, fainter)
			HazeSize = 4.48, -- a fainter, wider glow past the halo (0: none)
			HazeTransparency = 0.93,
			Flares = 0, -- wispy flames curling over the orb (QM: off)
			FlareLength = 1.6, -- (x Size)
			FlareWidth = 0.45, -- (x Size)
			FlareSpin = 220, -- degrees a second they turn round it
			FlareTransparency = 0.25,
			TrailLength = 0.25, -- seconds
			TrailWidth = 1, -- times the halo's width (it starts as the halo: its colour and HaloTransparency)
			Sparkles = 0, -- a second (QM: none on the orb)
			SparkleSize = 0.3,
			Flicker = 0, -- 0..1: the core jitters in size every frame
			Spin = 0, -- degrees a second (a bomb's tumble)
			-- sounds (QM, Oct 25), played where it's cast and where it lands
			FireSound = "rbxassetid://138498992667102", -- Magic
			HitSound = "rbxassetid://140209514807090", -- Magic-Bullet-s12-hit
			FireVolume = 0.6,
			HitVolume = 0.6,
		},
	},
}
