-- SpiritFox: The Bunny as the Magic Circle's spirit fox: white, pointed ears and a big
-- bushy tail glowing blue at the tips.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local SpiritFoxModel = require(script.Parent.SpiritFoxModel)

return Horse.variant("SpiritFox", SpiritFoxModel, "Mythic", {
	seat = Vector3.new(0, 5.2, 0.6),
	neck = { center = Vector3.new(0, 4.4, -3.4), radius = 1.8 },
})
