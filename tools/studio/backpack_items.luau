-- One-off (QM, Oct 26): clears the old Pets / Weapons tab buttons off StarterGui's Backpack
-- popup, so uibake.luau makes QM's new side selector (ItemsTab, PetsTab) and the Items tab.
-- Run uibake.luau after it, then save the place.
local root = game:GetService("StarterGui"):FindFirstChild("Hud")
root = root and root:FindFirstChild("Root")
local popup = root and root:FindFirstChild("BackpackPopup")
if not popup then
	return "no StarterGui.Hud.Root.BackpackPopup"
end
local gone = {}
for _, name in { "PetsTab", "WeaponsTab" } do
	local child = popup:FindFirstChild(name)
	if child then
		child:Destroy()
		table.insert(gone, name)
	end
end
return "removed " .. table.concat(gone, ", ") .. ": now run uibake.luau"
