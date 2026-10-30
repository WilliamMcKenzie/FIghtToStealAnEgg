-- Shroom: A walking mushroom from the Magic Circle: a blue stepped cap with glowing
-- spots over a cream stem with a face, on two little feet.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local ShroomModel = require(script.Parent.ShroomModel)

return Horse.variant("Shroom", ShroomModel, "Mythic", {
	seat = Vector3.new(0, 8, 0.2),
	neck = { center = Vector3.new(0, 4, 0), radius = 2 },
})
