-- Cactus: a running cactus guy, Uncommon.
-- Model and animations from designs/desert/Cactus.bbmodel (tools/cactus_rig.py), converted
-- into CactusModel.luau by tools/bbmodel_to_luau.py. You ride on top of his head.

local Horse = require(script.Parent.Horse)
local CactusModel = require(script.Parent.CactusModel)

return Horse.variant("Cactus", CactusModel, "Uncommon", {
	seat = Vector3.new(0, 11.7, 0.2),
	neck = { center = Vector3.new(0, 9.5, 0), radius = 2.2 },
})
