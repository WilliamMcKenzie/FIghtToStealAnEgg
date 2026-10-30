-- Slime: A dungeon slime: a stepped green cube that squashes and hops, two big
-- eyes and a little smile. You ride on its top.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local SlimeModel = require(script.Parent.SlimeModel)

return Horse.variant("Slime", SlimeModel, "Mythic", {
	seat = Vector3.new(0, 4.9, 0.4),
	neck = { center = Vector3.new(0, 3.6, -0.5), radius = 3.2 },
})
