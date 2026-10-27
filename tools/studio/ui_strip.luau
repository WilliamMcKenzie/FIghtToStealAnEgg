-- One-off (QM, Oct 27: "remove ALL ui ... other than the boss HP bar"): deletes everything in
-- StarterGui.Hud.Root except the BossBar (and the Fit scale), keeping QM's edits to the bar.
-- Run with lu.py in Edit after syncing src/, then save the place and run uisave.py.
if game:GetService("RunService"):IsRunning() then
	return "playing: stop Play first"
end
local hud = game:GetService("StarterGui"):FindFirstChild("Hud")
local root = hud and hud:FindFirstChild("Root")
if not root then
	return "no StarterGui.Hud.Root: nothing to strip"
end
local gone = {}
for _, child in root:GetChildren() do
	if child.Name ~= "BossBar" and child.Name ~= "Fit" then
		table.insert(gone, child.Name)
		child:Destroy()
	end
end
-- (the old shared outline's settings: the boss name keeps its own UIStroke)
for _, name in { "OutlineColor", "OutlineThickness", "TextOutlineThickness" } do
	hud:SetAttribute(name, nil)
end
game:GetService("ChangeHistoryService"):SetWaypoint("Strip UI")
return "removed: " .. (if #gone > 0 then table.concat(gone, ", ") else "nothing")
