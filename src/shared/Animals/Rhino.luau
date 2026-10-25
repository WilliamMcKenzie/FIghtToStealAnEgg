-- Rhino: grey, heavy, with a big horn on its snout.
-- Model from designs/animals/Rhino.bbmodel (tools/animal_designs.py), converted into
-- RhinoModel.luau by tools/bbmodel_to_luau.py. Seat and neck loop from meta.json.

local Horse = require(script.Parent.Horse)
local RhinoModel = require(script.Parent.RhinoModel)

return Horse.variant("Rhino", RhinoModel, "Epic", {
	seat = Vector3.new(0, 7.4, 2.2),
	neck = { center = Vector3.new(0, 5.2, -3.7), radius = 1.9 },
})
