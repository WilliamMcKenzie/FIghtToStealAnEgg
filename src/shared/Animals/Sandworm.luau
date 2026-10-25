-- Sandworm: plated segments, four mandibles round its maw. Epic.
-- QM's model designs/desert/Sandworm.bbmodel, animated by tools/sandworm_rig.py and
-- converted into SandwormModel.luau by tools/bbmodel_to_luau.py. You ride its front segment.

local Horse = require(script.Parent.Horse)
local SandwormModel = require(script.Parent.SandwormModel)

return Horse.variant("Sandworm", SandwormModel, "Epic", {
	seat = Vector3.new(0, 4.45, 1.6),
	neck = { center = Vector3.new(0, 3.2, -2.6), radius = 3 },
})
