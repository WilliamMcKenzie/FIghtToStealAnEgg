-- Snack Yak: QM's shaggy yak with a saddle, a fruit basket on its back, saddlebags with a
-- ham and a fish in them, and a stick dangling carrots in front of its nose. Epic, Tundra.
-- designs/snow/SnackYak.bbmodel is QM's painted model (SnackYak_QM.bbmodel) in one colour a
-- block, rigged and animated by tools/snack_yak.py, converted into SnackYakModel.luau with
-- `tools/bbmodel_to_luau.py --zyx`. You ride in the saddle, just in front of the stick.
-- QM's Oct 4 edit (SnackYak_QM2.bbmodel) is drawn 3.9x bigger (tools/bb_scale.py), about its
-- size in game, so its studs come out the Horse's size (QM: they were way too big).

local Horse = require(script.Parent.Horse)
local SnackYakModel = require(script.Parent.SnackYakModel)

return Horse.variant("SnackYak", SnackYakModel, "Epic", {
	seat = Vector3.new(0, 8.97, -0.39),
	neck = { center = Vector3.new(0, 5.07, -5.46), radius = 2.34 },
})
