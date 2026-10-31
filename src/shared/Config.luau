-- Tuning for the whole game. Slash values can also be tuned live in a Studio playtest:
-- edit the attributes on workspace.SlashTuning (see Shared/SlashTuning.luau), then tick
-- its PrintConfig to print the values to paste back here.

return {
	-- Rig.luau / Studs.luau: studs as stud Textures for now (no stud MaterialVariants yet)
	StudMaterial = false,
	FineStuds = {},
	AnimalScale = { RockHog = 1.5, VolcanoTortoise = 2.5, LavaWhale = 2.5, Phoenix = 2 }, -- (LassoAPet's)
	-- (the place's workspace.PetScale wins over AnimalScale, which only seeds it: Shared/PetScale.
	-- Size them in Studio with the pet lineup, then tick PetScale.CopyValues and paste its line here)
	StudTransparency = 0.5, -- every stud Texture (floor, walls, sword, horse): 0.5 = half strength (QM, Oct 24)
	-- workspace.StudStyle's knobs for a place that has none yet (Shared/StudStyle; QM's picks, Oct 30)
	StudStyle = { GroundTransparency = 0.5, GroundTileScale = 1, Transparency = 0.4, TileScale = 2 },

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

	-- the Shop popup (QM, Oct 30: the HUD's Shop button; client/Shop, Server/Store), laid out
	-- like QM's Figma "Shop" frame: Game Passes first, then Cash Packs, then Power Packs.
	-- Ids are placeholders: a pass without its game pass id, or a pack without its developer
	-- product, can't be bought yet (in Studio it's simply given, so it can be tried out).
	--   Passes  Id: its game pass; Gift: a developer product that gives it to someone else;
	--           Robux: the price shown; Look: its card's colours (Shop.Looks); Icon: its
	--           picture (HudImages); Badge: the text on its icon; Text: what it does
	--           (RichText). What each one does: Server/Store (Life, Damage, Cash, Growth).
	--   Cash / Power  Amount: cash, or Strength (the Power counter) it gives; Product: its
	--           developer product (bought for yourself or, through Gift, for someone else);
	--   Robux: the price shown; Icons: the pile on its card, each { picture, x, y, size }
	--           in Figma px, x from the card's middle, y from its top (QM's arrangements from
	--           the Figma: the first three cash piles are his). Pictures: Stack (a bundle of
	--           cash), StackFlip (mirrored), Bills (the flat one in front), Sword, SwordFlip.
	--   Cash packs sit 3 then 2 (wider), like QM's reference; Power packs 3 and 3.
	Shop = {
		Passes = {
			{ Name = "Life", Title = "Extra Life", Text = 'Come back once with <font color="#7CFF4D">full HP</font>!', Badge = "+1", Icon = "PassLife", Look = "Life", Robux = 149, Id = nil, Gift = 3724543631 },
			{ Name = "Damage", Title = "x2 Damage", Text = 'Deal <font color="#7CFF4D">2x</font> Damage!', Badge = "x2", Icon = "ShopSword", Look = "Damage", Robux = 299, Id = nil, Gift = 3724543964 },
			{ Name = "Cash", Title = "x2 Cash", Text = 'Earn <font color="#7CFF4D">2x</font> Money!', Badge = "x2", Icon = "CashStack", Look = "Gold", Robux = 199, Id = nil, Gift = 3724544026 },
			{ Name = "Growth", Title = "x2 Growth", Text = 'Eggs grow <font color="#7CFF4D">2x</font> Faster!', Badge = "x2", Icon = "PassGrowth", Look = "Growth", Robux = 149, Id = nil, Gift = 3724544080 },
		},
		Cash = {
			{ Amount = 200000, Robux = 59, Product = 3724541539, Icons = { { "Stack", 0, 229, 256 } } },
			{ Amount = 2000000, Robux = 79, Product = 3724542219, Icons = {
				{ "Stack", -111, 175, 219 }, { "StackFlip", 136, 191, 219 }, { "Stack", 13, 229, 294 },
			} },
			{ Amount = 10000000, Robux = 299, Product = 3724542603, Icons = {
				{ "Stack", -111, 194, 219 }, { "Stack", 245, 247, 219 }, { "StackFlip", 154, 138, 219 },
				{ "StackFlip", -240, 266, 219 }, { "Bills", 16, 229, 294 },
			} },
			{ Amount = 50000000, Robux = 599, Product = 3724542685, Icons = {
				{ "Stack", -150, 130, 219 }, { "StackFlip", 150, 130, 219 }, { "StackFlip", -330, 240, 219 },
				{ "Stack", 330, 240, 219 }, { "Stack", -150, 255, 240 }, { "StackFlip", 150, 255, 240 },
				{ "Bills", 0, 220, 294 },
			} },
			{ Amount = 250000000, Robux = 1199, Product = 3724542761, Icons = {
				{ "Stack", -230, 110, 210 }, { "StackFlip", 0, 95, 210 }, { "StackFlip", 230, 110, 210 },
				{ "StackFlip", -400, 240, 219 }, { "Stack", 400, 240, 219 }, { "Stack", -250, 250, 240 },
				{ "StackFlip", 250, 250, 240 }, { "Bills", -110, 215, 294 }, { "Bills", 110, 225, 294 },
			} },
		},
		Power = {
			{ Amount = 1000, Robux = 49, Product = 3724542839, Icons = { { "Sword", 0, 229, 280 } } },
			{ Amount = 5000, Robux = 99, Product = 3724543307, Icons = { { "SwordFlip", -70, 220, 260 }, { "Sword", 70, 220, 260 } } },
			{ Amount = 25000, Robux = 199, Product = 3724543392, Icons = {
				{ "SwordFlip", -120, 205, 230 }, { "Sword", 120, 205, 230 }, { "Sword", 0, 235, 290 },
			} },
			{ Amount = 100000, Robux = 459, Product = 3724543489, Icons = {
				{ "Sword", -200, 235, 210 }, { "SwordFlip", 200, 235, 210 }, { "SwordFlip", -75, 200, 260 },
				{ "Sword", 75, 200, 260 },
			} },
			{ Amount = 500000, Robux = 799, Product = 3724543534, Icons = {
				{ "Sword", -215, 250, 210 }, { "SwordFlip", 215, 250, 210 }, { "SwordFlip", -110, 165, 230 },
				{ "Sword", 110, 165, 230 }, { "Sword", 0, 240, 300 },
			} },
			{ Amount = 2500000, Robux = 1499, Product = 3724543583, Icons = {
				{ "SwordFlip", -235, 140, 190 }, { "Sword", 235, 140, 190 }, { "Sword", -225, 265, 210 },
				{ "SwordFlip", 225, 265, 210 }, { "SwordFlip", -110, 175, 240 }, { "Sword", 110, 175, 240 },
				{ "Sword", 0, 240, 310 },
			} },
		},
		-- a gift of a pack goes through the pack's own Product; Gift picks who gets it
		LifeShield = 2, -- seconds you can't be hurt after the Extra Life brings you back
	},

	-- the cactus vendor (QM, Oct 27: LassoAPet's Carl and his stall, a Vendor object in the
	-- map editor; Server/Map builds it, Client/Vendor animates him). He sells weapons for
	-- cash (QM, Oct 27): each weapon's Price in Config.Weapons (placeholders, climbing
	-- with rarity), bought once through
	-- Server/Arsenal's BuyWeapon. Talk hops hello and fires Vendor.talked (client/Vendor),
	-- where the shop popup will open.
	Vendor = {
		Reach = 12, -- studs from the counter where Talk shows
		LookRange = 30, -- he turns to watch a player this close
		Hop = 0.45, -- seconds of his hello hop
		-- the shop's sign and ring (QM, Oct 27, like Pickaxe Shop's in his reference): its
		-- title (the Vendor object's `title` in the map editor) floats over the roof in
		-- outlined text, light at the top to deep at the bottom (green, QM), and a glowing ring lies on
		-- the ground round the front of the stall
		TitleTop = Color3.fromRGB(190, 255, 120),
		TitleBottom = Color3.fromRGB(46, 176, 64),
		TitleStroke = Color3.fromRGB(16, 62, 28),
		TitleHeight = 4, -- studs tall, the text (it stays that size in the world)
		RingColor = Color3.fromRGB(110, 235, 90),
		RingRadius = 12, -- studs
		RingAhead = 5, -- its centre, this far in front of the stall's middle
		-- every weapon he sells can also be bought with Robux (QM's Weapon Shop design, Oct
		-- 27): one Roblox developer product per weapon. Robux is the price shown, by rarity
		-- (placeholders; a weapon's own Robux in Config.Weapons goes over it). Products =
		-- [weapon id] = its developer product id from the Creator Dashboard; a weapon without
		-- one can't be bought with Robux yet (Server/Arsenal's ProcessReceipt hands it over).
		Robux = {
			Common = 30, Uncommon = 75, Rare = 150, Epic = 400, Legendary = 700, Mythic = 1000,
			Divine = 1500, Celestial = 2000, Cosmic = 2500, Void = 3000, Omega = 3500,
		},
		Products = {
			Shortbow = 3724544244,
			Shortsword = 3724544324,
			Staff = 3724544784,
			Axe = 3724544883,
			Longbow = 3724544961,
			LightningStaff = 3724545053,
			Longsword = 3724545134,
			WindStaff = 3724545215,
			WaterStaff = 3724545583,
			Waraxe = 3724545659,
			Club = 3724545740,
			UnholyLance = 3724545809,
			NatureBow = 3724545890,
			BloodBow = 3724545936,
			FireStaff = 3724546310,
			RafflesiaBloom = 3724546371,
			SunBlade = 3724546432,
			StarlightBow = 3724546471,
			NebulaStaff = 3724546497,
			CometLance = 3724546540,
			GalaxyBow = 3724546828,
			VoidReaver = 3724546854,
			AbyssStaff = 3724546888,
			EclipseBow = 3724546933,
			Worldbreaker = 3724546996,
			GenesisStaff = 3724547071,
		},
	},

	-- the free gift (QM, Oct 31: like his reference's FREE! present): a red studded present with
	-- a yellow bow, "FREE!" over it, a glowing ring and sparkles, across the gateway from Carl's
	-- stall (Shared/GiftModel; Server/Map builds it fresh on every start, like the gates).
	-- Walking into its ring opens the Free Reward! popup (client/FreeReward): like the game,
	-- favorite it and join the group, then Claim gives Amount Power (Strength), once per
	-- player (saved: FreeGift). Roblox can't tell a game if you liked it, so Like is on your
	-- word; Favorite opens Roblox's favorite prompt; only the group is checked, by the server
	-- (Server/FreeGift), once GroupId is set (till then it's on your word too).
	FreeGift = {
		X = 50, Z = -130, Yaw = 160, -- (Carl is at -50, -130, yaw 200: the other side of the gateway)
		Scale = 1,
		Amount = 500, -- Power it gives (the smallest Power pack is 1,000 for 49 Robux)
		GroupId = nil, -- the Roblox group to join (its number from the group's page link)
		GroupName = "our group", -- shown on the Join card
		Reach = 30, -- studs from the gift the server takes a Claim from
		OpenRadius = 7, -- walking this close (the ring) opens the popup
		LabelTop = Color3.fromHex("eaff3c"), -- FREE!: lit lime at the top...
		LabelBottom = Color3.fromHex("38d41a"), -- ...to green at the bottom
		LabelHeight = 3.2, -- studs tall
		RingColor = Color3.fromRGB(255, 226, 60),
		RingRadius = 6,
		BoxColor = Color3.fromRGB(226, 26, 36),
		RibbonColor = Color3.fromRGB(255, 205, 30),
		Bob = 0.35, -- studs it floats up and down (client/FreeGift)
	},

	-- bosses (server/Bosses.luau, client/BossView.luau). Each biome's sleeps in its arena's
	-- middle until someone steals one of its eggs or hits it (Server/Eggs); /boss spawns a
	-- Chicken in front of you. Model is a module in Shared/Animals (<Model>Model.luau),
	-- Size times its Blockbench drawing. Strength is what each hit on it trains (x the damage
	-- you dealt: Config.Training). Cash is paid to everyone who beat it (Server/Bosses: Config.BossCash).
	-- Balance (Oct 27): Mother Hen is 20 Kendo Stick hits at 0 Strength and 5 at 1,000
	-- (QM, Oct 25: Config.Power). Each later boss takes about 15s, 25s and 45s solo with the
	-- weapon and Strength you'd have reaching it (Staff at ~3K Strength, Longsword at ~100K,
	-- Waraxe at ~4M); raids go faster. Your health only comes from your pet (100 to 200), so
	-- boss damage climbs gently: about 10, 7, 5 and 4 hits kill a pet from that biome.
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
			StopAt = 1, -- (walks right up to you, into its Swipe's Reach)
			Radius = 11,
			Turn = 4,
			Strength = 2,
			Respawn = 20, -- (unused now: the nests' cooldown, Eggs.Cooldown[biome], decides)
			-- (QM, Oct 24: every boss just chases you and hurts on contact for now; Server/
			-- BossAttacks also has Slam, Shot, Nova and Bombs for later)
			Attacks = {
				{ Kind = "Swipe", Every = 2.2, Reach = 20, Arc = 120, Windup = 0.9, Damage = 22 },
			},
		},
		GiantRafflesia = {
			Name = "Giant Rafflesia",
			Model = "GiantRafflesia", -- (LassoAPet's, QM Oct 25: its meshes in ReplicatedStorage.AnimalMeshes, tools/animal_meshes.luau)
			Size = 1, -- (about 50 studs tall; QM, Oct 27: the bosses but the Mother Hen grew 1.67x with the pets)
			Health = 200,
			-- a ranged boss (QM, Oct 27): rooted in the middle of its arena, it only turns to
			-- face you and casts the Flower Staff's own orbs, with weaker homing to dodge
			Speed = 0,
			Centre = true, -- (it arrives in the middle of its arena, not on the dais)
			StopAt = 1,
			Radius = 15,
			Turn = 3.5,
			Strength = 2,
			Respawn = 20,
			Attacks = {
				{
					Kind = "Magic",
					Every = 1.4, -- seconds between volleys
					Like = "RafflesiaBloom", -- (the Flower Staff: three green orbs, fanned)
					Damage = 6, -- each orb
					Height = 4, -- studs off the ground (about a rider's)
					Shot = {
						Homing = 70, -- (the staff's 240 for players: QM, these must be dodgeable)
						Launch = 35, -- (players' set off up to 90 degrees wide; these come more at you)
						Range = 90,
						Slack = 0, -- (players' shots get extra width to hit; these don't)
					},
				},
			},
		},
		MajesticUnicorn = {
			Name = "Majestic Unicorn",
			Model = "MajesticUnicorn", -- (LassoAPet's pet, scaled up to a boss: QM Oct 25)
			Size = 3.2, -- (about 42 studs tall; QM Oct 30: x0.8)
			Health = 200,
			Speed = 10,
			StopAt = 1,
			Radius = 10.5,
			Turn = 4,
			Strength = 2,
			Respawn = 20,
			Attacks = {
				{ Kind = "Swipe", Every = 2.4, Reach = 20, Arc = 140, Windup = 0.95, Damage = 22 },
				-- (QM, Oct 30: each Meadow boss teaches one move. Horn down, a wind-up,
				-- then it charges: step off the side; no floor warning, QM Oct 30)
				{ Kind = "Charge", Every = 5, Range = 70, Windup = 1, Speed = 70, Width = 18, Damage = 12, Anim = "charge" },
			},
		},
		VenusFlytrap = {
			Name = "Venus Flytrap",
			Model = "VenusFlytrap", -- (LassoAPet's pet, scaled up to a boss: QM Oct 25)
			Size = 2.7, -- (about 47 studs tall; QM Oct 30: x0.9)
			Health = 200,
			Speed = 10,
			StopAt = 1,
			Radius = 13.5,
			Turn = 4,
			Strength = 2,
			Respawn = 20,
			Attacks = {
				{ Kind = "Swipe", Every = 2.4, Reach = 34, Arc = 50, Width = 20, Windup = 1, Damage = 24 },
				-- (its snapping bite: a red circle in front fills, then the jaws come down)
				{ Kind = "Slam", Every = 3.5, Range = 14, Radius = 12, Windup = 0.9, Damage = 14, Anim = "slam" },
			},
		},
		CactusBoss = {
			Name = "Cactus Boss",
			Model = "CactusBoss", -- (LassoAPet's, QM Oct 24)
			Size = 4, -- (about 49 studs tall)
			Health = 4000,
			Speed = 11,
			StopAt = 1, -- (walks right up to you, into its Swipe's Reach)
			Radius = 22,
			Turn = 3.5,
			Strength = 6,
			Respawn = 25,
			-- (QM, Oct 27: the Cactus Boss tries out new mechanics. Besides its bite, it flings
			-- green cactus bombs at everyone (Server/BossAttacks' Lob, drawn by client/Bombs):
			-- each lands Airtime seconds later where you stood when it was thrown, so keep moving)
			Attacks = {
				{ Kind = "Swipe", Every = 2.6, Reach = 32, Arc = 180, Windup = 1.1, Damage = 34 },
				{
					Kind = "Lob",
					Every = 3.5, -- seconds between volleys
					Count = 2, -- extra bombs scattered round you, besides the one at your feet
					Scatter = 35, -- how far off (studs) the extras can land
					Radius = 11, -- each blast's radius (studs)
					Airtime = 1.3, -- seconds in the air (the red ring's fill time)
					Height = 29, -- the arc's peak, studs above the straight line
					Damage = 14,
					Style = "Cactus", -- (client/Bombs' look)
				},
			},
			-- at half health it calls up cactus monsters to help (Server/Minions, QM Oct 27):
			-- Desert Cactus pets, Scale x their riding size, chasing whoever's nearest
			Minions = {
				At = 0.5, -- of its health
				Count = 3,
				Model = "Cactus",
				Name = "Cactus Monster",
				Scale = 1.8,
				Health = 500, -- (about 3s of swinging when you get here: Config.Training's Desert)
				Speed = 14,
				Strength = 3, -- what each hit trains (x damage, like any enemy)
				Spread = 10, -- studs out from the boss's edge they land
				-- they drop out of the sky onto their spots (QM, Oct 30), a shadow growing under
				-- each as it comes down, and land in a puff of Dust (client/BossView)
				Drop = 0.8, -- seconds to fall
				DropFrom = 60, -- studs up they start
				Dust = Color3.fromRGB(226, 190, 128),
				Attacks = {
					{ Kind = "Swipe", Every = 1.6, Reach = 4, Arc = 110, Damage = 10 },
				},
			},
		},
		-- the Desert's burrowing boss (QM, Oct 27): rooted where it surfaces, arched up out of
		-- its hole facing you, it spits sand orbs 1, 2, 3 (Burst), waits, then dives back down
		-- its hole and tunnels to a new spot (a mound of sand running over the ground) to pop
		-- up again. Server/Bosses runs the cycle (its Burrow), client/BossView draws it
		Sandworm = {
			Name = "Sandworm",
			Model = "Sandworm", -- (the Sandworm pet's model, QM's designs/desert/Sandworm.bbmodel)
			Size = 3.12, -- (about 35 studs tall arched up out of the ground; QM Oct 30: x1.2)
			Health = 4000,
			Speed = 0, -- (it never walks: it tunnels, Burrow)
			StopAt = 1,
			Radius = 9.5,
			Turn = 5,
			TurnRate = 240, -- (degrees a second: it keeps its face on you while it's up)
			Strength = 6,
			Respawn = 25,
			Attacks = {
				{
					Kind = "Magic", -- (fired by its Burrow cycle, not on a timer: Every is unused)
					Every = 4,
					Like = "Staff", -- (one orb)
					Damage = 16, -- each orb
					Height = 8, -- studs off the ground (about its chin)
					Burst = 6, -- spat one after another... (QM: 6)
					BurstGap = 0.3, -- ...this many seconds apart
					Pulse = true, -- its head pulses on each, like a bow (client/BossView)
					Shot = {
						Color = Color3.fromRGB(232, 190, 116), -- sand
						Count = 1,
						Size = 1.4,
						SizeMax = 1.6, -- each a random size, Size up to this x it (QM)
						Speed = 40,
						Homing = 50, -- (gentle: you can dodge them)
						Launch = 90, -- each sets off up to this many degrees off its aim, at random (QM)
						Range = 100,
						Slack = 0,
					},
				},
			},
			-- its cycle: surfaces (Emerge s), spits after Aim s, stays up Linger s after its
			-- last spit, dives back in (Hide s), tunnels to its next spot (at least Travel s) as
			-- fast as LassoAPet's Sandworm burrows (its sprint, LassoSprint x the pet's speed)
			-- scaled up by how much bigger than the pet it is (QM; or Speed studs/s if set), Near..Far studs from whoever it's after and at least Hop from
			-- where it was, inside its arena
			Burrow = {
				Emerge = 0.5,
				Aim = 0.35,
				Linger = 3,
				Hide = 0.5,
				LassoSprint = 2, -- (LassoAPet's sprint: 2x; Server/Bosses works the speed out)
				Travel = 0.5,
				Near = 22,
				Far = 50,
				Hop = 25,
				Depth = 12.5, -- (model studs it sinks to be all underground, x Size)
				-- how it stands up out of the hole: { x, y, z, rx, ry, rz } per bone over its
				-- animation (studs at 1x and radians), the front half reared up, the rest down
				-- the hole, its head bent forward to look at you
				Pose = {
					root = { 0, 4.5, 0, 1.05, 0, 0 },
					Seg2 = { 0, 0, 0, 0.35, 0, 0 },
					Seg3 = { 0, 0, 0, 0.17, 0, 0 },
					neck = { 0, 0, 0, -1.25, 0, 0 },
				},
				-- the sand it throws up and its tunnelling (client/BurrowFx; no hole: QM)
				Sand = Color3.fromRGB(226, 190, 128),
				Sand2 = Color3.fromRGB(196, 156, 96), -- (the burrow's mounds alternate the two)
				Mound = 2.6, -- tunnelling: LassoAPet's Sandworm burrow, x this (its Size)
			},
		},
		ElderBoar = {
			Name = "Elder Boar",
			Model = "ElderBoar", -- (LassoAPet's, QM Oct 24)
			Size = 2.66, -- (about 36 studs tall, 53 long; QM Oct 30: x0.8)
			Health = 30000,
			Speed = 9,
			StopAt = 1, -- (walks right up to you, into its Swipe's Reach)
			Radius = 16,
			Turn = 3,
			Strength = 20,
			Respawn = 30,
			-- (QM, Oct 24: every boss just chases you and hurts on contact for now; Server/
			-- BossAttacks also has Slam, Shot, Nova and Bombs for later)
			Attacks = {
				{ Kind = "Swipe", Every = 2.4, Reach = 28, Arc = 150, Windup = 1, Damage = 50 },
				-- (tusks down, a hoof scrapes, then it charges: QM Oct 30)
				{ Kind = "Charge", Every = 5, Range = 90, Windup = 1.1, Speed = 75, Width = 30, Damage = 34, Anim = "charge" },
			},
		},
		LavaWyrm = {
			Name = "Lava Wyrm",
			Model = "LavaWyrm", -- (LassoAPet's, QM Oct 24)
			Size = 2.33, -- (about 25 studs tall, 103 long)
			Health = 200000,
			Speed = 8,
			StopAt = 1, -- (walks right up to you, into its Swipe's Reach)
			Radius = 17,
			Turn = 2.5,
			Strength = 60,
			Respawn = 35,
			-- (QM, Oct 24: every boss just chases you and hurts on contact for now; Server/
			-- BossAttacks also has Slam, Shot, Nova and Bombs for later)
			Attacks = {
				{ Kind = "Swipe", Every = 3, Reach = 32, Arc = 230, Windup = 1.2, Damage = 75 },
				-- (head reared back, then a gout of fireballs ahead of it: QM Oct 30, no rectangles)
				{
					Kind = "Magic",
					Every = 4.5,
					Cast = 0.7,
					Anim = "breath",
					Like = "Staff",
					Damage = 25,
					Height = 4,
					Burst = 4,
					BurstGap = 0.12,
					Shot = { Color = Color3.fromRGB(255, 120, 40), Count = 5, Spread = 14, Speed = 45, Homing = 0, Launch = 0, Range = 70, Slack = 0, Size = 1.5 },
				},
			},
		},
		-- QM, Oct 30: three bosses in every region, after Archero's (the Sandworm's way), in our
		-- style. Each new one names its own Model (designs/bosses, the boss modeller's) and a
		-- StandIn = { pet, size } drawn until that model's made. Rings of orbs are Magic with
		-- Spread 360 x (Count - 1) / Count, Launch and Homing 0. Numbers follow the balance
		-- curve: Desert 4k health, Tundra 30k, Lava 200k, Dungeon and Magic Circle 1.5M, Red
		-- Castle and Ocean 10M.

		-- Desert: Archero's scorpion. A long thin tail-stab swipe, then three poison barbs
		ScorpionKing = {
			Name = "Scorpion King",
			Model = "ScorpionKing",
			StandIn = { "Scorpion", 3.2 },
			Size = 3.25, -- (the Scorpion pet's drawing, 15.7 studs long: about 51 studs long, QM Oct 30: x0.8 of before)
			Health = 4000,
			Speed = 12,
			StopAt = 6,
			Radius = 14.5,
			Turn = 3.5,
			Strength = 6,
			Respawn = 25,
			Attacks = {
				{ Kind = "Swipe", Every = 2.6, Reach = 24, Arc = 110, Windup = 0.8, Damage = 26, Swings = 2, Anim = "pinch" },
				-- (the tail stab: a long thin swipe straight out ahead)
				{ Kind = "Swipe", Every = 3.5, Reach = 48, Arc = 24, Width = 40, Windup = 0.9, Damage = 22, Anim = "stab", Then = 3 },
				{
					Kind = "Magic",
					Linked = true, -- (after each stab)
					Every = 3.5,
					Like = "Staff",
					Damage = 12,
					Height = 6,
					Pulse = true,
					Shot = { Color = Color3.fromRGB(150, 230, 90), Count = 3, Spread = 40, Speed = 45, Homing = 0, Launch = 0, Range = 90, Slack = 0, Size = 1.3 },
				},
			},
		},

		-- Tundra: Archero's stone golem. Leaps onto you; landing throws a ring of ice shards
		FrostGolem = {
			Name = "Frost Golem",
			Model = "FrostGolem",
			StandIn = { "IceGolem", 1.8 },
			Size = 3.2,
			Health = 30000,
			Speed = 8,
			StopAt = 1,
			Radius = 15,
			Turn = 3,
			Strength = 20,
			Respawn = 30,
			Attacks = {
				{ Kind = "Swipe", Every = 2.6, Reach = 28, Arc = 160, Windup = 1, Damage = 50 },
				{ Kind = "Leap", Every = 5, Range = 90, Windup = 0.7, Airtime = 1.1, Height = 30, Radius = 18, Damage = 34, Anim = "leap", Then = 4 },
				{ Kind = "Slam", Every = 4, Range = 10, Radius = 16, Windup = 0.9, Damage = 34, Anim = "slam" },
				{
					Kind = "Magic",
					Linked = true, -- (the ring of shards as it lands)
					Every = 5,
					Like = "Staff",
					Damage = 18,
					Height = 4,
					Shot = { Color = Color3.fromRGB(170, 225, 255), Count = 10, Spread = 324, Speed = 38, Homing = 0, Launch = 0, Range = 80, Slack = 0, Size = 1.4 },
				},
			},
		},

		-- Tundra: a hovering snow owl. Snowballs lobbed at everyone, a fan of ice lances, feathers
		BlizzardOwl = {
			Name = "Blizzard Owl",
			Model = "BlizzardOwl",
			StandIn = { "Penguin", 3.6 },
			Size = 3.2,
			Health = 30000,
			Speed = 9,
			StopAt = 25, -- (keeps its distance)
			Radius = 12,
			Turn = 4,
			Strength = 20,
			Respawn = 30,
			Attacks = {
				{ Kind = "Lob", Every = 4, Count = 3, Scatter = 35, Radius = 11, Airtime = 1.3, Height = 32, Damage = 24, Style = "Snow", Cast = 0.5, Anim = "throw" },
				-- (three ice lances, flung like arrows)
				{
					Kind = "Magic",
					Every = 5,
					Cast = 0.6,
					Anim = "flap",
					Like = "Staff",
					Damage = 28,
					Height = 5,
					Shot = { Color = Color3.fromRGB(170, 225, 255), Count = 3, Spread = 22, Speed = 60, Homing = 0, Launch = 0, Range = 80, Slack = 0, Size = 1.2 },
				},
				{
					Kind = "Magic",
					Every = 3,
					Like = "Staff",
					Damage = 14,
					Height = 6,
					Burst = 2,
					BurstGap = 0.35,
					Pulse = true,
					Shot = { Color = Color3.fromRGB(235, 245, 255), Count = 5, Spread = 60, Speed = 42, Homing = 20, Launch = 0, Range = 90, Slack = 0 },
				},
			},
		},

		-- Lava: Archero's slimes. Three hops in a row at you, a ring of fireballs on each landing,
		-- and little slimes drop in at half health
		MagmaSlime = {
			Name = "Magma Slime",
			Model = "MagmaSlime",
			StandIn = { "RockHog", 3 },
			Size = 3.4,
			Health = 200000,
			Speed = 7,
			StopAt = 1,
			Radius = 16,
			Turn = 3,
			Strength = 60,
			Respawn = 35,
			Attacks = {
				{ Kind = "Swipe", Every = 3, Reach = 22, Arc = 300, Windup = 1.1, Damage = 70 },
				{ Kind = "Leap", Every = 6, Range = 100, Windup = 0.6, Airtime = 0.9, Height = 26, Radius = 19, Damage = 50, Hops = 3, Anim = "leap", Then = 3 },
				{
					Kind = "Magic",
					Linked = true,
					Every = 6,
					Like = "Staff",
					Damage = 26,
					Height = 4,
					Shot = { Color = Color3.fromRGB(255, 130, 40), Count = 8, Spread = 315, Speed = 34, Homing = 0, Launch = 0, Range = 70, Slack = 0, Size = 1.5 },
				},
			},
			Minions = {
				At = 0.5,
				Count = 4,
				Model = "MagmaSlime",
				StandIn = { "RockHog", 1.4 },
				Size = 1, -- (its own model, small: Server/Minions)
				Name = "Magma Blob",
				Health = 20000,
				Speed = 16,
				Strength = 20,
				Spread = 12,
				Drop = 0.8,
				DropFrom = 60,
				Dust = Color3.fromRGB(90, 60, 50),
				Attacks = { { Kind = "Swipe", Every = 1.6, Reach = 4, Arc = 100, Damage = 26 } },
			},
		},

		-- Lava: the Volcano Tortoise pet grown huge. Slow; lava bombs out of its shell, eruptions
		-- under everyone, and rock hogs at half health
		VolcanoTortoise = {
			Name = "Volcano Tortoise",
			Model = "VolcanoTortoise",
			Size = 3, -- (QM Oct 30: x0.6)
			Health = 200000,
			Speed = 5,
			StopAt = 1,
			Radius = 11,
			Turn = 2,
			Strength = 60,
			Respawn = 35,
			Attacks = {
				{ Kind = "Swipe", Every = 2.8, Reach = 22, Arc = 180, Windup = 1.1, Damage = 75 },
				{ Kind = "Lob", Every = 4, Count = 4, Scatter = 41.5, Radius = 13, Airtime = 1.4, Height = 48, Damage = 40, Style = "Lava", Cast = 0.8, Anim = "erupt" },
				{ Kind = "Bombs", Every = 7, Count = 3, Scatter = 20, Radius = 9, Windup = 1.4, Damage = 46 },
			},
			Minions = {
				At = 0.5,
				Count = 3,
				Model = "RockHog",
				Name = "Rock Hog",
				Scale = 0.8, -- (QM: half the size they were)
				Health = 40000,
				Speed = 15,
				Strength = 20,
				Spread = 12,
				Drop = 0.8,
				DropFrom = 60,
				Dust = Color3.fromRGB(90, 60, 50),
				Attacks = { { Kind = "Swipe", Every = 1.6, Reach = 4, Arc = 120, Damage = 28 } },
			},
		},

		-- Dungeon: Archero's skeleton king. A sword cleave, a charge, skeletons at half health
		BoneWarden = {
			Name = "Bone Warden",
			Model = "BoneWarden",
			StandIn = { "IceGolem", 1.8 },
			Size = 4.76, -- (QM Oct 30: x1.4)
			Health = 1500000,
			Speed = 10,
			StopAt = 1,
			Radius = 19.5,
			Turn = 3.5,
			Strength = 180,
			Respawn = 35,
			Attacks = {
				{ Kind = "Swipe", Every = 2.8, Reach = 30, Arc = 120, Windup = 0.9, Damage = 55, Swings = 2 },
				-- (the big sword cleave: QM, a swipe like any melee)
				{ Kind = "Swipe", Every = 4, Reach = 44, Arc = 170, Windup = 1.3, Damage = 80, Anim = "cleave" },
				{ Kind = "Charge", Every = 6, Range = 100, Windup = 0.8, Speed = 80, Width = 26, Damage = 60, Anim = "charge" },
			},
			Minions = {
				At = 0.5,
				Count = 4,
				Model = "Skeleton",
				StandIn = { "Snowman", 1.3 },
				Size = 2,
				Name = "Skeleton",
				Health = 200000,
				Speed = 16,
				Strength = 60,
				Spread = 12,
				Drop = 0.8,
				DropFrom = 60,
				Dust = Color3.fromRGB(104, 126, 146),
				Attacks = { { Kind = "Swipe", Every = 1.6, Reach = 5, Arc = 90, Damage = 35 } },
			},
		},

		-- Dungeon: Archero's floating eye. Rooted mid-arena; beams that ripple out at you, rings of orbs
		DungeonWatcher = {
			Name = "Dungeon Watcher",
			Model = "DungeonWatcher",
			StandIn = { "Fish", 5 },
			Size = 3.2,
			Health = 1500000,
			Speed = 0,
			Centre = true,
			StopAt = 1,
			Radius = 14,
			Turn = 2.5,
			TurnRate = 70,
			Strength = 180,
			Respawn = 35,
			Attacks = {
				-- (its stare: three streams of beams at you)
				{
					Kind = "Magic",
					Every = 4,
					Cast = 0.7,
					Anim = "stare",
					Like = "Staff",
					Damage = 30,
					Height = 6,
					Burst = 5,
					BurstGap = 0.15,
					Shot = { Color = Color3.fromRGB(190, 255, 210), Count = 3, Spread = 25, Speed = 55, Homing = 0, Launch = 0, Range = 120, Slack = 0, Size = 1.1 },
				},
				{
					Kind = "Magic",
					Every = 3,
					Like = "Staff",
					Damage = 40,
					Height = 6,
					Burst = 2,
					BurstGap = 0.6,
					Pulse = true,
					Shot = { Color = Color3.fromRGB(90, 255, 130), Count = 12, Spread = 330, Speed = 30, Homing = 0, Launch = 0, Range = 110, Slack = 0, Size = 1.4 },
				},
			},
		},

		-- Dungeon: a treasure chest that bites. Chomping charges, gold coins lobbed at you
		TreasureMimic = {
			Name = "Treasure Mimic",
			Model = "TreasureMimic",
			StandIn = { "Pig", 5.5 },
			Size = 4.4,
			Health = 1500000,
			Speed = 11,
			StopAt = 1,
			Radius = 15,
			Turn = 4,
			Strength = 180,
			Respawn = 35,
			Attacks = {
				{ Kind = "Swipe", Every = 2, Reach = 28, Arc = 110, Windup = 0.9, Damage = 100 },
				{ Kind = "Charge", Every = 4, Range = 100, Windup = 0.7, Speed = 90, Width = 24, Damage = 65, Anim = "charge", Then = 3 },
				{ Kind = "Lob", Linked = true, Every = 4, Count = 4, Scatter = 38.5, Radius = 11, Airtime = 1.2, Height = 35, Damage = 45, Style = "Coin", Cast = 0.5, Anim = "spit" },
			},
		},

		-- Red Castle, the raid: Bandos-style. At 70% it raises a shield and calls three guards; it
		-- can't be hurt till they're all down
		CrimsonKnight = {
			Name = "Crimson Knight",
			Model = "CrimsonKnight",
			StandIn = { "IceGolem", 2 },
			Size = 4.2, -- (LassoAPet's Asura, 10.9 studs tall: about 46 studs, QM Oct 30)
			Health = 10000000,
			Speed = 9,
			StopAt = 1,
			Radius = 15,
			Turn = 3,
			Strength = 500,
			Respawn = 40,
			Attacks = {
				-- (QM, Oct 30: each slash of the combo bigger than the last: 1x, 1.25x, 1.5x)
				{ Kind = "Swipe", Every = 3.6, Reach = 30, Arc = 150, Windup = 0.85, Damage = 75, Swings = 3, Grow = 0.25 },
				{ Kind = "Charge", Every = 6, Range = 120, Windup = 1, Speed = 85, Width = 28, Damage = 90, Anim = "charge" },
				{ Kind = "Slam", Every = 4, Range = 14, Radius = 18, Windup = 0.8, Damage = 90, Anim = "slam" },
			},
			Minions = {
				At = 0.7,
				Count = 3,
				Shield = true, -- (Server/Minions: the knight can't be hurt while any stands)
				Anim = "summon", -- (its lance raised as they drop in)
				Model = "CastleGuard",
				StandIn = { "IceGolem", 0.9 },
				Size = 1.6,
				Name = "Castle Guard",
				Health = 1500000,
				Speed = 15,
				Strength = 150,
				Spread = 14,
				Drop = 0.8,
				DropFrom = 60,
				Dust = Color3.fromRGB(156, 22, 42),
				Attacks = { { Kind = "Swipe", Every = 1.8, Reach = 6, Arc = 120, Damage = 50 } },
			},
		},

		-- Red Castle: Archero's bats. Blinks round the arena, then a sonic ring; red circles under you
		BloodBat = {
			Name = "Blood Bat",
			Model = "BloodBat",
			StandIn = { "Firebird", 2.8 },
			Size = 3.2, -- (LassoAPet's Bat, hovering, 18 studs across the wings: about 58, QM Oct 30)
			Health = 10000000,
			Speed = 12,
			StopAt = 15,
			Radius = 14,
			Turn = 4,
			Strength = 500,
			Respawn = 40,
			Attacks = {
				{ Kind = "Swipe", Every = 1.8, Reach = 24, Arc = 120, Windup = 0.8, Damage = 85 },
				{ Kind = "Blink", Every = 4.5, Fade = 0.6, Near = 30, Far = 55, Anim = "screech", Then = 3 },
				{
					Kind = "Magic",
					Linked = true,
					Every = 4.5,
					Like = "Staff",
					Damage = 55,
					Height = 6,
					Burst = 2,
					BurstGap = 0.4,
					Pulse = true,
					Shot = { Color = Color3.fromRGB(255, 70, 90), Count = 14, Spread = 334, Speed = 36, Homing = 0, Launch = 0, Range = 100, Slack = 0, Size = 1.3 },
				},
				{ Kind = "Bombs", Every = 6, Count = 3, Scatter = 20, Radius = 9, Windup = 1.2, Damage = 80 },
			},
		},

		-- Red Castle: a dragon. Fire breath fanned three ways, fireballs, a wing-borne leap
		CastleWyvern = {
			Name = "Castle Wyvern",
			Model = "CastleWyvern",
			StandIn = { "Phoenix", 3.2 },
			Size = 2.25, -- (LassoAPet's Rock Candy Dragon, 33 studs long: about 74, QM Oct 30)
			Health = 10000000,
			Speed = 10,
			StopAt = 6,
			Radius = 20,
			Turn = 3,
			Strength = 500,
			Respawn = 40,
			Attacks = {
				{ Kind = "Swipe", Every = 3, Reach = 34, Arc = 220, Windup = 1.2, Damage = 130 },
				-- (fire breath: three gouts of fireballs)
				{
					Kind = "Magic",
					Every = 4.5,
					Cast = 0.7,
					Anim = "breath",
					Like = "Staff",
					Damage = 45,
					Height = 5,
					Burst = 4,
					BurstGap = 0.12,
					Shot = { Color = Color3.fromRGB(255, 110, 50), Count = 3, Spread = 25, Speed = 45, Homing = 0, Launch = 0, Range = 70, Slack = 0, Size = 1.5 },
				},
				{ Kind = "Lob", Every = 4, Count = 3, Scatter = 38.5, Radius = 13, Airtime = 1.3, Height = 41.5, Damage = 70, Style = "Fire" },
				{ Kind = "Leap", Every = 8, Range = 120, Windup = 0.8, Airtime = 1.3, Height = 40, Radius = 25, Damage = 90, Anim = "leap" },
			},
		},

		-- Magic Circle: Archero's teleporting mage. Never walks up to you; blinks away and casts
		RuneMage = {
			Name = "Rune Mage",
			Model = "RuneMage",
			StandIn = { "Snowman", 3.3 },
			Size = 3.4,
			Health = 1500000,
			Speed = 6,
			StopAt = 30,
			Radius = 10,
			Turn = 4,
			Strength = 180,
			Respawn = 35,
			Attacks = {
				{ Kind = "Blink", Every = 5, Fade = 0.6, Near = 35, Far = 60, Then = 2 },
				{
					Kind = "Magic",
					Every = 2.5,
					Like = "Staff",
					Damage = 40,
					Height = 6,
					Burst = 3,
					BurstGap = 0.3,
					Pulse = true,
					Cast = 0.4,
					Anim = "cast",
					Shot = { Color = Color3.fromRGB(249, 168, 255), Count = 3, Spread = 30, Speed = 45, Homing = 40, Launch = 10, Range = 100, Slack = 0, Size = 1.3 },
				},
				{ Kind = "Bombs", Every = 6, Count = 4, Scatter = 22, Radius = 9, Windup = 1.3, Damage = 60 },
			},
		},

		-- Magic Circle: Archero's tree. Rooted mid-arena; roots erupt in rows creeping out at you,
		-- seeds, and saplings at half health
		ElderTreant = {
			Name = "Elder Treant",
			Model = "ElderTreant",
			StandIn = { "VenusFlytrap", 2.6 },
			Size = 1.75, -- (LassoAPet's Ancient Treant, 32 studs tall: about 56, QM Oct 30)
			Health = 1500000,
			Speed = 0,
			Centre = true,
			StopAt = 1,
			Radius = 15,
			Turn = 2.5,
			TurnRate = 80,
			Strength = 180,
			Respawn = 35,
			Attacks = {
				{ Kind = "Line", Every = 4, Range = 200, Windup = 1, Width = 10, Length = 16, Segments = 6, Gap = 0.15, Count = 2, Spread = 30, Damage = 65, Anim = "roots", Style = "Root" },
				{
					Kind = "Magic",
					Every = 2.5,
					Like = "RafflesiaBloom",
					Damage = 40,
					Height = 6,
					Shot = { Homing = 60, Launch = 30, Range = 100, Slack = 0 },
				},
			},
			Minions = {
				At = 0.5,
				Count = 4,
				Model = "AncientTreant",
				StandIn = { "Cactus", 1.4 },
				Size = 1.4,
				Scale = 1.1, -- (x the Ancient Treant pet)
				Name = "Sapling",
				Health = 200000,
				Speed = 14,
				Strength = 60,
				Spread = 12,
				Drop = 0.8,
				DropFrom = 60,
				Dust = Color3.fromRGB(56, 196, 168),
				Attacks = { { Kind = "Swipe", Every = 1.6, Reach = 4, Arc = 110, Damage = 35 } },
			},
		},

		-- Magic Circle: a giant mushroom. Leaps, rings of spore circles round itself, spore spray
		ToadstoolKing = {
			Name = "Toadstool King",
			Model = "ToadstoolKing",
			StandIn = { "Cactus", 3 },
			Size = 3.4,
			Health = 1500000,
			Speed = 8,
			StopAt = 1,
			Radius = 14,
			Turn = 3,
			Strength = 180,
			Respawn = 35,
			Attacks = {
				{ Kind = "Swipe", Every = 2.8, Reach = 22, Arc = 270, Windup = 1.1, Damage = 100 },
				{ Kind = "Leap", Every = 5, Range = 90, Windup = 0.6, Airtime = 1, Height = 28, Radius = 17, Damage = 70, Anim = "leap", Then = 3 },
				{ Kind = "Bombs", Linked = true, Every = 5, Count = 8, Around = true, Scatter = 8, Radius = 8, Windup = 1.2, Damage = 60, Cast = 0.5, Anim = "puff" },
				{
					Kind = "Magic",
					Every = 3,
					Like = "Staff",
					Damage = 40,
					Height = 5,
					Pulse = true,
					Shot = { Color = Color3.fromRGB(255, 160, 220), Count = 5, Spread = 70, Speed = 40, Homing = 30, Launch = 10, Range = 90, Slack = 0 },
				},
			},
		},

		-- Ocean: LassoAPet's King Crab grown huge. Scuttling charges, a claw slam, bubbles
		KingCrab = {
			Name = "King Crab",
			Model = "KingCrab",
			Size = 7.2, -- (QM Oct 30: x0.8)
			Health = 10000000,
			Speed = 10,
			StopAt = 1,
			Radius = 17.5,
			Turn = 3,
			Strength = 500,
			Respawn = 40,
			Attacks = {
				{ Kind = "Swipe", Every = 2.8, Reach = 28, Arc = 120, Windup = 0.95, Damage = 75, Swings = 2 },
				{ Kind = "Charge", Every = 5, Range = 110, Windup = 0.9, Speed = 80, Width = 40, Damage = 90, Anim = "charge" },
				{ Kind = "Slam", Every = 4, Range = 14, Radius = 20, Windup = 0.9, Damage = 90, Anim = "slam" },
				{
					Kind = "Magic",
					Every = 3,
					Like = "Staff",
					Damage = 50,
					Height = 5,
					Burst = 3,
					BurstGap = 0.3,
					Shot = { Color = Color3.fromRGB(140, 200, 236), Count = 1, Size = 1.6, SizeMax = 1.5, Speed = 40, Homing = 50, Launch = 60, Range = 100, Slack = 0 },
				},
			},
		},

		-- Ocean: a pufferfish lord. Puffs up and bursts a ring of spines; charges
		PufferLord = {
			Name = "Puffer Lord",
			Model = "PufferLord",
			StandIn = { "Fish", 5 },
			Size = 3.4,
			Health = 10000000,
			Speed = 10,
			StopAt = 1,
			Radius = 15,
			Turn = 3.5,
			Strength = 500,
			Respawn = 40,
			Attacks = {
				{ Kind = "Swipe", Every = 2.8, Reach = 18, Arc = 330, Windup = 1.1, Damage = 120 },
				{
					Kind = "Magic",
					Every = 4,
					Like = "Staff",
					Damage = 60,
					Height = 5,
					Burst = 2,
					BurstGap = 0.5,
					Cast = 1,
					Anim = "puff",
					Shot = { Color = Color3.fromRGB(255, 230, 140), Count = 16, Spread = 337.5, Speed = 34, Homing = 0, Launch = 0, Range = 100, Slack = 0, Size = 1.2 },
				},
				{ Kind = "Charge", Every = 6, Range = 110, Windup = 0.9, Speed = 85, Width = 26, Damage = 90, Anim = "charge" },
			},
		},

		-- Ocean: LassoAPet's shark boss (QM, Oct 30, in place of the Kraken). It swims under the
		-- floor like the Sandworm (its Burrow: a wake runs over the ground), hunting whoever's
		-- nearest for up to Hunt seconds; then a red circle fills where it is and it bursts up
		-- through it (Breach), throwing a ring of water orbs (its Magic, on surfacing), bites
		-- at anyone close while it's up (its Swipe), and dives again
		Shark = {
			Name = "Trench Shark",
			Model = "SharkBoss",
			StandIn = { "Fish", 5 },
			Size = 12, -- (Lasso's shark boss is a small drawing: about 60 studs long, 36 tall)
			Health = 10000000,
			Speed = 0, -- (it never walks: it swims under, Burrow)
			StopAt = 1,
			Radius = 18,
			Turn = 5,
			TurnRate = 200,
			Strength = 500,
			Respawn = 40,
			Attacks = {
				{ Kind = "Swipe", Every = 1.4, Reach = 30, Arc = 120, Windup = 0.9, Damage = 90, Anim = "bite" },
				{
					Kind = "Magic",
					Linked = true, -- (fired as it surfaces, by its Burrow: Server/Bosses)
					Every = 4,
					Like = "Staff",
					Damage = 55,
					Height = 5,
					Burst = 2,
					BurstGap = 0.5,
					Shot = { Color = Color3.fromRGB(140, 200, 236), Count = 12, Spread = 330, Speed = 32, Homing = 0, Launch = 0, Range = 100, Slack = 0, Size = 1.4 },
				},
			},
			Burrow = {
				Emerge = 0.5,
				Aim = 0.2, -- (its ring goes out just as it's up)
				Linger = 2.5, -- (up this long after its ring: bite range)
				Hide = 0.5,
				Speed = 34, -- studs/s swimming under (a Horse outruns it; slower pets don't)
				Travel = 0,
				Hunt = 3, -- seconds it chases you under the floor before it breaches
				Near = 0,
				Far = 10,
				Hop = 0,
				Breach = { Radius = 22, Windup = 0.8, Damage = 90, Anim = "breach" },
				Depth = 3.4, -- (model studs it sinks to be all under, x Size)
				Pose = {},
				Sand = Color3.fromRGB(220, 240, 255), -- (its wake: foam and sea)
				Sand2 = Color3.fromRGB(140, 200, 236),
				Mound = 3,
			},
		},
	},
	-- each biome's boss: one of these at random every time it (re)spawns (QM, Oct 25; /reboss
	-- re-rolls them all)
	-- what beating a boss pays (QM, Oct 31): about Share of what the next region costs
	-- (Config.Regions.Cost[Next[its biome]]), to everyone who beat it, x2 with the x2 Cash
	-- pass. Past the last regions, Last x their own cost. Meadow bosses pay $120 (Desert's 6K),
	-- Desert's 2.4K, Tundra's 30K, Lava Valley's 400K, Dungeon's and Magic Circle's 5M.
	BossCash = {
		Share = 1 / 50,
		Next = { Meadow = "Desert", Desert = "Ice", Ice = "Lava", Lava = "Dungeon", Dungeon = "Castle", Forest = "Ocean" },
		Last = 10,
	},

	-- the new player tutorial (QM, Oct 31; client/Tutorial, Server/Tutorial): a new player
	-- starts on foot with no pets (OnFoot: WalkSpeed, FootHealth), Egg in hand and no UI,
	-- places it in their pen, hatches it (ready in HatchTime seconds), rides what hatched
	-- (QM, Oct 31: "after hatching they must ride"), steals a Meadow egg, beats its boss (always Boss in the tutorial;
	-- every hit they take is x Damage, so they out-heal it), gets at least BossCash for it,
	-- buys Weapon from Carl and buys Ground's training ground for free. Their first hit on a
	-- mob there ends it (TutorialDone, saved: a returning player never sees it again).
	-- Owner/Studio chat commands: /tutorial (run it again), /skiptutorial.
	Tutorial = {
		On = true,
		Egg = "Horse",
		HatchTime = 0,
		Boss = "MotherHen",
		Damage = 0.02,
		BossCash = 500, -- (the Shortbow's price)
		Weapon = "Shortbow",
		Ground = "Meadow",
		WalkSpeed = 16, -- on foot, before the first ride
		FootHealth = 100,
	},
	BossPools = {
		Meadow = { "MotherHen", "GiantRafflesia", "MajesticUnicorn", "VenusFlytrap" },
		Desert = { "CactusBoss", "Sandworm", "ScorpionKing" },
		Ice = { "ElderBoar", "FrostGolem", "BlizzardOwl" },
		Lava = { "LavaWyrm", "MagmaSlime", "VolcanoTortoise" },
		-- (QM, Oct 30: three in every region; Server/Bosses draws a StandIn pet for one whose
		-- model isn't made yet)
		Dungeon = { "BoneWarden", "DungeonWatcher", "TreasureMimic" },
		Castle = { "CrimsonKnight", "BloodBat", "CastleWyvern" },
		Forest = { "RuneMage", "ElderTreant", "ToadstoolKing" },
		Ocean = { "KingCrab", "PufferLord", "Shark" },
	},
	-- healing (QM, Oct 30; Server/Regen): always on, in a fight or not, at your pet's Regen
	-- (health a second: Config.PetStats.Regen, Shared/Pets). A sprint ability can speed it
	-- up (the Snake's: Config.SprintAbility.Glow). (Replaces Roblox's default slow regen;
	-- before Oct 30 it was 10% a second after 10 s without a hit.)
	-- boss melee only hits in front (QM, Oct 27: circle round a boss and you dodge it):
	-- its Swipe's Arc (Config.EnemySwipe), and bosses turn at most TurnRate degrees a second
	-- (Server/Bosses; a boss's own TurnRate overrides it). A Horse (44 studs/s) circling
	-- Mother Hen's reach (about 15 studs out) sweeps about 170 degrees a second, so it
	-- outruns 120; a Fish (about 26 studs/s) can't, until it hugs closer.
	BossMelee = {
		TurnRate = 120,
	},
	-- every enemy's melee (QM, Oct 30): a swipe like the player's, after a red telegraph in
	-- its shape fills on the ground for Windup seconds, so you can step out of it. Each
	-- attack's Swipe sets its Reach, Arc and Damage (Server/BossAttacks); these are the
	-- rest of its look, the same keys as Config.Slash (Shared/SlashFx), plus the
	-- telegraph's (client/Swipes, styled like the bombs' landing rings: client/Bombs).
	EnemySwipe = {
		Windup = 0.5, -- seconds from the telegraph appearing to the hit (bosses set longer)
		Arc = 120,
		-- how much bigger than its Reach (and Width) every swipe really is, by region (QM,
		-- Oct 30: pets are fast, so dodging was trivial; about 1.6x across the board,
		-- growing further out). Bosses, minions and training mobs alike; a training
		-- ground goes by its name (Meadow, Desert, Ice, Lava), Dummies and anything else
		-- by Default.
		Scale = {
			Default = 1.6,
			Meadow = 1.5,
			Desert = 1.6,
			Ice = 1.6,
			Lava = 1.7,
			Dungeon = 1.8,
			Castle = 1.9,
			Forest = 1.9,
			Ocean = 2,
		},
		-- where it sits (QM, Oct 30: out in front, never over the enemy itself): a swipe of
		-- Narrow degrees or less is centred Ahead of the way to its front edge; Wrap or more on its
		-- middle (it goes most of the way round); in between, in between
		Narrow = 140,
		Wrap = 220,
		Ahead = 0.5, -- (a narrow one's centre: this share of the way out to its front edge)
		Clear = 1, -- studs its inner edge stays off the enemy's body
		Thick = 0.65, -- thickness, of its radius (less if that would reach the body; Width overrides)
		Ends = 0.75, -- (fat ends: it reads as an area, not a streak)
		Belly = 0.4,
		Skew = 1,
		OuterSegments = 5,
		InnerSegments = 3,
		Jitter = 0.6,
		RadiusJitter = 0.03,
		MaxStrip = 0.06,
		Variety = {
			Arc = { 0.95, 1.05 },
			Radius = { 0.97, 1.03 },
			Width = { 0.9, 1.1 },
			Belly = { 0.7, 1.3 },
			Skew = { 0.8, 1.25 },
			Ends = { 0.85, 1.15 },
			OuterSegments = { 0.8, 1.2 },
			InnerSegments = { 0.67, 1.34 },
			Jitter = { 0.7, 1.3 },
			RadiusJitter = { 0.5, 1.5 },
		},
		-- the swipe itself (white, like yours)
		Height = 1.2, -- studs above the ground
		Color = Color3.fromRGB(255, 255, 255),
		Opacity = 0.35,
		Glow = 0.8,
		Sweep = 0.12,
		Ease = 3,
		Hold = 0.1,
		Fade = 0.2,
		Trail = 1.15,
		Pop = 1.1,
		-- the telegraph (red, filling from its inner edge out to the outer by the hit)
		Warn = Color3.fromRGB(255, 50, 35),
		Lift = 0.15, -- studs above the ground
		Outline = 0.15, -- transparency of its outline (all round)
		OutlineWidth = 0.4, -- studs
		FadeBands = 4, -- inside the outer edge, faint red to clear going in
		FadeEdge = 0.6,
		FadeDepth = 0.6, -- of its thickness
		Fill = 0.5, -- transparency of the fill
		Edge = 0.15, -- the fill's leading edge
		EdgeWidth = 0.35, -- studs
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
	-- the boss fight camera (QM, Oct 29): locked into a fight, the camera looks steeply down
	-- on you from high up, from a fixed side, and follows you; no turning or zooming it
	-- (client/FightCam). Pitch: degrees down from level (90 = straight down). Yaw: which
	-- side it looks from, degrees (0 = from the south, looking north). Distance: studs from
	-- you. Height: studs above your middle it aims at. Fov: field of view (Roblox's usual
	-- is 70; lower looks flatter). InTime / OutTime: seconds easing in and back out.
	-- Fixed (QM, Oct 30): held over the arena's middle instead, back far enough that the
	-- arena's width times Fit fills the screen (Distance unused then).
	FightCam = { On = true, Fixed = true, Fit = 1, Pitch = 62, Yaw = 0, Distance = 80, Height = 0, Fov = 55, InTime = 0.6, OutTime = 0.6 },
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
			-- the bosses made in Python: written by tools/boss_designs.py from each one's sleep() (QM, Oct 30)
			FrostGolem = { -- (slumped down, fists on the ground)
				Bones = {
					root = { 0, -1.4, 0, -0.10472, 0, 0 },
					ArmL = { 0, 0, 0, 0.17453, 0, 0.10472 },
					ArmR = { 0, 0, 0, 0.17453, 0, -0.10472 },
				},
				Breathe = {
					root = { 0, 0.15, 0, 0.01745, 0, 0 },
				},
				Shut = { "GlowL", "GlowR" },
				Hide = {},
			},
			BlizzardOwl = { -- (landed, wings tucked in)
				Bones = {
					root = { 0, -3.4, 0, 0, 0, 0 },
					WingL = { 0, 0, 0, 0, 0, 0.10472 },
					WingR = { 0, 0, 0, 0, 0, -0.10472 },
				},
				Breathe = {
					root = { 0, 0.12, 0, 0, 0, 0 },
					WingL = { 0, 0, 0, 0, 0, 0.05236 },
					WingR = { 0, 0, 0, 0, 0, -0.05236 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = { "PupilL", "PupilR" },
			},
			MagmaSlime = { -- (settled, its lid down)
				Bones = {
					root = { 0, -0.5, 0, 0, 0, 0 },
					Lid = { 0, -0.15, 0, 0, 0, 0 },
				},
				Breathe = {
					root = { 0, 0.12, 0, 0, 0, 0 },
					Lid = { 0, 0.2, 0, 0, 0, 0 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = {},
			},
			BoneWarden = { -- (sat on the ground, legs out, skull drooped, sword laid forward)
				Bones = {
					root = { 0, -2.4, 0.6, 0, 0, 0 },
					LegL = { 0, 0, 0, 1.39626, 0, -0.13963 },
					LegR = { 0, 0, 0, 1.39626, 0, 0.13963 },
					neck = { 0, 0, 0, -0.43633, 0, 0.13963 },
					ArmR = { 0, 0, 0, 0.34907, 0, 0 },
					ArmL = { 0, 0, 0, 0.17453, 0, -0.10472 },
				},
				Breathe = {
					root = { 0, 0.1, 0, 0, 0, 0 },
					neck = { 0, 0, 0, 0.05236, 0, 0 },
				},
				Shut = {},
				Hide = { "GlowL", "GlowR" },
			},
			DungeonWatcher = { -- (sunk to the floor, its lid shut)
				Bones = {
					root = { 0, -3.6, 0, 0, 0, 0 },
					Lid = { 0, -2.6, 0, 0, 0, 0 },
				},
				Breathe = {
					root = { 0, 0.15, 0, 0, 0, 0 },
				},
				Shut = { "Sclera" },
				Hide = { "Iris", "Pupil" },
			},
			TreasureMimic = { -- (just a chest, lid shut, lifting a crack with each breath)
				Bones = {
					root = { 0, -0.2, 0, 0, 0, 0 },
					Lid = { 0, 0, 0, 0, 0, 0 },
				},
				Breathe = {
					root = { 0, 0.08, 0, 0, 0, 0 },
					Lid = { 0, 0, 0, 0.06981, 0, 0 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = {},
			},
			RuneMage = { -- (settled down, hat tipped over its eyes)
				Bones = {
					root = { 0, -0.3, 0, -0.06981, 0, 0 },
					Hat = { 0, -0.3, -0.2, -0.24435, 0, 0 },
					ArmR = { 0, 0, 0, 0.06981, 0, 0 },
				},
				Breathe = {
					root = { 0, 0.1, 0, 0, 0, 0 },
					Hat = { 0, 0, 0, 0.03491, 0, 0 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = {},
			},
			ToadstoolKing = { -- (squat, cap tipped forward)
				Bones = {
					root = { 0, -0.8, 0, 0, 0, 0 },
					Cap = { 0, -0.5, 0, -0.13963, 0, 0 },
				},
				Breathe = {
					Cap = { 0, 0.2, 0, 0, 0, 0 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = {},
			},
			PufferLord = { -- (resting on the sand, deflated)
				Bones = {
					root = { 0, -3.4, 0, 0, 0, 0 },
					Tail = { 0, 0, 0, 0, 0.34907, 0 },
				},
				Breathe = {
					root = { 0, 0.15, 0, 0, 0, 0 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = { "PupilL", "PupilR" },
			},
			ScorpionKing = { -- (belly down, pincers tucked in, tail drooped forward)
				Bones = {
					root = { 0, -1, 0, 0, 0, 0 },
					ClawL = { 0.3, -0.4, 0.8, -0.13963, -0.34907, 0 },
					ClawR = { -0.3, -0.4, 0.8, -0.13963, 0.34907, 0 },
					Tail = { 0, -0.3, 0, 0.27925, 0, 0 },
				},
				Breathe = {
					root = { 0, 0.1, 0, 0, 0, 0 },
					Tail = { 0, 0, 0, 0.05236, 0, 0 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = { "PupilL", "PupilR" },
			},
			ElderTreant = { -- (branches drooped, canopy sagging)
				Bones = {
					root = { 0, 0, 0, -0.03491, 0, 0 },
					ArmL = { 0, 0, 0, 0.06981, 0, 0.24435 },
					ArmR = { 0, 0, 0, 0.06981, 0, -0.24435 },
					neck = { 0, -0.5, 0, -0.13963, 0, 0 },
				},
				Breathe = {
					neck = { 0, 0.2, 0, 0.01745, 0, 0 },
				},
				Shut = {},
				Hide = {},
			},
			CrimsonKnight = { -- (asleep on his feet, head drooped, sword lowered)
				Bones = {
					legs = { 0, -0.3, 0, 0, 0, 0 },
					body = { 0, 0, 0, -0.13963, 0, 0 },
					neck = { 0, -0.1, 0, -0.45379, 0, 0.06981 },
					left_shoulder = { 0, 0, 0, 0.10472, 0, 0 },
				},
				Breathe = {
					body = { 0, 0, 0, 0.02618, 0, 0 },
					neck = { 0, 0, 0, 0.05236, 0, 0 },
				},
				Shut = { "GlowEyeL", "GlowEyeR" },
				Hide = {},
			},
			BloodBat = { -- (landed, wrapped in its wings)
				Bones = {
					root = { 0, -4, 0, 0, 0, 0 },
					WingL = { 0, 0, 0, 0, -0.95993, 0.34907 },
					WingR = { 0, 0, 0, 0, 0.95993, -0.34907 },
					WingL2 = { 0, 0, 0, 0, -1.0472, 0 },
					WingR2 = { 0, 0, 0, 0, 1.0472, 0 },
					neck = { 0, -0.2, 0, -0.17453, 0, 0 },
				},
				Breathe = {
					root = { 0, 0.1, 0, 0, 0, 0 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = { "PupilL", "PupilR" },
			},
			CastleWyvern = { -- (lying down, head on the ground, tail curled round, wings folded)
				Bones = {
					root = { 0, -3.4, 0, 0, 0, 0 },
					neck = { 0, -1.2, 0, -0.31416, 0.41888, 0 },
					Tail1 = { 0, 0, 0, 0, -0.45379, 0 },
					Tail2 = { 0, 0, 0, 0, -0.45379, 0 },
					Tail3 = { 0, 0, 0, 0, -0.38397, 0 },
					LegFL = { 0, 0, 0, -1.22173, 0, 0 },
					LegFR = { 0, 0, 0, -1.22173, 0, 0 },
					LegHL = { 0, 0, 0, 1.22173, 0, 0 },
					LegHR = { 0, 0, 0, 1.22173, 0, 0 },
				},
				Breathe = {
					root = { 0, 0.12, 0, 0, 0, 0 },
					WingL = { 0, 0, 0, 0, 0, -0.06981 },
					WingR = { 0, 0, 0, 0, 0, 0.06981 },
				},
				Shut = { "EyeL", "EyeR" },
				Hide = { "PupilL", "PupilR" },
			},
			SharkBoss = { -- (resting on the floor, jaws shut, tail still)
				Bones = {
					root = { 0, -0.2, 0, 0, 0, 0 },
					Tail = { 0, 0, 0, 0, 0.17453, 0 },
					TailFin = { 0, 0, 0, 0, 0.13963, 0 },
				},
				Breathe = {
					root = { 0, 0.05, 0, 0, 0, 0 },
					FinL = { 0, 0, 0, 0, 0, 0.06981 },
					FinR = { 0, 0, 0, 0, 0, -0.06981 },
				},
				Shut = {},
				Hide = { "Pupil" },
			},
			-- end of the bosses made in Python
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
		-- seconds after a fight ends before the nests refill (QM, Oct 27): 10 in the Meadow,
		-- 5 more each biome further in; both sides of the fork past the Lava share a step
		Cooldown = { Meadow = 10, Desert = 15, Ice = 20, Lava = 25, Dungeon = 30, Forest = 30, Castle = 35, Ocean = 35 },
		DefaultCooldown = 60, -- (a biome missing from Cooldown)
		PopStagger = 0.15, -- seconds between each nest's egg popping in
		TimerRange = 45, -- studs from a nest you see its cooldown over it
		-- does a stolen egg ride on your back (and earn its reward in your pen)? Off for now
		-- (QM, Oct 25): stealing only wakes the boss and locks you into its fight
		Carry = false,
		-- (QM, Oct 25: real eggs, LassoAPet's: Shared/Eggs/<Kind>EggModel, one per animal.)
		-- Each nest lays one of its biome's kinds, by these weights (LassoAPet's spawn odds:
		-- each biome's Herd there). A new animal: its egg model, Pets above, then here.
		-- The biomes past the Lava Valley (QM, Oct 30) lay the later pets (tools/later_pets.py),
		-- on odds shaped like the Lava Valley's.
		Kinds = {
			Meadow = { Pinto = 0.35, Pig = 0.25, Bunny = 0.25, Fish = 0.13, Rhino = 0.08, Unicorn = 0.05 },
			Desert = { Cactus = 0.3, Scorpion = 0.3, Sandworm = 0.2, SpineLizard = 0.2, Snake = 0.025 },
			Ice = { Penguin = 0.3, Boar = 0.25, Snowman = 0.22, IceGolem = 0.12, Icebringer = 0.02 },
			Lava = { Firebird = 0.42, RockHog = 0.18, FireLobster = 0.17, Rockworm = 0.13, VolcanoTortoise = 0.1, Phoenix = 0.03, LavaWhale = 0.03 }, -- (LassoAPet's Volcano)
			Dungeon = { DungeonRat = 0.34, Bat = 0.2, Slime = 0.18, CaveSpider = 0.16, BoneSteed = 0.12, Mimic = 0.07, BoneWyrm = 0.03 },
			Castle = { WarBoar = 0.35, RoyalSteed = 0.22, ChessKnight = 0.15, RoyalPeacock = 0.13, LivingArmor = 0.08, CrimsonDrake = 0.05, RoyalEagle = 0.02 },
			Forest = { Shroom = 0.35, SpiritFox = 0.22, SpiritDeer = 0.15, AncientTreant = 0.13, MysticOwl = 0.08, CrystalTortoise = 0.05, SpiritLoong = 0.02 },
			Ocean = { Squid = 0.38, Seahorse = 0.22, KingCrab = 0.17, FishSchool = 0.12, Whale = 0.08, AbyssWhale = 0.03 },
		},
		Scale = { Nest = 1.3, Carried = 0.6, Pen = 0.9 }, -- times the egg's drawing (about 4 studs tall)
		-- a nest's egg is also this x bigger by its pet's rarity (QM, Oct 27: a Legendary's
		-- much bigger than a Common's)
		RarityScale = { Common = 1, Uncommon = 1.1, Rare = 1.25, Epic = 1.45, Legendary = 1.75, Mythic = 2, Divine = 2.2, Celestial = 2.4, Cosmic = 2.6, Void = 2.8, Omega = 3 },
		Twitch = { 3, 8 }, -- seconds between an egg's AFK twitches (random in this range)
		Reward = { Meadow = 100, Desert = 600, Ice = 3000, Lava = 15000, Dungeon = 60000, Forest = 60000, Castle = 250000, Ocean = 250000 },
		PenShows = 24, -- most eggs sat in a pen
	},

	-- saving (Server/Data): the DataStore's name (a new name starts everyone fresh)
	Data = {
		Store = "Players_v1",
		AutoSave = 90, -- seconds
		-- offline earnings (QM, Oct 27): a tenth of the pen's income, for up to 4 hours away
		OfflineRate = 0.1,
		OfflineMax = 4 * 3600, -- seconds
		-- the Offline Cash popup (QM, Oct 31; client/OfflineCash): what came in while away waits
		-- there till Claim. Its 2x button is a Roblox developer product: put its id from the
		-- Creator Dashboard here (till then, in Studio the button just pays 2x for free). The
		-- price shown is the product's own once it has an id; OfflineDoubleRobux till then.
		OfflineDoubleProduct = 3724925413,
		OfflineDoubleRobux = 49,
		OfflinePopupDelay = 1.5, -- seconds after joining before it pops up
	},

	-- rebirth (Server/Data, the Rebirth popup): cash needed is Cost x Growth ^ rebirths so far;
	-- it resets your cash, Strength and training grounds, and each rebirth makes every hit
	-- train StrengthBonus more (0.5: 1.5x after one, 2x after two) and your pen earn
	-- CashBonus more (Config.Income). Weapons and pets are kept. (Balance, Oct 27: the first
	-- is about an hour and a half in, after the Lava Valley.)
	-- the "Your Base" marker (client/BaseMarker): QM's blue house and "Your Base" floating over
	-- your own pen, only for you, until you first walk into it (BaseFound, saved)
	BaseMarker = {
		Height = 9, -- studs above the pen's floor to the marker's middle
		Size = 9, -- studs: the house's width (the text sits under it)
		Bob = 0.6, -- studs it floats up and down
		BobPeriod = 2.4, -- seconds
	},
	Rebirth = {
		Cost = 10000000,
		Growth = 3,
		StrengthBonus = 0.5,
		CashBonus = 0.5,
	},

	-- income (Server/PetInventory, Balance Oct 27): the pets in your pen pay their Cash
	-- (Config.Pets) every Every seconds, x (1 + Rebirth.CashBonus x rebirths). It's the
	-- game's main cash; bosses pay a little too (Config.Bosses' Cash).
	Income = {
		Every = 1,
	},

	-- rarities (QM's Weapon Shop Figma, Oct 27; pets use them too since Oct 30): each one's
	-- card back gradient, bottom to top (reaching the top colour `at` of the way up), and
	-- its text colour. From Mythic up they `move` (QM, Oct 27: after their Pickaxe Shop's
	-- Divine, Cosmic, Celestial, Void and Omega cards): a card's back turns with a sheen
	-- across it, and a band of `text2` sweeps across the rarity's name (Shared/RarityLook
	-- paints and animates the text). Common is white to grey with a grey outline.
	-- (QM, Oct 31: every other colour here is at full saturation, no white or pastel stops;
	-- a gradient's two ends differ only in hue, so keep it that way when tuning.)
	Rarities = {
		Common = { text = Color3.new(1, 1, 1), text2 = Color3.fromRGB(135, 135, 135), stroke = Color3.fromRGB(70, 70, 70) },
		Uncommon = { bottom = Color3.fromHex("40ff00"), top = Color3.fromHex("c8ff00"), at = 0.736, text = Color3.fromHex("00ff00") },
		Rare = { bottom = Color3.fromHex("0070ff"), top = Color3.fromHex("00e6ff"), at = 1, text = Color3.fromHex("00b7ff") },
		Epic = { bottom = Color3.fromHex("9000ff"), top = Color3.fromHex("ff00f0"), at = 1, text = Color3.fromHex("d300ff") },
		Legendary = { bottom = Color3.fromHex("ff0020"), top = Color3.fromHex("ff8c00"), at = 1, text = Color3.fromHex("ff0004") },
		Mythic = { bottom = Color3.fromHex("ff0040"), top = Color3.fromHex("ff00c0"), at = 1, text = Color3.fromHex("ff0050"), text2 = Color3.fromHex("ff00d0"), move = true },
		Divine = { bottom = Color3.fromHex("6a00ff"), top = Color3.fromHex("00d0ff"), at = 1, text = Color3.fromHex("00dcff"), text2 = Color3.fromHex("0040ff"), move = true },
		Celestial = { bottom = Color3.fromHex("ff6a00"), top = Color3.fromHex("ffe600"), at = 1, text = Color3.fromHex("ffd000"), text2 = Color3.fromHex("ff5a00"), move = true },
		Cosmic = { bottom = Color3.fromHex("3000ff"), top = Color3.fromHex("ff00e0"), at = 1, text = Color3.fromHex("d000ff"), text2 = Color3.fromHex("3000ff"), move = true },
		Void = { bottom = Color3.fromHex("3a00b0"), top = Color3.fromHex("a000ff"), at = 1, text = Color3.fromHex("5a00ff"), text2 = Color3.fromHex("22009a"), move = true },
		Omega = { bottom = Color3.fromHex("00ff40"), top = Color3.fromHex("ffee00"), at = 1, text = Color3.fromHex("7dff00"), text2 = Color3.fromHex("00ffb0"), move = true },
	},

	-- the Index (QM, Oct 30: client/IndexPanel, Server/PetIndex): every pet, a section per
	-- biome in Order (its egg's kinds, Config.Eggs.Kinds, plus Extra), "???" until you've
	-- owned one (player attribute PetIndex, kept through rebirths). Each pet you find has a
	-- reward to claim once (IndexClaimed): CashSeconds of its cash a second and Power (Strength)
	-- by its rarity. (Placeholder numbers.)
	Index = {
		Order = { "Meadow", "Desert", "Ice", "Lava", "Dungeon", "Castle", "Forest", "Ocean" },
		Extra = { Meadow = { "Horse" } }, -- (pets no egg lays: the starter)
		CashSeconds = 60,
		Power = {
			Common = 20, Uncommon = 40, Rare = 80, Epic = 150, Legendary = 300, Mythic = 600,
			Divine = 1200, Celestial = 2500, Cosmic = 5000, Void = 10000, Omega = 20000,
		},
		-- each biome's picture's colour, under its Studio screenshot (client/HudImages
		-- Biome<Name>) and in place of it until that's uploaded
		Tint = {
			Meadow = Color3.fromRGB(42, 186, 0), Desert = Color3.fromRGB(226, 148, 0),
			Ice = Color3.fromRGB(0, 163, 245), Lava = Color3.fromRGB(230, 69, 0),
			Dungeon = Color3.fromRGB(0, 0, 110), Castle = Color3.fromRGB(180, 0, 13),
			Forest = Color3.fromRGB(110, 0, 220), Ocean = Color3.fromRGB(0, 61, 170),
		},
	},

	-- the Backpack (QM, Oct 25: client/Backpack, Server/PetInventory): the pets you own
	-- and the weapons bosses dropped you, duplicates stacked ("x5"). Pets you equip wander
	-- in your pen, up to PenSlots of them; the weapon you equip is the one you hold.
	Backpack = {
		PenSlots = 5, -- (QM, Oct 26: the Backpack's Pets tab has five)
		-- the pet a new player owns and rides (QM, Oct 27: the pet you ride is one of your
		-- pen's pets; Server/PetInventory). It still pays its Cash a second while ridden.
		Starter = "Horse",
		-- the Active Pets popup's "+1 Equip" (QM's Figma, Oct 27; client/PetsPanel): one more
		-- pen slot for Robux, for good, as many times as they like (Server/Store, saved ExtraSlots).
		SlotRobux = 30,
		SlotProduct = 3724544159,
	},

	-- hatching (QM, Oct 25, LassoAPet's; Oct 27: all of it LassoAPet's 1:1, client/PenEggs):
	-- a stolen egg is yours at once, in the hotbar right of the Backpack button (player
	-- attribute EggBag; lost when you die). Click it to hold it instead of your weapon,
	-- click in your pen to put it down; it grows from 1x to GrowScale x while it waits its
	-- Time (seconds, LassoAPet's PetHatchTime; Default for one not listed), then stand by
	-- it and hold F to hatch it: its top pops off and the pet jumps out onto the spot, into
	-- your Backpack and pen (Server/Hatchery).
	Hatch = {
		-- the Growing Eggs popup's GROW ALL (QM's Figma, Oct 27; client/EggsPanel): every egg
		-- in your pen ready at once, for Robux. Not sold yet: no developer product or server side.
		GrowAllProduct = nil,
		PenEggs = 8, -- most eggs waiting in a pen at once
		Range = 10, -- studs from an egg you can hatch it (LassoAPet's SpeedupEgg.Range)
		HoldTime = 0.35, -- seconds holding F
		Edge = 2, -- studs an egg is kept from the pen's sides
		GrowScale = 2, -- a placed egg grows from 1x to this by the time it's ready (LassoAPet's EggGrowScale)
		SizePerTier = 1.5, -- an egg is this x bigger per size tier of its pet (LassoAPet's EggSizePerTier)
		TopPops = 1.58, -- seconds into the hatch when the top flies off and the pet jumps out
		JumpTime = 0.6, -- seconds the pet takes to jump out onto the spot
		JumpHeight = 5, -- studs it goes up on the way
		Default = 15,
		Time = {
			Horse = 15, Pinto = 15, Pig = 15, Bunny = 15, Fish = 45, Rhino = 120, Unicorn = 3600, -- Meadow
			Cactus = 15, Scorpion = 60, Sandworm = 75, SpineLizard = 90, Snake = 7200, -- Desert
			Penguin = 15, Boar = 15, Snowman = 60, IceGolem = 300, Icebringer = 7200, SnackYak = 3600, -- Tundra
			Firebird = 15, RockHog = 60, FireLobster = 60, VolcanoTortoise = 60, Rockworm = 1200, LavaWhale = 1200, Phoenix = 43200, -- Lava (LassoAPet's Volcano)
			DungeonRat = 30, Bat = 45, Slime = 60, CaveSpider = 120, BoneSteed = 300, Mimic = 1800, BoneWyrm = 21600, -- Abandoned Dungeon
			Shroom = 30, SpiritFox = 60, SpiritDeer = 120, AncientTreant = 300, MysticOwl = 1200, CrystalTortoise = 2400, SpiritLoong = 21600, -- Magic Circle
			WarBoar = 60, RoyalSteed = 90, ChessKnight = 300, RoyalPeacock = 600, LivingArmor = 2400, CrimsonDrake = 3600, RoyalEagle = 43200, -- Red Castle
			Squid = 60, Seahorse = 120, KingCrab = 600, FishSchool = 900, Whale = 3600, AbyssWhale = 43200, -- Ocean Trench
		},
	},

	-- pets (QM, Oct 25: LassoAPet's, with their rarity, cash a second and egg odds). The
	-- pet you ride is all your health and speed (Shared/Pets works them out, PetStats
	-- below); its name shows over you in its rarity's colours (Rarities above).
	-- Rarity climbs with the biome (QM, Oct 30): each biome's pets keep LassoAPet's order
	-- (Uncommon, Rare, Epic, Legendary there) but start higher the further in it is, so the
	-- Meadow's best is Epic and the Lava Valley's Celestial:
	--   Meadow  Common .. Epic        (LassoAPet's one tier down; the Rhino Rare, the Unicorn Epic)
	--   Desert  Rare .. Mythic        (one tier up)
	--   Tundra  Epic .. Divine        (two up)
	--   Lava    Legendary .. Celestial (three up)
	--   Abandoned Dungeon, Magic Circle   Mythic .. Cosmic (the fork's first biomes)
	--   Red Castle, Ocean Trench          Divine .. Void   (its last)
	--   Rarity  its rarity
	--   Cash    cash a second it earns in your pen (LassoAPet's PetIncome, the Tundra's
	--           after its income curve; the Lava's on tools/balance_sim.py's curve, as
	--           LassoAPet's Volcano came after its Ocean; the later biomes' about 4x per biome
	--           on from there; Config.Income)
	--   Tier    its size tier (LassoAPet's PetTiers): 1 reads as big as the Horse, each
	--           tier PetStats.TierGrowth x bigger (and x AnimalScale, top of the file)
	--   Lean    -1 (quick and fragile) to 1 (slow and tough), traded at PetStats.Lean
	--           (a guess from how fast each ran in LassoAPet)
	--   Regen   (optional) x its regen (PetStats.Regen)
	Pets = {
		Horse = { Rarity = "Common", Cash = 3, Tier = 1, Lean = 0, Speed = 1 },
		-- Meadow
		Pig = { Rarity = "Common", Cash = 9, Tier = 1, Lean = 0.5, Speed = 0.8 },
		Bunny = { Rarity = "Common", Cash = 12, Tier = 1, Lean = -0.6, Speed = 1.2 },
		Pinto = { Rarity = "Common", Cash = 15, Tier = 1, Lean = -0.2, Speed = 1.1 },
		Fish = { Rarity = "Uncommon", Cash = 24, Tier = 1, Lean = 0.6, Speed = 0.6 },
		Rhino = { Rarity = "Rare", Cash = 90, Tier = 2, Lean = 0.6, Speed = 1.35 },
		Unicorn = { Rarity = "Epic", Cash = 450, Tier = 2, Lean = -0.4, Speed = 1.8 },
		-- Desert
		Cactus = { Rarity = "Rare", Cash = 18, Tier = 1, Lean = 0.2, Speed = 1.31 },
		Scorpion = { Rarity = "Epic", Cash = 60, Tier = 1, Lean = 0, Speed = 1.77 },
		Sandworm = { Rarity = "Legendary", Cash = 180, Tier = 2, Lean = 0.5, Speed = 1.7 },
		SpineLizard = { Rarity = "Legendary", Cash = 240, Tier = 2, Lean = -0.5, Speed = 1.97 },
		Snake = { Rarity = "Mythic", Cash = 750, Tier = 3, Lean = -0.3, Speed = 2.8 },
		-- Tundra
		Penguin = { Rarity = "Epic", Cash = 45, Tier = 1, Lean = 0.3, Speed = 2.355 },
		Boar = { Rarity = "Epic", Cash = 91, Tier = 1, Lean = -0.2, Speed = 2.517 },
		Snowman = { Rarity = "Legendary", Cash = 180, Tier = 1, Lean = 0.4, Speed = 2.678 },
		IceGolem = { Rarity = "Mythic", Cash = 760, Tier = 2, Lean = 0.4, Speed = 2.86 },
		SnackYak = { Rarity = "Mythic", Cash = 9000, Tier = 2, Lean = 0.5, Speed = 3 }, -- (a Robux pet in LassoAPet: in no egg)
		Icebringer = { Rarity = "Divine", Cash = 2000, Tier = 3, Lean = 0.2, Speed = 3.8 },
		-- Lava (LassoAPet's Volcano)
		Firebird = { Rarity = "Legendary", Cash = 300, Tier = 2, Lean = -0.4, Speed = 5.11 },
		RockHog = { Rarity = "Mythic", Cash = 600, Tier = 2, Lean = 0.3, Speed = 6.56 },
		FireLobster = { Rarity = "Mythic", Cash = 650, Tier = 2, Lean = 0.4, Speed = 6.43 },
		VolcanoTortoise = { Rarity = "Mythic", Cash = 800, Tier = 2, Lean = 0.8, Speed = 6.17 },
		Rockworm = { Rarity = "Divine", Cash = 1800, Tier = 2, Lean = 0.3, Speed = 7.12 },
		LavaWhale = { Rarity = "Divine", Cash = 4500, Tier = 4, Lean = 0.7, Speed = 6.83 },
		Phoenix = { Rarity = "Celestial", Cash = 12000, Tier = 3, Lean = -0.3, Speed = 7.2 },
		-- Abandoned Dungeon (tools/later_pets.py; QM, Oct 30: new pets for the later biomes)
		DungeonRat = { Rarity = "Mythic", Cash = 1500, Tier = 2, Lean = -0.4, Speed = 7.6 },
		Bat = { Rarity = "Mythic", Cash = 1900, Tier = 1, Lean = -0.6, Speed = 7.8 }, -- (LassoAPet's Halloween Bat, QM Oct 30; its meshes are the Blood Bat boss's, tools/animal_meshes.luau)
		Slime = { Rarity = "Mythic", Cash = 2400, Tier = 2, Lean = 0.6, Speed = 7.2 },
		CaveSpider = { Rarity = "Divine", Cash = 5000, Tier = 2, Lean = -0.5, Speed = 8.2 },
		BoneSteed = { Rarity = "Divine", Cash = 7000, Tier = 2, Lean = -0.2, Speed = 8 },
		Mimic = { Rarity = "Celestial", Cash = 16000, Tier = 2, Lean = 0.6, Speed = 7.4 },
		BoneWyrm = { Rarity = "Cosmic", Cash = 60000, Tier = 2, Lean = 0.3, Speed = 8.6 },
		-- Magic Circle
		Shroom = { Rarity = "Mythic", Cash = 1500, Tier = 2, Lean = 0.4, Speed = 7.2 },
		SpiritFox = { Rarity = "Mythic", Cash = 2400, Tier = 2, Lean = -0.6, Speed = 8.2 },
		SpiritDeer = { Rarity = "Divine", Cash = 5000, Tier = 2, Lean = -0.5, Speed = 8.4 },
		AncientTreant = { Rarity = "Divine", Cash = 7000, Tier = 2, Lean = 0.6, Speed = 7.4 }, -- (LassoAPet's, for the Treant: QM; its meshes in ReplicatedStorage.AnimalMeshes, tools/animal_meshes.luau)
		MysticOwl = { Rarity = "Celestial", Cash = 14000, Tier = 2, Lean = -0.2, Speed = 7.6 },
		CrystalTortoise = { Rarity = "Celestial", Cash = 18000, Tier = 2, Lean = 0.8, Speed = 7.2 },
		SpiritLoong = { Rarity = "Cosmic", Cash = 60000, Tier = 3, Lean = -0.3, Speed = 8.6 },
		-- Red Castle
		WarBoar = { Rarity = "Divine", Cash = 8000, Tier = 2, Lean = 0.5, Speed = 8.4 },
		RoyalSteed = { Rarity = "Divine", Cash = 12000, Tier = 2, Lean = -0.3, Speed = 9.2 },
		ChessKnight = { Rarity = "Celestial", Cash = 25000, Tier = 2, Lean = 0.2, Speed = 8.6 },
		RoyalPeacock = { Rarity = "Celestial", Cash = 32000, Tier = 2, Lean = -0.4, Speed = 8.8 },
		LivingArmor = { Rarity = "Cosmic", Cash = 70000, Tier = 3, Lean = 0.8, Speed = 8.6 },
		CrimsonDrake = { Rarity = "Cosmic", Cash = 100000, Tier = 3, Lean = 0, Speed = 9.4 },
		RoyalEagle = { Rarity = "Void", Cash = 300000, Tier = 3, Lean = -0.4, Speed = 10 },
		-- Ocean Trench
		Squid = { Rarity = "Divine", Cash = 8000, Tier = 2, Lean = 0.2, Speed = 8.4 }, -- (the Squid, Fish School and Whale: LassoAPet's, QM's picks)
		Seahorse = { Rarity = "Divine", Cash = 12000, Tier = 2, Lean = -0.3, Speed = 8.8 },
		KingCrab = { Rarity = "Celestial", Cash = 25000, Tier = 2, Lean = 0.6, Speed = 8.6 },
		FishSchool = { Rarity = "Celestial", Cash = 35000, Tier = 2, Lean = -0.4, Speed = 9.6 },
		Whale = { Rarity = "Cosmic", Cash = 90000, Tier = 3, Lean = 0.7, Speed = 9 },
		AbyssWhale = { Rarity = "Void", Cash = 300000, Tier = 4, Lean = 0.7, Speed = 9.4 },
	},
	-- a pet's health and speed (Shared/Pets): set by its rarity (QM, Oct 25: mostly a status
	-- signal; since Oct 30 rarity climbs with the biome, so later pets get a little tougher).
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
			Divine = { Health = 230, Speed = 34 },
			Celestial = { Health = 260, Speed = 35.5 },
			Cosmic = { Health = 290, Speed = 37 },
			Void = { Health = 320, Speed = 38.5 },
			Omega = { Health = 350, Speed = 40 },
		},
		Lean = 0.25, -- Lean 1: +25% health, -25% speed (Lean -1 the other way)
		-- Regen (QM, Oct 30: pets set health and regen separately): health a second, Rate x
		-- its rarity's Health, x (1 - its Lean x RegenLean) (the quick, fragile ones heal
		-- faster: a Unicorn about twice a Rhino), x its own Regen in Config.Pets if it has one
		Regen = { Rate = 0.025, RegenLean = 0.5 },
		-- Speed (QM, Oct 26): each pet's own, LassoAPet's: MountSpeed studs/s x its Speed in
		-- Config.Pets (Lasso's AnimalStats Speed; its horse rides at 44). This replaces the
		-- rarity's Speed and the Lean's speed half; a pet without a Speed keeps those.
		MountSpeed = 44,
		-- Past the Horse's 1 the curve is logarithmic (QM, Oct 30): MountSpeed + k x ln(Speed),
		-- k set so the fastest Speed in Config.Pets (TopSpeed, the Royal Eagle's 10) rides at
		-- MaxSpeed studs/s; nothing rides faster (before the sprint). Pets under 1 stay
		-- MountSpeed x Speed. Horse 44, Unicorn 84, Snake 114, Icebringer 134, Phoenix 178.
		MaxSpeed = 200,
		TopSpeed = 10,
		Hitbox = 0.5, -- 0: size doesn't matter; 1: twice the hitbox, twice the health
		TierGrowth = 1.6, -- each size tier reads this much bigger than the one below (LassoAPet's)
		SmallSize = 10.4, -- studs a tier 1 pet reads (LassoAPet's PetSmallSize: the Horse at 1x its drawing)
	},

	-- Sprint (QM, Oct 26; client/Sprint): ride Delay seconds without stopping and your pet
	-- builds up to a sprint, Speed x its speed, over Ramp seconds. Stopping (letting go of
	-- the controls, or held up against something: under StopAt of your speed) drops you
	-- straight back. LassoAPet's sprint is 2x; this game's is 1.3x (QM).
	Sprint = { On = true, Speed = 1.3, Delay = 1.5, Ramp = 1.2, StopAt = 0.4 },
	-- Steering (QM, Oct 30: riding felt drifty; client/Riding): on the ground you go exactly
	-- where you push at full speed and stop dead, turning to face it at Turn (a rate: 30 is
	-- all but instant, lower is smoother).
	Steer = { On = true, Turn = 30 },
	-- Hopping (QM, Oct 30; client/Hop): riding into something solid up to Height studs tall
	-- (a fence: 4) within Ahead studs past your pet's hitbox, it hops over, Clear studs
	-- higher than it, with Push studs/s more forward. Taller walls stop you as before.
	Hop = { On = true, Height = 6, Ahead = 1.5, Clear = 1.5, Push = 6 },
	-- Sprint abilities (QM, Oct 30; client/SprintAbility draws them, Server/SprintAbility
	-- runs them): these pets' sprint is a special move instead. It starts once, the moment
	-- you've ridden Sprint.Delay seconds without stopping (whatever your speed), with the
	-- camera bounce, the sky flash and the tier-up whoosh (no other pet gets those any
	-- more: QM), and lasts till you stop.
	--   Burrow  under the floor: nothing can hit you (LassoAPet's Sandworm: its sand
	--           mounds and dirt spray, in Sand / Sand2)
	--   Fly     Height studs up, rising over Rise seconds: melee, bombs, slams and plain
	--           shots all miss you; only homing magic (a Magic shot with Homing) still hits
	--   Smash   Grow x bigger, a white outline and LassoAPet's charge wind (the Rhino's), a
	--           charge that builds (QM, Oct 30): over Ramp seconds of charging you speed up
	--           to MaxSpeed x your sprint, and running into an enemy hits it for Damage x
	--           your slash's damage at the start up to MaxDamage x at the full Ramp. It knocks
	--           it Knockback studs back over KnockTime seconds (a boss BossKnock x that),
	--           and ends the sprint (another Sprint.Delay of riding to start it again)
	--   Bombs   an orange outline, and a bomb dropped every Every seconds: each goes
	--           off Fuse seconds later, hitting every enemy within Radius for Damage x your
	--           slash's damage (orange and yellow in turn)
	--   Crabwalk  a Smash, scuttling sideways (the model turned Turn degrees; LassoAPet's
	--           King Crab), its charge wind breaking round its side
	--   Leap    LassoAPet's Unicorn leap: it walks up Steps steps of thin air, StepTime
	--           seconds each, to Height studs, trailing its Trail colours (the rainbow);
	--           once the sprint stops it drops back down (Gravity studs/s², like a boss's
	--           minions out of the sky). Up there it dodges like a flier.
	--   Glow    LassoAPet's Snake rattle: its horns and spikes glow, and you heal Regen x
	--           your pet's regen (Server/Regen)
	--   Frost   LassoAPet's Icebringer blizzard round it: a boss's minion that comes
	--           within Radius studs is frozen solid for Freeze seconds (no moving, no
	--           biting), then can't be frozen again for Again seconds
	SprintPets = {
		Sandworm = "Burrow",
		Rockworm = "Burrow", -- (the Sandworm's recolour)
		Firebird = "Fly",
		Phoenix = "Fly",
		MysticOwl = "Fly",
		SpiritLoong = "Fly",
		CrimsonDrake = "Fly",
		RoyalEagle = "Fly",
		BoneWyrm = "Burrow", -- (QM, Oct 30: like the Sandworm)
		Bat = "Fly",
		Unicorn = "Leap",
		BoneSteed = "Leap", -- (its trail in bone and ghost-fire colours)
		Snake = "Glow",
		Icebringer = "Frost",
		KingCrab = "Crabwalk",
		Rhino = "Smash",
		Boar = "Smash", -- (QM, Oct 30: every boar charges)
		RockHog = "Smash",
		WarBoar = "Smash",
		LavaWhale = "Smash", -- (a whale like the Whale and Abyss Whale)
		Whale = "Smash",
		AbyssWhale = "Smash",
		VolcanoTortoise = "Bombs",
	},
	SprintAbility = {
		Burrow = {
			-- (the Sandworm's the Sandworm boss's sand; the Rockworm's dark rock)
			Sand = { Sandworm = Color3.fromRGB(226, 190, 128), Rockworm = Color3.fromRGB(90, 70, 65), BoneWyrm = Color3.fromRGB(110, 100, 95) },
			Sand2 = { Sandworm = Color3.fromRGB(196, 156, 96), Rockworm = Color3.fromRGB(60, 45, 45), BoneWyrm = Color3.fromRGB(75, 68, 66) },
			Mound = 1.3, -- x LassoAPet's mounds
		},
		Fly = { Height = 10, Rise = 0.4 },
		Smash = {
			Grow = 1.2,
			Outline = Color3.fromRGB(255, 255, 255),
			Damage = 2,
			MaxDamage = 8,
			Ramp = 3,
			MaxSpeed = 1.6,
			Reach = 2, -- studs past the two bodies' edges that still count as running into it
			Knockback = 18,
			KnockTime = 0.3,
			BossKnock = 0.5,
		},
		Crabwalk = { Turn = 90 }, -- (its hits, outline and growing: Smash's)
		Leap = {
			Height = 9,
			Steps = 3,
			StepTime = 0.22,
			Gravity = 160,
			Trail = {
				Unicorn = { -- (LassoAPet's rainbow)
					Color3.fromRGB(255, 70, 70),
					Color3.fromRGB(255, 160, 50),
					Color3.fromRGB(255, 235, 70),
					Color3.fromRGB(80, 220, 90),
					Color3.fromRGB(70, 150, 255),
					Color3.fromRGB(170, 90, 240),
				},
				BoneSteed = { -- (bone, then ghost fire)
					Color3.fromRGB(235, 228, 205),
					Color3.fromRGB(150, 255, 190),
					Color3.fromRGB(70, 210, 170),
					Color3.fromRGB(120, 90, 220),
					Color3.fromRGB(70, 40, 130),
				},
			},
		},
		Glow = { Regen = 2, Color = Color3.fromRGB(48, 196, 214) }, -- (Color: the parts that glow, the Snake's horns and spikes)
		Frost = { Radius = 30, Freeze = 0.5, Again = 1 },
		Bombs = {
			Outline = Color3.fromRGB(255, 140, 30),
			Every = 0.15, -- (it runs about 200 studs/s: one every ~30 studs)
			Fuse = 0.9,
			Radius = 8,
			Damage = 1,
		},
	},
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
	-- horse's sprint, between MinScale and MaxScale. A SprintPets pet's sprint starting
	-- bounces the camera's distance: in to Bounce.In x, out to Bounce.Out x, then settling.
	SprintCam = { On = true, Fov = 95, Zoom = 0.75, InTime = 0.3, OutTime = 0.5, MinScale = 0.5, MaxScale = 1.8, Bounce = { In = 0.7, InTime = 0.1, Out = 1.2, OutTime = 0.15, SettleTime = 0.4 } },
	-- Sprint tiers, in horse's sprints (LassoAPet's 180, 360 and 440 studs/s over its horse's
	-- 88). Breaking into one used to bounce the camera, flash the sky and play the tier-up
	-- whoosh; QM, Oct 30: no more (only a SprintPets pet's sprint does that, once). They're
	-- unused now.
	SprintTiers = { 2.05, 4.1, 5 },
	-- A white trail off you while you sprint (client/SprintTrail): Life seconds long at a
	-- horse's sprint, longer the faster you go, up to MaxLife.
	SprintTrail = { On = false, Life = 0.12, MaxLife = 0.6, Transparency = 0.55 }, -- (off: QM, Oct 27)
	-- The sky flashes white as a SprintPets pet's sprint starts, fading back over Time seconds
	-- (client/SkyFlash). Start: its see-through at the flash. Distance: studs round the camera.
	SkyFlash = { On = true, Time = 0.8, Start = 0, Distance = 1000 },
	-- workspace.SkyColor's colours for a place that has none yet (Shared/SkyColor, QM Oct 31):
	-- the fog/sky colour in each area, blended over TweenTime seconds as you walk in
	SkyColor = {
		TweenTime = 1.5,
		Base = Color3.fromRGB(71, 125, 166), -- (QM's steel blue fog, as before)
		Meadow = Color3.fromRGB(96, 170, 222),
		Desert = Color3.fromRGB(222, 178, 120),
		Ice = Color3.fromRGB(176, 210, 234),
		Lava = Color3.fromRGB(128, 48, 36),
		Dungeon = Color3.fromRGB(44, 54, 74),
		Castle = Color3.fromRGB(96, 32, 54),
		Forest = Color3.fromRGB(112, 74, 156),
		Ocean = Color3.fromRGB(24, 74, 126),
	},

	-- regions (QM, Oct 25): each biome past the Meadow is bought with cash. Until you own
	-- it, its gate shows a blocker only you see (client/Regions: a navy wall with its name,
	-- price and a Buy button, and its shadow on the floor); Server/Regions sells it and
	-- Server/Data saves it (Region<Name>). A rebirth locks them again, like the training
	-- grounds. Balance (Oct 27): a full pen of a biome's pets (Config.Income) pays for the
	-- next one in about 5, 10 and 25 minutes, after a few weapons; past the Lava Valley they're
	-- placeholders until those biomes have pets.
	Regions = {
		Cost = {
			Meadow = 0,
			Desert = 6000,
			Ice = 120000,
			Lava = 1500000,
			Dungeon = 20000000,
			Forest = 20000000,
			Castle = 250000000,
			Ocean = 250000000,
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

	-- training (Server/Training, Server/Combat): Strength comes from attacking. Every hit
	-- trains the damage it dealt x the enemy's Strength x PerDamage (QM, Oct 25), so it
	-- grows with your damage, and your damage grows with it on Config.Power's log curve.
	-- The training grounds, one per biome, are regions off the base (QM, Oct 30: Ice and
	-- Meadow west, Lava and Desert east, joined to it by corridors), each shut by a blocker
	-- like a boss region's until bought with cash (a rebirth will lock them again); their
	-- mobs roam the region and come back Respawn seconds after they fall, for AFK training
	-- (RuneScape's sand crabs).
	-- Balance (Oct 27): each ground costs a little more than its biome's region, so you buy it
	-- once that biome's pets are paying. A mob's Health is about 4 seconds of swinging for the
	-- weapon and Strength you'd have then (Meadow ~100 a second, Desert ~300, Tundra ~1,300,
	-- Lava ~4,500), and its bites are about 60% of its boss's hit every 1.5s.
	-- (Strength grows into the millions by the Lava Valley: Config.Power's log curve keeps
	-- what it does in check.)
	-- Mobs fight back (QM, Oct 26): hit one and it turns on you, follows you round its yard
	-- at Chase x its Speed and swipes with its Attacks (Server/BossAttacks' Swipe, like
	-- the bosses), until you've left its region, died, or not hit it for Calm seconds. They
	-- hit for real (QM, Oct 26), about 40% of their biome boss's damage a second, and can
	-- kill you (your pet's regen keeps healing you meanwhile: Server/Regen).
	-- Each mob is a random pet from its biome's eggs (Config.Eggs.Kinds, any with odds; QM,
	-- Oct 26), drawn at the pet's own size; Mob and Size are only for a ground whose eggs
	-- are still the Horse placeholder. Pet (and Name) put one pet in a ground instead: the
	-- Desert's cactus monsters (QM, Oct 27), the Lava's Rock Hogs (the Lava Whale and the
	-- Phoenix are far too big).
	-- Count: how many roam it at once (more than the old pens held: the regions are big).
	Training = {
		PerDamage = 0.1, -- (at 0 Strength a Kendo Stick hit deals 10: Strength 2 trains 2, as before)
		Grounds = {
			-- each ground's Mobs take turns filling its Count (QM, Oct 30): Pet (its model, at
			-- Scale x its riding size), Name, Mode and Attacks (else the ground's own). Mode is
			-- how an angry one moves: Melee (default) runs at you, Range keeps Keep studs off
			-- and casts, Flee runs away from you and lobs bombs back.
			Meadow = {
				Cost = 300,
				Health = 400,
				Count = 8,
				Strength = 2,
				Speed = 4,
				Attacks = { { Kind = "Swipe", Every = 1.8, Reach = 3, Arc = 100, Damage = 8 } }, -- (boss: 10 a second)
				Mobs = { { Pet = "Pig" }, { Pet = "Fish" } },
			},
			Desert = {
				Cost = 8000,
				Health = 1500,
				Count = 10,
				Strength = 5,
				Speed = 2.5,
				Attacks = { { Kind = "Swipe", Every = 1.8, Reach = 3, Arc = 110, Damage = 13 } }, -- (boss: 16)
				Mobs = {
					{ Pet = "Cactus", Name = "Cactus Monster" },
					{
						Pet = "Scorpion",
						Mode = "Range",
						Keep = 14,
						Attacks = {
							{
								Kind = "Magic",
								Every = 2.4,
								Like = "Staff",
								Damage = 9,
								Height = 3,
								Cast = 0.3,
								Shot = { Color = Color3.fromRGB(232, 190, 116), Count = 1, Size = 1.2, Speed = 34, Homing = 40, Launch = 0, Range = 60, Slack = 0 }, -- sand
							},
						},
					},
				},
			},
			Ice = {
				Cost = 150000,
				Health = 6000,
				Count = 9,
				Strength = 15,
				Speed = 3,
				Attacks = { { Kind = "Swipe", Every = 2, Reach = 4, Arc = 140, Damage = 22 } }, -- (boss: 26)
				Mobs = {
					{ Pet = "Boar" },
					{
						Pet = "Snowman",
						Mode = "Range",
						Keep = 15,
						Attacks = {
							{
								Kind = "Magic",
								Every = 2.6,
								Like = "Staff",
								Damage = 10,
								Height = 4,
								Cast = 0.3,
								Shot = { Color = Color3.fromRGB(235, 245, 255), Count = 2, Spread = 20, Size = 1.2, Speed = 36, Homing = 30, Launch = 0, Range = 60, Slack = 0 }, -- snow
							},
						},
					},
					{
						Pet = "Penguin",
						Mode = "Flee",
						Attacks = {
							{ Kind = "Lob", Every = 3, Count = 0, Scatter = 9.5, Radius = 8, Airtime = 1.2, Height = 22.5, Damage = 22 },
						},
					},
				},
			},
			Lava = {
				Cost = 2000000,
				Health = 20000,
				Count = 10,
				Strength = 45,
				Speed = 3.5,
				Attacks = { { Kind = "Swipe", Every = 1.8, Reach = 4, Arc = 130, Damage = 32 } }, -- (boss: 40)
				Mobs = {
					{ Pet = "RockHog", Name = "Fire Boar", Scale = 0.6 }, -- (40% smaller, hitbox too: QM, Oct 30)
					{
						Pet = "Firebird",
						Mode = "Range",
						Keep = 16,
						Attacks = {
							{
								Kind = "Magic",
								Every = 2.4,
								Like = "Staff",
								Damage = 16,
								Height = 5,
								Burst = 2,
								BurstGap = 0.3,
								Cast = 0.3,
								Shot = { Color = Color3.fromRGB(255, 130, 40), Count = 1, Size = 1.3, Speed = 38, Homing = 40, Launch = 0, Range = 60, Slack = 0 }, -- fire
							},
						},
					},
				},
			},
		},
		Respawn = 4,
		Chase = 2.5, -- an angry mob moves this many times its Speed
		Calm = 8, -- seconds without being hit before it forgets you
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
		-- every hit rolls its damage between these times the base, rounded to a whole number
		-- (QM, Oct 27: no two hits the same); 1 and 1 turns it off. All weapons, not just swords
		RollMin = 0.8,
		RollMax = 1.2,
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

	-- weapons (QM, Oct 25). Bought from Carl the cactus vendor with cash (QM, Oct 27: boss
	-- drops and the spin are gone); you hold one at a time (Server/Arsenal). Three
	-- types: Melee slashes (Config.Slash with the weapon's Slash values over it), Ranged
	-- shoots straight (arrows, bolts, thrown things), Magic fires slightly homing missiles
	-- (Shared/Projectiles, client/Shots draws them). Every weapon auto-attacks like the sword.
	--   Name     shown in the shop
	--   Type     "Melee", "Ranged" or "Magic"
	--   Rarity   one of Rarities (above): its colour
	--   Damage   times your Power (Server/Combat: Slash.Damage x Shared/Power's Strength curve) per hit
	--   Price    cash Carl sells it for (nil: not for sale; the Kendo Stick is everyone's to start)
	--   Slash    (Melee) Config.Slash values to change: Arc, Radius, Forward, Width,
	--            Cooldown, AttackRange, Color, Variety...
	--   Shot     (Ranged, Magic) values over Config.Shots.Ranged or .Magic (below: every
	--            value is listed there)
	-- Every weapon's values can be tuned live in Play: hold it and edit Workspace > Weapon
	-- (client/WeaponTuning); tick PrintConfig there for its block to paste back here.
	Weapons = {
		-- QM's weapons (Oct 25). Rarity steps up every 2-3 weapons in price order (QM, Oct 27):
		-- (Balance, Oct 27: each weapon in price order is 1.3x the one before in damage a second,
		-- Damage x Count / Cooldown, from the Kendo Stick's 2 to the Genesis Staff's 1,834; prices
		-- roughly double each step, 500 to 25B, so a new biome's cash buys the next few.)
		-- Common, Uncommon, Rare, Epic, Legendary, Mythic, Divine, Celestial, Cosmic, Void
		-- and Omega (Rarities above; the last four are the endgame designs). Every Ranged one
		-- shoots the same arrow (only its numbers and trail differ); Magic ones are drawn from
		-- their numbers (client/Shots). Tune any of them live: Workspace > Weapon.
		-- (everyone's to start: Arsenal.Start, so Carl doesn't sell it)
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
			Rarity = "Uncommon",
			Damage = 1.35,
			Price = 1500,
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
			Damage = 1.2,
			Price = 500,
			Shot = { Cooldown = 0.45 },
		},
		Staff = { -- (a plain staff, no element: QM, Oct 25)
			Name = "Staff",
			Type = "Magic",
			Rarity = "Uncommon",
			Damage = 3.1,
			Price = 3500,
			Shot = {
				Speed = 60,
				Homing = 220,
				Size = 0.9,
				Color = Color3.fromRGB(49, 200, 242),
			},
		},
		Axe = {
			Name = "Axe",
			Type = "Melee",
			Rarity = "Rare",
			Damage = 5.7,
			Price = 10000,
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
			Rarity = "Epic",
			Damage = 12.5,
			Price = 100000,
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
			Rarity = "Rare",
			Damage = 2.6,
			Price = 50000,
			Shot = {
				Cooldown = 0.8,
				Count = 3,
				Spread = 16,
				TrailLength = 0.2,
				TrailTransparency = 0.6,
			},
		},
		WindStaff = {
			Name = "Wind Staff",
			Type = "Magic",
			Rarity = "Epic",
			Damage = 6.5,
			Price = 250000,
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
			Rarity = "Rare",
			Damage = 3,
			Price = 25000,
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
		WaterStaff = {
			Name = "Water Staff",
			Type = "Magic",
			Rarity = "Legendary",
			Damage = 7.4,
			Price = 500000,
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
			Rarity = "Legendary",
			Damage = 55,
			Price = 1000000,
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
			Rarity = "Legendary",
			Damage = 108,
			Price = 2000000,
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
		UnholyLance = { -- (QM's, Oct 25)
			Name = "Unholy Lance",
			Type = "Melee",
			Rarity = "Mythic",
			Damage = 21,
			Price = 4000000,
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
			Rarity = "Mythic",
			Damage = 6,
			Price = 8000000,
			Shot = {
				Cooldown = 0.2,
				Count = 2,
				Spread = 8,
				TrailColor = Color3.fromRGB(51, 255, 0),
				TrailLength = 0.3,
				TrailTransparency = 0.7,
			},
		},
		BloodBow = {
			Name = "Blood Bow",
			Type = "Ranged",
			Rarity = "Divine",
			Damage = 31.5,
			Price = 15000000,
			Shot = {
				Cooldown = 0.4,
				Pierce = 1,
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
			Rarity = "Divine",
			Damage = 82,
			Price = 30000000,
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
		-- once the Giant Rafflesia's own drop (QM cut the other boss weapons, Oct 25); Carl sells
		-- it now like the rest, at the top price (QM, Oct 27: no more drops)
		RafflesiaBloom = { -- (the Flower Staff: QM renamed it, Oct 25; the id stays for saves)
			Name = "Flower Staff",
			Type = "Magic",
			Rarity = "Celestial",
			Damage = 22,
			Price = 75000000,
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
		-- the endgame (QM, Oct 30: more tiers, enough to reach the Red Castle and Ocean Trench).
		-- Each is an original design in QM's palette (tools/weapon_designs.py) that fights like
		-- the drawn weapon it first recoloured, still 1.3x the one before in damage a second
		-- (Flower Staff's 133 up to the Genesis Staff's 1,834). Prices climb ~1.8x a step from 150M: the first two
		-- are Dungeon and Magic Circle cash, the next few Red Castle and Ocean Trench, and the
		-- Omega pair is the chase past them (placeholders).
		SunBlade = {
			Name = "Sun Blade",
			Type = "Melee",
			Rarity = "Celestial",
			Damage = 173,
			Price = 150000000,
			Slash = {
				Arc = 240,
				AttackRange = 20,
				Color = Color3.fromRGB(255, 226, 140),
				Cooldown = 1,
				Ends = 0.3,
				Fade = 0.5,
				Forward = 3.5,
				Glow = 1,
				OuterSegments = 6,
				Radius = 13,
				Recover = 1,
				Trail = 1,
			},
		},
		StarlightBow = {
			Name = "Starlight Bow",
			Type = "Ranged",
			Rarity = "Celestial",
			Damage = 60,
			Price = 250000000,
			Shot = {
				Cooldown = 0.8,
				Count = 3,
				Spread = 16,
				TrailColor = Color3.fromRGB(255, 211, 74),
				TrailLength = 0.3,
				TrailTransparency = 0.5,
			},
		},
		NebulaStaff = {
			Name = "Nebula Staff",
			Type = "Magic",
			Rarity = "Cosmic",
			Damage = 102,
			Price = 450000000,
			Shot = {
				Color = Color3.fromRGB(255, 122, 230),
				Count = 2,
				Homing = 180,
				Size = 1.2,
				Speed = 40,
				Splash = 6,
				Sparkles = 6,
			},
		},
		CometLance = {
			Name = "Comet Lance",
			Type = "Melee",
			Rarity = "Cosmic",
			Damage = 171,
			Price = 800000000,
			Slash = {
				Arc = 60,
				AttackRange = 19,
				Color = Color3.fromRGB(224, 112, 255),
				Cooldown = 0.45,
				Forward = 0,
				Glow = 1,
				InnerSegments = 1,
				Opacity = 1,
				OuterSegments = 2,
				Radius = 16,
			},
		},
		GalaxyBow = {
			Name = "Galaxy Bow",
			Type = "Ranged",
			Rarity = "Cosmic",
			Damage = 198,
			Price = 1500000000,
			Shot = {
				Cooldown = 0.4,
				Pierce = 1,
				Size = 3,
				Spread = 5,
				TrailColor = Color3.fromRGB(255, 112, 224),
				TrailLength = 0.5,
				TrailTransparency = 0.8,
			},
		},
		VoidReaver = {
			Name = "Void Reaver",
			Type = "Melee",
			Rarity = "Void",
			Damage = 1284,
			Price = 2500000000,
			Slash = {
				Arc = 300,
				AttackRange = 10,
				Color = Color3.fromRGB(155, 107, 255),
				Cooldown = 2,
				Ends = 1,
				Forward = 1,
				Glow = 1,
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
		AbyssStaff = {
			Name = "Abyss Staff",
			Type = "Magic",
			Rarity = "Void",
			Damage = 668,
			Price = 4500000000,
			Shot = {
				Color = Color3.fromRGB(110, 70, 255),
				Cooldown = 0.8,
				Homing = 170,
				Size = 2,
				SparkleSize = 1,
				Speed = 50,
				TrailLength = 1,
			},
		},
		EclipseBow = {
			Name = "Eclipse Bow",
			Type = "Ranged",
			Rarity = "Void",
			Damage = 108.5,
			Price = 8000000000,
			Shot = {
				Cooldown = 0.2,
				Count = 2,
				Spread = 8,
				TrailColor = Color3.fromRGB(122, 77, 255),
				TrailLength = 0.3,
				TrailTransparency = 0.6,
			},
		},
		Worldbreaker = {
			Name = "Worldbreaker",
			Type = "Melee",
			Rarity = "Omega",
			Damage = 4232,
			Price = 15000000000,
			Slash = {
				Arc = 140,
				AttackRange = 11,
				Belly = 0.4,
				Color = Color3.fromRGB(180, 255, 106),
				Cooldown = 3,
				Forward = 5,
				Glow = 1,
				Hold = 0.4,
				Jitter = 1,
				OuterSegments = 3,
				Pop = 1,
				Radius = 7,
				Recover = 1,
				Width = 5,
			},
		},
		GenesisStaff = {
			Name = "Genesis Staff",
			Type = "Magic",
			Rarity = "Omega",
			Damage = 734,
			Price = 25000000000,
			Shot = {
				Color = Color3.fromRGB(180, 255, 106),
				Cooldown = 0.4,
				Homing = 360,
				HomingCone = 130,
				Size = 1.1,
				Sparkles = 8,
				Speed = 120,
				TrailLength = 0.2,
			},
		},
	},
	-- weapons a player owns (Server/Arsenal). No spins, drops or merging any more (QM, Oct
	-- 27): every weapon but the starting one is bought from Carl (Config.Vendor), once.
	-- the screen UI's sounds (client/UiFx; QM, Oct 30: "find some UI/UX sfx ... to make it
	-- better"). Flat 2D, never through Sfx.play. Free Creator Store sounds; swap any id here.
	-- id, volume, speed (pitch: 1 as recorded), start (seconds in to begin from)
	UiSounds = {
		Click = { id = "rbxassetid://6895079853", volume = 0.5 }, -- UI Click: every button, as it's pressed
		Hover = { id = "rbxassetid://6895079853", volume = 0.12, speed = 1.6 }, -- the same, small and high
		Open = { id = "rbxassetid://2375539277", volume = 0.45 }, -- Pop Sound: a popup opens
		Close = { id = "rbxassetid://2198217232", volume = 0.3, speed = 1.3 }, -- whoosh: one closes
		Buy = { id = "rbxassetid://7112275565", volume = 0.45 }, -- Cash Register (Kaching)
		Claim = { id = "rbxassetid://1169755927", volume = 0.5 }, -- Coin Collect: a pet sent to storage
		Equip = { id = "rbxassetid://133331985238497", volume = 0.5 }, -- Item grab/equip 7
		Error = { id = "rbxassetid://6895079853", volume = 0.6, speed = 0.55 }, -- the click, low: can't buy
	},

	Arsenal = {
		Start = "KendoStick", -- everyone owns this one (QM, Oct 25: the Sword's gone)
	},
	-- shots (Shared/Projectiles): what Ranged and Magic weapons fire
	Shots = {
		Height = 0.8, -- above the rider's hips, like the slash
		Radius = 0.6, -- a shot's own width for hitting (studs), times its Size
		Slack = 1.5, -- studs added to every target's width for shots (QM: more forgiving; height never counts)
		Trust = 12, -- studs: how far the shooter's own spot may be from the server's (Server/Combat)
		-- no range on bows and staffs (QM, Oct 30, as in Archero): in a boss fight they shoot
		-- the nearest enemy anywhere in the arena, and a shot flies until it hits or leaves the
		-- arena. Outside a fight (training yards) they reach this far instead
		Reach = 90, -- studs
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
			Range = 400, -- studs it flies at most: only a cleanup cap now (QM, Oct 30: no range, like Archero)
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
			Range = 400, -- (a cleanup cap, as for bows)
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
