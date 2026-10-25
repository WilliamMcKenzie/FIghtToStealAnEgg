-- Tuning for the whole game. Slash values can also be tuned live in a Studio playtest:
-- edit the attributes on workspace.SlashTuning (see Shared/SlashTuning.luau), then tick
-- its PrintConfig to print the values to paste back here.

return {
	-- Rig.luau / Studs.luau: studs as stud Textures for now (no stud MaterialVariants yet)
	StudMaterial = false,
	FineStuds = {},
	AnimalScale = {},
	StudTransparency = 0.5, -- every stud Texture (floor, walls, sword, horse): 0.5 = half strength (QM, Oct 24)

	-- the horse everyone rides (Animals/Horse.luau): its size, times the Blockbench drawing
	HorseSize = 0.6,
	RideSpeed = 25.6, -- studs/s riding: Roblox's default 16 x 1.6 (QM, Oct 23)

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
		StoneDark = Color3.fromRGB(176, 178, 168),

		-- the map (tools/map_gen.py lays it out, Server/Map.luau builds it). Each floor
		-- tile's Checker is its checker's colour.
		-- the base: Grass and Dirt (above, the dirt a stud lower) are its floor, WallDirt its wall
		Wood = Color3.fromRGB(150, 98, 56),
		WoodDark = Color3.fromRGB(110, 72, 42),
		Straw = Color3.fromRGB(226, 196, 110),
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
	-- Size times its Blockbench drawing. Strength is what each hit on it trains.
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
		Meadow = {
			Name = "Mother Hen",
			Model = "Chicken",
			Size = 2.4, -- (about 25 studs tall)
			Health = 800,
			Speed = 10,
			StopAt = 1, -- (walks right into you: its Contact reaches 4)
			Radius = 7,
			Turn = 4,
			Strength = 2,
			Respawn = 20, -- seconds after it dies before it's back asleep on its dais
			-- (QM, Oct 24: every boss just chases you and hurts on contact for now; Server/
			-- BossAttacks also has Slam, Shot, Nova and Bombs for later)
			Attacks = {
				{ Kind = "Contact", Every = 1, Reach = 4, Damage = 10 },
			},
		},
		Desert = {
			Name = "Cactus Boss",
			Model = "CactusBoss", -- (LassoAPet's, QM Oct 24)
			Size = 2.4, -- (about 29 studs tall)
			Health = 4000,
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
		Ice = {
			Name = "Elder Boar",
			Model = "ElderBoar", -- (LassoAPet's, QM Oct 24)
			Size = 2, -- (about 27 studs tall, 40 long)
			Health = 20000,
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
		Lava = {
			Name = "Lava Wyrm",
			Model = "LavaWyrm", -- (LassoAPet's, QM Oct 24)
			Size = 1.4, -- (about 16 studs tall, 60 long)
			Health = 100000,
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
	BossCalmDown = 6, -- seconds with nobody locked in its fight before a boss walks home, heals and sleeps

	-- eggs (Server/Eggs): one in every nest round each biome's edges. Hold E to steal one:
	-- its boss wakes and red barriers (only you see them) lock you in the biome until
	-- it's dead; then carry the egg home to your pen for its Reward in cash.
	Eggs = {
		StealTime = 0.6, -- seconds holding E
		Respawn = 40, -- seconds before a nest lays again
		Size = Vector3.new(2.6, 3.3, 2.6),
		Colors = { -- shell, by biome
			Meadow = Color3.fromRGB(250, 246, 232),
			Desert = Color3.fromRGB(240, 206, 140),
			Ice = Color3.fromRGB(190, 226, 255),
			Lava = Color3.fromRGB(255, 120, 40),
		},
		Reward = { Meadow = 100, Desert = 600, Ice = 3000, Lava = 15000 },
		PenShows = 24, -- most eggs sat in a pen
	},

	-- saving (Server/Data): the DataStore's name (a new name starts everyone fresh)
	Data = {
		Store = "Players_v1",
		AutoSave = 90, -- seconds
	},

	-- rebirth (Server/Data, the Rebirth popup): cash needed is Cost x Growth ^ rebirths so far;
	-- it resets your cash, Strength and training grounds, and each rebirth makes every hit
	-- train StrengthBonus more (0.5: 1.5x after one, 2x after two)
	Rebirth = {
		Cost = 25000,
		Growth = 3,
		StrengthBonus = 0.5,
	},

	-- regions (QM, Oct 25): each biome past the Meadow is bought with cash. Until you own
	-- it, its gate shows a blocker only you see (client/Regions: a navy wall with its name,
	-- price and a Buy button, and a shadow spilling off it); Server/Regions sells it and
	-- Server/Data saves it (Region<Name>). A rebirth locks them again, like the training
	-- grounds. Prices are placeholders.
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
		Names = { Dungeon = "The Dungeon", Castle = "Red Castle", Forest = "Magic Forest", Ocean = "Ocean Trench" },
		Color = Color3.fromRGB(0, 28, 78), -- #001C4E: the blocker and its shadow
		Shadow = 10, -- studs the shadow spreads off it before it's gone
	},

	-- training (Server/Training, Server/Combat): Strength comes from attacking. Every hit
	-- trains the enemy's Strength (a boss's in Bosses above), and each point of Strength
	-- adds DamagePerStrength to your slash. The training grounds at the south of the base,
	-- one per biome, are fenced off until bought with cash (a rebirth will lock them again);
	-- their mobs wander and come back Respawn seconds after they fall, for AFK training
	-- (RuneScape's sand crabs).
	Training = {
		DamagePerStrength = 1,
		Grounds = {
			Dummies = { Cost = 0, Strength = 1 }, -- free: straw dummies that never fall
			Meadow = { Cost = 300, Mob = "Pig", Size = 0.55, Health = 60, Count = 4, Strength = 2, Speed = 4 },
			Desert = {
				Cost = 4000,
				Mob = "KingCrab",
				Name = "Sand Crab",
				Tint = "Sand",
				Size = 1,
				Health = 300,
				Count = 5,
				Strength = 5,
				Speed = 2.5,
			},
			Ice = { Cost = 40000, Mob = "Penguin", Size = 0.6, Health = 1500, Count = 4, Strength = 15, Speed = 3 },
			Lava = { Cost = 400000, Mob = "RockHog", Size = 0.5, Health = 8000, Count = 4, Strength = 45, Speed = 3.5 },
		},
		Respawn = 4,
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
		AimTurn = 8, -- how fast the aim eases round (higher = quicker; never a snap)
		AimTwist = 110, -- the most the upper body turns from the hips (degrees)
		Damage = 10, -- per slash that catches a boss (server checks it)
		Alternate = true, -- swing left-to-right, then right-to-left
	},
}
