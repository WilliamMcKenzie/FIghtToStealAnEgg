-- RoyalSteed: The Horse dressed for the Red Castle: white, a crimson caparison with gold
-- trim, a steel face plate and a red plume.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local RoyalSteedModel = require(script.Parent.RoyalSteedModel)

return Horse.variant("RoyalSteed", RoyalSteedModel, "Divine", {
	seat = points.seat or SEAT,
	neck = byName.neckBone,
})
