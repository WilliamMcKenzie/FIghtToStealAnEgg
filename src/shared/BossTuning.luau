-- Live boss tuning (QM, Oct 30): workspace.BossTuning, a Configuration to edit during Play.
-- The server makes it fresh from Config each run; the client reads it every frame, so a
-- change shows at once. Edit it in either view (Client or Server): only the client reads it.
--
--   BossScale  how big the bosses out now are drawn, times their Config size (1 = as is).
--              Only the look: their hitbox and attack reach stay Config's
--   Boss       (filled in by the client) the boss out now, and the Size to put in its
--              Config.Bosses entry for this scale
--   Fixed      the boss fight camera holds still over the arena's middle, zoomed so its
--              width fits the screen (off: it follows you, Distance studs away)
--   Fit        with Fixed, how much of the screen's width the arena takes (1 = edge to
--              edge, 1.1 = a little room either side, 0.9 = a little cut off)
--   Distance, Pitch, Yaw, Height, Fov   the rest of the boss fight camera (Config.FightCam:
--              Distance is the zoom when it follows you, studs from you)
--
-- Tick PrintConfig to print the values to the Output, ready to paste into Config (or to
-- send to Claude).
--
--   BossTuning.create()     -- server, once
--   BossTuning.camera()     -- Config.FightCam with the attributes applied
--   BossTuning.scale()      -- BossScale (1 without the folder)
--   BossTuning.watchPrint() -- client, once

local Config = require(script.Parent.Config)

local BossTuning = {}

local NAME = "BossTuning"
local CAMERA = { "Fixed", "Fit", "Distance", "Pitch", "Yaw", "Height", "Fov" }

function BossTuning.create()
	local old = workspace:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Configuration")
	folder.Name = NAME
	folder:SetAttribute("BossScale", 1)
	folder:SetAttribute("Boss", "")
	for _, name in CAMERA do
		folder:SetAttribute(name, Config.FightCam[name])
	end
	folder:SetAttribute("PrintConfig", false)
	folder.Parent = workspace
	return folder
end

function BossTuning.folder()
	return workspace:FindFirstChild(NAME)
end

function BossTuning.camera()
	local c = Config.FightCam
	local folder = workspace:FindFirstChild(NAME)
	if not folder then
		return c
	end
	c = table.clone(c)
	for _, name in CAMERA do
		local value = folder:GetAttribute(name)
		if typeof(value) == typeof(c[name]) then
			c[name] = value
		end
	end
	return c
end

function BossTuning.scale()
	local folder = workspace:FindFirstChild(NAME)
	local value = folder and folder:GetAttribute("BossScale")
	return if typeof(value) == "number" and value > 0 then value else 1
end

function BossTuning.print()
	local c = BossTuning.camera()
	local parts = {}
	for _, name in CAMERA do
		local value = if typeof(c[name]) == "number" then string.format("%.4g", c[name]) else tostring(c[name])
		table.insert(parts, name .. " = " .. value)
	end
	local lines = { "-- BossTuning", "FightCam: " .. table.concat(parts, ", ") }
	local folder = workspace:FindFirstChild(NAME)
	local boss = folder and folder:GetAttribute("Boss")
	if typeof(boss) == "string" and boss ~= "" then
		table.insert(lines, "Boss: " .. boss)
	end
	print(table.concat(lines, "\n"))
end

function BossTuning.watchPrint()
	task.spawn(function()
		local folder = workspace:WaitForChild(NAME)
		folder:GetAttributeChangedSignal("PrintConfig"):Connect(function()
			if folder:GetAttribute("PrintConfig") then
				BossTuning.print()
				folder:SetAttribute("PrintConfig", false)
			end
		end)
	end)
end

return BossTuning
