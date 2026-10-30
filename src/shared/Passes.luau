-- Game passes a player has (QM, Oct 30: the Shop's Game Passes; Config.Shop.Passes). Server/
-- Store sets a Pass<Name> attribute on each player for each pass they own, bought or gifted;
-- this reads it, on the server and the client alike.
--
--   Passes.has(player, name) -> boolean      -- "Life", "Damage", "Cash", "Growth"
--   Passes.mult(player, name) -> 2 or 1      -- the x2 passes' multiplier
--   Passes.hatchTime(player, seconds) -> seconds  -- an egg's grow time, halved by x2 Growth

local Passes = {}

function Passes.has(player, name)
	return player ~= nil and player:GetAttribute("Pass" .. name) == true
end

function Passes.mult(player, name)
	return if Passes.has(player, name) then 2 else 1
end

function Passes.hatchTime(player, seconds)
	return seconds / Passes.mult(player, "Growth")
end

return Passes
