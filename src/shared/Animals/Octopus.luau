-- Octopus: A deep violet octopus from the Ocean Trench: a big round mantle with pale
-- spots, wide eyes and eight curling arms that ripple as it walks.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local OctopusModel = require(script.Parent.OctopusModel)

return Horse.variant("Octopus", OctopusModel, "Cosmic", {
	seat = Vector3.new(0, 7.6, 0.6),
	neck = { center = Vector3.new(0, 3.4, -0.2), radius = 3 },
})
