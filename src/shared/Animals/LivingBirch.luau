-- LivingBirch: LassoAPet's Living Birch: a white birch trunk with dark bands, a face,
-- leafy hands, stubby legs and a chunky autumn canopy. You ride on top of the canopy.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local LivingBirchModel = require(script.Parent.LivingBirchModel)

return Horse.variant("LivingBirch", LivingBirchModel, "Divine", {
	seat = Vector3.new(0, 17.3, 0),
	neck = { center = Vector3.new(0, 9.6, 0), radius = 2 },
})
