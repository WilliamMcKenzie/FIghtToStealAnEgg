-- CrimsonDrake: The Spine Lizard as the castle's drake: crimson scales, a gold belly and
-- sail, black crests and two horns.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local CrimsonDrakeModel = require(script.Parent.CrimsonDrakeModel)

return Horse.variant("CrimsonDrake", CrimsonDrakeModel, "Cosmic", {
	seat = Vector3.new(0, 4.2, -4.08),
	neck = { center = Vector3.new(0, 2.84, -4.42), radius = 2.04 },
})
