-- Is this humanoid up and fighting? (QM, Nov 3: the death screen.) A hit that would kill
-- you knocks you down instead (Server/Death): Health a hair above 0, the character's Downed
-- attribute set, lying on the floor while the death screen asks Continue or Revive. Downed,
-- you're out of it: nothing targets or hits you, you don't attack, heal or move. Everything
-- that used to ask "Health > 0" about a player asks this.
--
--   Alive(humanoid) -> bool

return function(humanoid)
	return humanoid ~= nil
		and humanoid.Health > 0
		and not (humanoid.Parent and humanoid.Parent:GetAttribute("Downed"))
end
