-- WarBoar: The Boar in the Red Castle's barding: dark bristles, a crimson mane, a
-- steel helm on its brow and gold tusks.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local WarBoarModel = require(script.Parent.WarBoarModel)

return Horse.variant("WarBoar", WarBoarModel, "Divine", {
	seat = Vector3.new(0, 6.27, 1.52),
	neck = { center = Vector3.new(0, 4.94, -4.56), radius = 2.66 },
})
