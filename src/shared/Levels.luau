-- Levels (QM, Oct 31): your Power (Strength) puts you on a level (Config.Levels). The HUD
-- counter shows "4.1K/10K", "Level up!" pops over your head (client/LevelUp), and the level
-- shows in yellow by your name (client/PlayerBars). Server/Combat keeps the player's Level
-- attribute up to date. What a level does to damage and attack speed is in Shared/Power.
--
--   Levels.at(level) -> the Power that level starts at (0 for level 1)
--   Levels.of(power) -> level (1 and up)
--   Levels.goal(power) -> the Power the next level starts at

local Config = require(script.Parent:WaitForChild("Config"))

local Levels = {}

function Levels.at(level)
	local c = Config.Levels
	if level <= 1 then
		return 0
	end
	local i = level - 2
	local steps = c.Steps
	local decade = i // #steps
	return c.First.Power * steps[i % #steps + 1] * 10 ^ decade
end

function Levels.of(power)
	power = tonumber(power) or 0
	if power ~= power then
		return 1
	end
	local level = 1
	-- (whole decades at a time first, so huge Power doesn't walk one level at a time)
	local steps = #Config.Levels.Steps
	while level < 100000 and Levels.at(level + 1 + steps) <= power do
		level += steps
	end
	while level < 100000 and Levels.at(level + 1) <= power do
		level += 1
	end
	return level
end

function Levels.goal(power)
	return Levels.at(Levels.of(power) + 1)
end

return Levels
