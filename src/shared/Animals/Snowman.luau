-- Snowman: three rounded snowballs, the Horse's eyes, a carrot nose, a coal smile, a red scarf
-- and beanie, stick arms raised. Rare.
-- Model from designs/snow/Snowman.bbmodel (tools/refine_designs.py), animated by tools/snow_rig.py
-- (it hops: the blocks squash on landing, the arms swing) and converted into SnowmanModel.luau
-- by tools/bbmodel_to_luau.py. You ride on top of its head. No legs, so no dust.

local Horse = require(script.Parent.Horse)
local SnowmanModel = require(script.Parent.SnowmanModel)

return Horse.variant("Snowman", SnowmanModel, "Rare", {
	seat = Vector3.new(0, 12.1, 0),
	neck = { center = Vector3.new(0, 8.9, 0), radius = 2.1 },
})
