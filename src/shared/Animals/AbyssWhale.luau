-- AbyssWhale: The Lava Whale from the bottom of the trench: navy hide, a pale belly and
-- its glyphs glowing cyan like deep-sea lights. The trench's prize, bigger than the Whale.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local AbyssWhaleModel = require(script.Parent.AbyssWhaleModel)

return Horse.variant("AbyssWhale", AbyssWhaleModel, "Void", {
	seat = Vector3.new(0, 6.4, 1.2),
	neck = { center = Vector3.new(0, 4.5, -6.5), radius = 3.8 },
	size = 1.52, -- (its longest side 44 studs)
})
