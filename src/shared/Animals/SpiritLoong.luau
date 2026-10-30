-- SpiritLoong: The Snake as the Magic Circle's spirit dragon: turquoise and white with
-- violet bands, glowing blue whiskers and crest.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local SpiritLoongModel = require(script.Parent.SpiritLoongModel)

return Horse.variant("SpiritLoong", SpiritLoongModel, "Cosmic", {
	seat = Vector3.new(0, 3.5, 1.6),
	neck = { center = Vector3.new(0, 2.2, -5), radius = 2.3 },
})
