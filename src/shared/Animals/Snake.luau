-- Snake: a long horned desert snake that rears up, Legendary. Its slit pupils glow (Neon).
-- QM's model designs/desert/Snake.bbmodel, animated by tools/snake_rig.py and converted
-- into SnakeModel.luau by tools/bbmodel_to_luau.py. You ride its first segment, behind the neck.

local Horse = require(script.Parent.Horse)
local SnakeModel = require(script.Parent.SnakeModel)

return Horse.variant("Snake", SnakeModel, "Legendary", {
	seat = Vector3.new(0, 3.5, 1.6),
	neck = { center = Vector3.new(0, 2.2, -5), radius = 2.3 },
})
