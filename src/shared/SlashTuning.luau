-- Live slash tuning: workspace.SlashTuning, a Configuration whose attributes are every
-- Config.Slash value (numbers, true/false, colours) plus each Variety range as a
-- Vector2 named Variety_<name> (X = min, Y = max). The server makes it fresh from
-- Config each run; the client reads it on every slash, so editing an attribute in the
-- Properties panel during Play shows on the next click. (Edit it in the Client view:
-- the slash is drawn on the client.)
--
-- Tick PrintConfig to print the current values as a Config.Slash block to the Output,
-- ready to paste into src/shared/Config.luau (or to send to Claude).
--
--   SlashTuning.create()      -- server, once
--   SlashTuning.read()        -- Config.Slash with the attributes applied
--   SlashTuning.watchPrint()  -- client, once

local Config = require(script.Parent.Config)

local SlashTuning = {}

local NAME = "SlashTuning"
local SIMPLE = { number = true, boolean = true, Color3 = true }

function SlashTuning.create()
	local old = workspace:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Configuration")
	folder.Name = NAME
	for name, value in Config.Slash do
		if SIMPLE[typeof(value)] then
			folder:SetAttribute(name, value)
		end
	end
	for name, range in Config.Slash.Variety do
		folder:SetAttribute("Variety_" .. name, Vector2.new(range[1], range[2]))
	end
	folder:SetAttribute("PrintConfig", false)
	folder.Parent = workspace
	return folder
end

function SlashTuning.read()
	local c = table.clone(Config.Slash)
	c.Variety = table.clone(Config.Slash.Variety)
	local folder = workspace:FindFirstChild(NAME)
	if not folder then
		return c
	end
	for name, value in folder:GetAttributes() do
		local variety = name:match("^Variety_(.+)$")
		if variety and typeof(value) == "Vector2" then
			c.Variety[variety] = { value.X, value.Y }
		elseif c[name] ~= nil and typeof(value) == typeof(c[name]) then
			c[name] = value
		end
	end
	return c
end

local function format(value)
	if typeof(value) == "number" then
		return string.format("%.4g", value)
	elseif typeof(value) == "Color3" then
		return string.format(
			"Color3.fromRGB(%d, %d, %d)",
			math.round(value.R * 255),
			math.round(value.G * 255),
			math.round(value.B * 255)
		)
	end
	return tostring(value)
end

function SlashTuning.print()
	local c = SlashTuning.read()
	local names = {}
	for name, value in c do
		if SIMPLE[typeof(value)] then
			table.insert(names, name)
		end
	end
	table.sort(names)
	local lines = { "Slash = {" }
	for _, name in names do
		table.insert(lines, string.format("\t%s = %s,", name, format(c[name])))
	end
	table.insert(lines, "\tVariety = {")
	local kinds = {}
	for name in c.Variety do
		table.insert(kinds, name)
	end
	table.sort(kinds)
	for _, name in kinds do
		local r = c.Variety[name]
		table.insert(lines, string.format("\t\t%s = { %s, %s },", name, format(r[1]), format(r[2])))
	end
	table.insert(lines, "\t},")
	table.insert(lines, "\t(Sounds unchanged)")
	table.insert(lines, "},")
	print(table.concat(lines, "\n"))
end

function SlashTuning.watchPrint()
	local folder = workspace:WaitForChild(NAME, 30)
	if not folder then
		return
	end
	folder:GetAttributeChangedSignal("PrintConfig"):Connect(function()
		if folder:GetAttribute("PrintConfig") then
			SlashTuning.print()
			folder:SetAttribute("PrintConfig", false)
		end
	end)
end

return SlashTuning
