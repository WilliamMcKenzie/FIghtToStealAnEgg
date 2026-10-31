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
	CashStack = "rbxassetid://109204892225012", -- assets/ui/shop/CashStack.png
	CashStackFlip = "rbxassetid://115708546699708", -- assets/ui/shop/CashStackFlip.png (mirrored: Roblox can't flip an image)
	CashBills = "rbxassetid://82388402206576", -- assets/ui/shop/CashBills.png
	ShopSword = "rbxassetid://123356988454404", -- assets/ui/shop/ShopSword.png
	ShopSwordFlip = "rbxassetid://83681064036819", -- assets/ui/shop/ShopSwordFlip.png
	PassLife = "rbxassetid://82975673131375", -- assets/ui/shop/PassLife.png
	PassGrowth = "rbxassetid://114174541072022", -- assets/ui/shop/PassGrowth.png
	GiftIcon = "rbxassetid://128507687375224", -- assets/ui/shop/GiftIcon.png
	Sunburst = "rbxassetid://77681254888649", -- assets/ui/shop/Sunburst.png
	StudTile = "rbxassetid://100359261064701", -- assets/ui/StudTile.png (QM's Figma stud texture)
	WeldTile = "rbxassetid://94674059514917", -- assets/ui/WeldTile.png (QM's Figma weld texture)
	BossAliveIcon = "rbxassetid://136700539456694", -- assets/ui/hud/BossAliveIcon.png
	BossDeadIcon = "rbxassetid://108102901826020", -- assets/ui/hud/BossDeadIcon.png
	BossGlow = "rbxassetid://136536336593533", -- assets/ui/hud/BossGlow.png
	BaseHouse = "", -- assets/ui/hud/BaseHouse.png (QM's blue house over your pen: client/BaseMarker)
	-- the Index (client/IndexPanel): the pet stats' icons (QM's icon pack: assets/ui/index) and
	-- each biome's picture, a screenshot of it from Studio (Biome<Name>; its Config.Index.Tint
	-- shows until it's in)
	HealthIcon = "rbxassetid://99839625403183", -- assets/ui/index/HealthIcon.png
	RegenIcon = "rbxassetid://112079382579969", -- assets/ui/index/RegenIcon.png
	SpeedIcon = "rbxassetid://122906677557167", -- assets/ui/index/SpeedIcon.png
	BiomeMeadow = "rbxassetid://139337197595520",
	BiomeDesert = "rbxassetid://97315736124697",
	BiomeIce = "rbxassetid://124244390098510",
	BiomeLava = "rbxassetid://111108179475916",
	BiomeDungeon = "rbxassetid://132962071166702",
	BiomeCastle = "rbxassetid://97026154183303",
	BiomeForest = "rbxassetid://133300550274882",
	BiomeOcean = "rbxassetid://102204872903218",
	-- the banners that sweep across the top (client/Banner, QM Oct 31): QM's 2587 x 113 art
	-- in thirds (an upload's at most 1024 wide), assets/ui/banner/<Name>1-3.png. The
	-- tutorial's on PromptBanner, "Boss Defeated!" on BossBanner; a plain red band shows
	-- till they're uploaded.
	PromptBanner1 = "rbxassetid://94058909154953",
	PromptBanner2 = "rbxassetid://119576300026393",
	PromptBanner3 = "rbxassetid://118436197826900",
	BossBanner1 = "rbxassetid://94486153125848",
	BossBanner2 = "rbxassetid://99661704347673",
	BossBanner3 = "rbxassetid://135693206047238",
}
