-- Pufferfish: The Fish puffed up: round and yellow with brown spots and white spines.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local PufferfishModel = require(script.Parent.PufferfishModel)

return Horse.variant("Pufferfish", PufferfishModel, "Divine", {
	seat = Vector3.new(0, 7.1, -0.54),
	neck = { center = Vector3.new(0, 3.6, -3.51), radius = 3 },
})
