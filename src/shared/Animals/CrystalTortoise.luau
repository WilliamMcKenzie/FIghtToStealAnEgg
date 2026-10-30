-- CrystalTortoise: The Volcano Tortoise from the Magic Circle: a blue stone shell with a
-- crystal mound glowing where the volcano was, mossy turquoise skin.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local CrystalTortoiseModel = require(script.Parent.CrystalTortoiseModel)

return Horse.variant("CrystalTortoise", CrystalTortoiseModel, "Celestial", {
	seat = Vector3.new(0, 5.2, 2.35),
	neck = { center = Vector3.new(0, 4, -5.6), radius = 1.8 },
})
