-- SpiritDeer: The Unicorn as the Magic Circle's spirit deer: turquoise with a darker mane,
-- white spots and glowing crystal antlers.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local SpiritDeerModel = require(script.Parent.SpiritDeerModel)

return Horse.variant("SpiritDeer", SpiritDeerModel, "Divine", {
	seat = Vector3.new(0, 7.3, 1),
	neck = { center = Vector3.new(0, 7.4, -1.9), radius = 1.35 },
})
