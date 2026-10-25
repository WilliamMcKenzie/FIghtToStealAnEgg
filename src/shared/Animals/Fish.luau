-- Fish: a big blue fish with no legs; it flops along on its belly.
-- Model from designs/animals/Fish.bbmodel (tools/animal_designs.py), converted into
-- FishModel.luau by tools/bbmodel_to_luau.py. Seat and neck loop from meta.json.

local Horse = require(script.Parent.Horse)
local FishModel = require(script.Parent.FishModel)

return Horse.variant("Fish", FishModel, "Rare", {
	seat = Vector3.new(0, 6.48, -0.54),
	neck = { center = Vector3.new(0, 2.97, -3.51), radius = 2.565 },
})
