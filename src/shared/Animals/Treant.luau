-- Treant: The Ice Golem grown from the Magic Circle's trees: bark limbs, a turquoise
-- mossy cap and shoulders, and leafy shoots where its crystals were.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local TreantModel = require(script.Parent.TreantModel)

return Horse.variant("Treant", TreantModel, "Divine", {
	seat = Vector3.new(0, 13.36, 0.4),
	neck = { center = Vector3.new(0, 9.2, -1.6), radius = 2.8 },
})
