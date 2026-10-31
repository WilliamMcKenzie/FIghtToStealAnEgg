-- BoneSteed: The Horse as a skeleton: bone white, a crypt-dark mane and hooves, ribs
-- down its sides and the dungeon's green glowing in its eye sockets.
-- Made by tools/later_pets.py.

local Horse = require(script.Parent.Horse)
local BoneSteedModel = require(script.Parent.BoneSteedModel)

return Horse.variant("BoneSteed", BoneSteedModel, "Divine")
