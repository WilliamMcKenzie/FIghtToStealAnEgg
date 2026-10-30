-- SpiritLoong: The Loong as the Magic Circle's spirit dragon: pearl white with a
-- turquoise mane and whiskers, violet bands and spines, and glowing eyes.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local SpiritLoongModel = require(script.Parent.SpiritLoongModel)

return Horse.variant("SpiritLoong", SpiritLoongModel, "Cosmic", {
	seat = Vector3.new(0, 7, -1.2),
	neck = { center = Vector3.new(0, 4.8, -7.2), radius = 2.6 },
	seatBone = "saddle",
	size = 0.929, -- (42 studs long)
})
