-- DungeonRat: The Pig as a dungeon rat: grey fur, round pink ears, a pointed pink
-- nose with buck teeth and a long bare tail.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local DungeonRatModel = require(script.Parent.DungeonRatModel)

return Horse.variant("DungeonRat", DungeonRatModel, "Mythic", {
	seat = Vector3.new(0, 6.4, 0.4),
	neck = { center = Vector3.new(0, 4.2, -3.9), radius = 1.9 },
})
