-- The HUD in a boss fight (QM, Oct 31): while you're locked into one (your LockedIn
-- attribute), everything on the HUD goes except the Power and Cash counters (bottom left)
-- and the boss bar: no Shop/Index/Eggs/Pets buttons, no hotbar, no popups, no goal panel,
-- no "Place your egg" lines. When the fight ends it all comes back as it was.
--
-- Every other child of StarterGui > Hud > Root is hidden, so anything added there later (the
-- goal panel, a new popup) is hidden in fights too without being listed here. Only KEEP stays.
-- Other screens named in SCREENS (their own ScreenGuis) are switched off as well.
--
-- The code that runs each piece still sets its Visible during a fight (a popup closing, the
-- "Place your egg" line coming and going); that's remembered and put back afterwards instead
-- of what it was when the fight started, so nothing comes back that shouldn't.
--
-- Your weapon is in your hand for the whole fight (Server/Arsenal, Server/Hatchery: no
-- holding an egg while LockedIn), since the hotbar to switch with is hidden.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local KEEP = { -- children of Hud > Root that stay in a fight
	Power = true,
	Cash = true,
	BossBar = true,
}
local SCREENS = { -- other ScreenGuis in PlayerGui that go in a fight (if they exist)
	Goal = true,
	GoalPanel = true,
	Goals = true,
}

local hidden = {} -- [object] = { prop = "Visible" | "Enabled", wanted = value its own code wants, conn }
local forcing = false
local inFight = false

local function hide(object, prop)
	if hidden[object] then
		return
	end
	local entry = { prop = prop, wanted = object[prop] }
	hidden[object] = entry
	entry.conn = object:GetPropertyChangedSignal(prop):Connect(function()
		if forcing then
			return
		end
		-- (its own code changed it mid-fight: remember that, keep it hidden)
		entry.wanted = object[prop]
		if object[prop] then
			forcing = true
			object[prop] = false
			forcing = false
		end
	end)
	forcing = true
	object[prop] = false
	forcing = false
end

local function restoreAll()
	for object, entry in hidden do
		entry.conn:Disconnect()
		if object.Parent then
			forcing = true
			object[entry.prop] = entry.wanted
			forcing = false
		end
	end
	table.clear(hidden)
end

local root -- PlayerGui > Hud > Root
local playerGui = player:WaitForChild("PlayerGui")

local function consider(child)
	if not inFight then
		return
	end
	if child.Parent == root and child:IsA("GuiObject") and not KEEP[child.Name] then
		hide(child, "Visible")
	elseif child.Parent == playerGui and child:IsA("ScreenGui") and SCREENS[child.Name] then
		hide(child, "Enabled")
	end
end

local function update()
	local now = player:GetAttribute("LockedIn") ~= nil
	if now == inFight then
		return
	end
	inFight = now
	if not now then
		restoreAll()
		return
	end
	if root then
		for _, child in root:GetChildren() do
			consider(child)
		end
	end
	for _, child in playerGui:GetChildren() do
		consider(child)
	end
end

player:GetAttributeChangedSignal("LockedIn"):Connect(update)
playerGui.ChildAdded:Connect(consider)
task.spawn(function()
	local hud = playerGui:WaitForChild("Hud")
	root = hud:WaitForChild("Root")
	root.ChildAdded:Connect(consider)
	if inFight then
		for _, child in root:GetChildren() do
			consider(child)
		end
	end
end)
update()

return {}
