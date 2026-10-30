-- The HUD's images by name: QM's NewUI Figma icons, exported to assets/ui/hud (and the Robux
-- icon to assets/ui/shop). Everything flat is built natively (client/HudKit). Empty until
-- they're uploaded (tools/studio/imgup.py); each one shows blank until then.
return {
	ShopIcon = "rbxassetid://130215760984830",
	IndexIcon = "rbxassetid://75800289775667",
	EggsIcon = "rbxassetid://136976238742516",
	PetsIcon = "rbxassetid://135122637332207",
	PowerIcon = "rbxassetid://123860946510182",
	CashIcon = "rbxassetid://102450910988008",
	PowerGainIcon = "rbxassetid://124462507147384", -- assets/ui/hud/PowerGainIcon.png (the gain popups': client/GainPopups)
	CashGainIcon = "rbxassetid://96406134533444", -- assets/ui/hud/CashGainIcon.png
	RobuxIcon = "rbxassetid://86362799525767",
	-- the Shop's (client/Shop; assets/ui/shop): QM's Figma cash icons, a sword and pass
	-- pictures from his icon pack, the gift icon and the sunburst behind every card
	CashStack = "", -- assets/ui/shop/CashStack.png
	CashStackFlip = "", -- assets/ui/shop/CashStackFlip.png (mirrored: Roblox can't flip an image)
	CashBills = "", -- assets/ui/shop/CashBills.png
	ShopSword = "", -- assets/ui/shop/ShopSword.png
	ShopSwordFlip = "", -- assets/ui/shop/ShopSwordFlip.png
	PassLife = "", -- assets/ui/shop/PassLife.png
	PassGrowth = "", -- assets/ui/shop/PassGrowth.png
	GiftIcon = "", -- assets/ui/shop/GiftIcon.png
	Sunburst = "", -- assets/ui/shop/Sunburst.png
	StudTile = "rbxassetid://100359261064701", -- assets/ui/StudTile.png (QM's Figma stud texture)
	WeldTile = "rbxassetid://94674059514917", -- assets/ui/WeldTile.png (QM's Figma weld texture)
	BossAliveIcon = "rbxassetid://136700539456694", -- assets/ui/hud/BossAliveIcon.png
	BossDeadIcon = "rbxassetid://108102901826020", -- assets/ui/hud/BossDeadIcon.png
	BossGlow = "rbxassetid://136536336593533", -- assets/ui/hud/BossGlow.png
	-- the Index (client/IndexPanel): the pet stats' icons (QM's icon pack: assets/ui/index) and
	-- each biome's picture, a screenshot of it from Studio (Biome<Name>; its Config.Index.Tint
	-- shows until it's in)
	HealthIcon = "", -- assets/ui/index/HealthIcon.png
	RegenIcon = "", -- assets/ui/index/RegenIcon.png
	SpeedIcon = "", -- assets/ui/index/SpeedIcon.png
	BiomeMeadow = "",
	BiomeDesert = "",
	BiomeIce = "",
	BiomeLava = "",
	BiomeDungeon = "",
	BiomeCastle = "",
	BiomeForest = "",
	BiomeOcean = "",
}
