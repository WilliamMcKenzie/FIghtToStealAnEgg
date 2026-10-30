-- ChessKnight: A giant chess knight from the Red Castle's hall: ivory, a crimson mane
-- and gold rings, hopping on its round base like the piece it is.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local ChessKnightModel = require(script.Parent.ChessKnightModel)

return Horse.variant("ChessKnight", ChessKnightModel, "Celestial", {
	seat = Vector3.new(0, 5.6, 1.5),
	neck = { center = Vector3.new(0, 5.6, -0.6), radius = 2 },
})
