-- Live world colours: every part (or checker Texture) with a ColorKey attribute wears
-- Config.WorldColors[ColorKey]. The server makes workspace.WorldColors, a Configuration
-- with one Color3 attribute per key, fresh from Config each run; the client repaints
-- everything with that key whenever one changes, so you can tune colours in the
-- Properties panel during Play (in the Client view). Tick PrintColors to print the
-- current set as a Config.WorldColors block for the Output (paste it into Config, or to
-- Claude). StudTransparency there fades every stud Texture the same way.
-- On start everything is painted from Config, so a saved place can't keep stale colours.
--
--   WorldColors.create()  -- server, once
--   WorldColors.watch()   -- client, once

local Config = require(script.Parent.Config)

local WorldColors = {}

local NAME = "WorldColors"
local STUD_IMAGE = "rbxassetid://7447638591"

function WorldColors.create()
	local old = workspace:FindFirstChild(NAME)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Configuration")
	folder.Name = NAME
	for key, color in Config.WorldColors do
		folder:SetAttribute(key, color)
	end
	folder:SetAttribute("StudTransparency", Config.StudTransparency)
	folder:SetAttribute("PrintColors", false)
	folder.Parent = workspace
	WorldColors.paintAll(folder)
	return folder
end

local function paint(key, color)
	for _, thing in workspace:GetDescendants() do
		if thing:GetAttribute("ColorKey") == key then
			if thing:IsA("BasePart") then
				thing.Color = color
			elseif thing:IsA("Texture") then
				thing.Color3 = color
			end
		end
	end
end

-- everything, from the folder's current values (the server does this on start, so the
-- world always wears Config's colours however the place was saved)
function WorldColors.paintAll(folder)
	local stud = folder:GetAttribute("StudTransparency")
	for _, thing in workspace:GetDescendants() do
		local key = thing:GetAttribute("ColorKey")
		local color = key and folder:GetAttribute(key)
		if typeof(color) == "Color3" then
			if thing:IsA("BasePart") then
				thing.Color = color
			elseif thing:IsA("Texture") then
				thing.Color3 = color
			end
		elseif stud and thing:IsA("Texture") and thing.Texture == STUD_IMAGE then
			thing.Transparency = stud
		end
	end
end

local function printAll(folder)
	local keys = {}
	for key, value in folder:GetAttributes() do
		if typeof(value) == "Color3" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local lines = { "WorldColors = {" }
	for _, key in keys do
		local c = folder:GetAttribute(key)
		table.insert(
			lines,
			string.format(
				"\t%s = Color3.fromRGB(%d, %d, %d),",
				key,
				math.round(c.R * 255),
				math.round(c.G * 255),
				math.round(c.B * 255)
			)
		)
	end
	table.insert(lines, "},")
	print(table.concat(lines, "\n"))
end

function WorldColors.watch()
	local folder = workspace:WaitForChild(NAME, 30)
	if not folder then
		return
	end
	WorldColors.paintAll(folder)
	folder.AttributeChanged:Connect(function(key)
		local value = folder:GetAttribute(key)
		if key == "PrintColors" then
			if value then
				printAll(folder)
				print("StudTransparency = " .. tostring(folder:GetAttribute("StudTransparency")))
				folder:SetAttribute("PrintColors", false)
			end
		elseif key == "StudTransparency" and typeof(value) == "number" then
			for _, thing in workspace:GetDescendants() do
				if thing:IsA("Texture") and thing.Texture == STUD_IMAGE then
					thing.Transparency = value
				end
			end
		elseif typeof(value) == "Color3" then
			paint(key, value)
		end
	end)
end

return WorldColors
