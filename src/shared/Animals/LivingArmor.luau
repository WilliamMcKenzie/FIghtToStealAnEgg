-- LivingArmor: The Icebringer as an empty suit of the castle's armour: steel plates over
-- crimson cloth, gold trim and red eyes glowing inside.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local LivingArmorModel = require(script.Parent.LivingArmorModel)

return Horse.variant("LivingArmor", LivingArmorModel, "Cosmic", {
	seat = Vector3.new(0, 9.8, 1.1),
	neck = { center = Vector3.new(0, 9, -0.8), radius = 1.3 },
	size = 1.507, -- (its longest side 34 studs)
})
