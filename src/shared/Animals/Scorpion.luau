-- Scorpion: low and wide, big pincers, tail over its back. Rare.
-- QM's model designs/desert/Scorpion.bbmodel, animated by tools/scorpion_rig.py and
-- converted into ScorpionModel.luau by tools/bbmodel_to_luau.py.

local Horse = require(script.Parent.Horse)
local ScorpionModel = require(script.Parent.ScorpionModel)

return Horse.variant("Scorpion", ScorpionModel, "Rare", {
	seat = Vector3.new(0, 4.42, -0.52),
	neck = { center = Vector3.new(0, 2.99, -3.9), radius = 2.2 },
})
