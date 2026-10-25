-- Pig: pink, round and quick on its short legs.
-- Model from designs/animals/Pig.bbmodel (tools/animal_designs.py), converted into
-- PigModel.luau by tools/bbmodel_to_luau.py. Seat and neck loop from meta.json.

local Horse = require(script.Parent.Horse)
local PigModel = require(script.Parent.PigModel)

return Horse.variant("Pig", PigModel, "Uncommon", {
	seat = Vector3.new(0, 6.4, 0.4),
	neck = { center = Vector3.new(0, 4.2, -3.9), radius = 1.9 },
})
