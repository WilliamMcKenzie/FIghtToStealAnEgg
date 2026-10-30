-- KingCrab: The King Crab of the Ocean Trench (its model shared with the trench's boss).
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local KingCrabModel = require(script.Parent.KingCrabModel)

return Horse.variant("KingCrab", KingCrabModel, "Celestial", {
	seat = Vector3.new(0, 4.3, -0.6),
	neck = { center = Vector3.new(0, 3, -2.6), radius = 2.4 },
})
