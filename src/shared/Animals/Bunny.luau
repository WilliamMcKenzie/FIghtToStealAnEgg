-- Bunny: a tan cottontail that hops, with tall ears and big hind feet (QM picked take A, Oct 7).
-- Model from designs/animals/Bunny.bbmodel (tools/bunny_design.py game), converted into
-- BunnyModel.luau by tools/bbmodel_to_luau.py. Seat and neck loop from meta.json.

local Horse = require(script.Parent.Horse)
local BunnyModel = require(script.Parent.BunnyModel)

return Horse.variant("Bunny", BunnyModel, "Uncommon", {
	seat = Vector3.new(0, 5.2, 0.6),
	neck = { center = Vector3.new(0, 4.4, -3.4), radius = 1.8 },
})
