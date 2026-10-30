-- Shark: The Fish as a shark: grey with a white belly, a tall dorsal fin and teeth.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local SharkModel = require(script.Parent.SharkModel)

return Horse.variant("Shark", SharkModel, "Celestial", {
	seat = Vector3.new(0, 6.48, -0.54),
	neck = { center = Vector3.new(0, 2.97, -3.51), radius = 2.565 },
})
