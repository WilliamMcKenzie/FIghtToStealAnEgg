-- Whale: LassoAPet's Whale: a big blue sperm whale with a huge square head, a pale ridged
-- belly and cyan spiral glyphs. You ride on its back, behind the head.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local WhaleModel = require(script.Parent.WhaleModel)

return Horse.variant("Whale", WhaleModel, "Cosmic", {
	seat = Vector3.new(0, 6.4, 1.2),
	neck = { center = Vector3.new(0, 4.5, -6.5), radius = 3.8 },
	size = 1.217, -- (its longest side 34 studs)
})
