-- Boar: a stocky brown boar with a big pink nose, angry brows, tusks and dark tufts round its face. Uncommon.
-- Converted from QM's old Blockbench model by tools/convert_designs.py (the pose is in its bones'
-- rest rotations), animated by tools/convert_rig.py and converted into BoarModel.luau by
-- tools/bbmodel_to_luau.py from designs/converted/Boar.bbmodel. You ride on its back behind the shoulder hump.

local Horse = require(script.Parent.Horse)
local BoarModel = require(script.Parent.BoarModel)

return Horse.variant("Boar", BoarModel, "Uncommon", {
	seat = Vector3.new(0, 6.27, 1.52),
	neck = { center = Vector3.new(0, 4.94, -4.56), radius = 2.66 },
})
