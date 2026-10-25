-- Unicorn: a white horse with a rainbow mane and tail and a gold horn.
-- Model from designs/animals/Unicorn.bbmodel (tools/animal_designs.py), converted into
-- UnicornModel.luau by tools/bbmodel_to_luau.py. Seat and neck loop from meta.json.

local Horse = require(script.Parent.Horse)
local UnicornModel = require(script.Parent.UnicornModel)

return Horse.variant("Unicorn", UnicornModel, "Legendary", {
	seat = Vector3.new(0, 7.3, 1),
	neck = { center = Vector3.new(0, 7.4, -1.9), radius = 1.35 },
})
