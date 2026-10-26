-- One-off (QM, Oct 26): makes the baked Backpack popup in StarterGui QM's plain tiled panel:
-- removes its dark Panel, title, X, SORT and EQUIP BEST. Run uibake.luau after it to make
-- the tiled Panel, then save the place.
local root = game:GetService("StarterGui"):FindFirstChild("Hud")
root = root and root:FindFirstChild("Root")
local popup = root and root:FindFirstChild("BackpackPopup")
if not popup then
	return "no StarterGui.Hud.Root.BackpackPopup"
end
local gone = {}
for _, name in { "Panel", "Title", "Close", "Sort", "EquipBest" } do
	local child = popup:FindFirstChild(name)
	if child then
		child:Destroy()
		table.insert(gone, name)
	end
end
return "removed " .. table.concat(gone, ", ") .. ": now run uibake.luau"
