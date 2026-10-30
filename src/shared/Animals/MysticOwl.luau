-- MysticOwl: The Penguin as the Magic Circle's owl: tawny feathers with darker wings,
-- a speckled cream front, a wide pale face with big amber eyes, ear tufts and a small beak.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local MysticOwlModel = require(script.Parent.MysticOwlModel)

return Horse.variant("MysticOwl", MysticOwlModel, "Celestial", {
	seat = Vector3.new(0, 9.9, -0.2),
	neck = { center = Vector3.new(0, 7.9, -0.2), radius = 2.2 },
})
