-- RoyalPeacock: The Firebird as the castle garden's peacock: royal blue with a teal
-- breast, gold claws and a gold crest.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local RoyalPeacockModel = require(script.Parent.RoyalPeacockModel)

return Horse.variant("RoyalPeacock", RoyalPeacockModel, "Celestial", {
	seat = Vector3.new(0, 8.6, 0.8),
	neck = { center = Vector3.new(0, 11, -4.6), radius = 2 },
})
