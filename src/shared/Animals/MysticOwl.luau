-- MysticOwl: The Penguin as the Magic Circle's owl: night blue, a pale violet front,
-- gold beak and feet, ear tufts and big glowing eyes.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local MysticOwlModel = require(script.Parent.MysticOwlModel)

return Horse.variant("MysticOwl", MysticOwlModel, "Celestial", {
	seat = Vector3.new(0, 9.9, -0.2),
	neck = { center = Vector3.new(0, 7.9, -0.2), radius = 2.2 },
})
