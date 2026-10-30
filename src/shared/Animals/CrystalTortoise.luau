-- CrystalTortoise: The Treasure Turtle without its island, from the Magic Circle: a stepped
-- blue stone shell with glowing crystal scutes, a pale plastron and its teal skin.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local CrystalTortoiseModel = require(script.Parent.CrystalTortoiseModel)

return Horse.variant("CrystalTortoise", CrystalTortoiseModel, "Celestial", {
	seat = Vector3.new(0, 7.3, 0.3),
	neck = { center = Vector3.new(0, 5.18, -8.4), radius = 2 },
	size = 1.494, -- (its longest side 28 studs)
})
