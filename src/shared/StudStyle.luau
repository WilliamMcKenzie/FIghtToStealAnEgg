-- One knob for every stud Texture in the game (QM, Oct 30): workspace.StudStyle, a
-- Configuration with a Transparency attribute (0 = full studs, 1 = none). Change it in
-- the Properties panel in Edit mode (the Map Baker plugin repaints the place) or during
-- Play (server or client view): every stud Texture follows at once, and new ones (pets,
-- eggs, weapons) are made with it. It's kept with the place, like FightBarrierStyle, so
-- your value wins over Config.StudTransparency, which only seeds a place that has none.
--
--   StudStyle.transparency()  -- the current value, for whatever makes a stud Texture
--   StudStyle.ensure()        -- server, once: makes workspace.StudStyle if it's missing
--   StudStyle.watch()         -- server and client, once: applies it, live

local Config = require(script.Parent.Config)

local StudStyle = {}

StudStyle.NAME = "StudStyle"
StudStyle.IMAGE = "rbxassetid://7447638591" -- the classic stud decal every stud Texture uses

function StudStyle.transparency()
	local style = workspace:FindFirstChild(StudStyle.NAME)
	local value = style and style:GetAttribute("Transparency")
	if typeof(value) == "number" then
		return value
	end
	return Config.StudTransparency or 0
end

function StudStyle.ensure()
	local style = workspace:FindFirstChild(StudStyle.NAME)
	if not style then
		style = Instance.new("Configuration")
		style.Name = StudStyle.NAME
		style.Parent = workspace
	end
	if typeof(style:GetAttribute("Transparency")) ~= "number" then
		style:SetAttribute("Transparency", Config.StudTransparency or 0)
	end
	return style
end

local function isStud(thing)
	return thing:IsA("Texture") and thing.Texture == StudStyle.IMAGE
end

function StudStyle.applyAll(value)
	value = value or StudStyle.transparency()
	for _, thing in workspace:GetDescendants() do
		if isStud(thing) then
			thing.Transparency = value
		end
	end
end

function StudStyle.watch()
	local style = workspace:WaitForChild(StudStyle.NAME, 30)
	if not style then
		return
	end
	StudStyle.applyAll()
	style:GetAttributeChangedSignal("Transparency"):Connect(function()
		StudStyle.applyAll()
	end)
	-- (anything made later with another value, or before the knob reached this side)
	workspace.DescendantAdded:Connect(function(thing)
		if isStud(thing) then
			thing.Transparency = StudStyle.transparency()
		end
	end)
end

return StudStyle
