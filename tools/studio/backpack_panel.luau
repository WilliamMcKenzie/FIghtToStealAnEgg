-- One-off (QM, Oct 26): swaps the baked Backpack popup's dark Panel in StarterGui for the new
-- tiled one. Removes the old Panel; run uibake.luau after it to make the new one, then save.
local popup = game:GetService("StarterGui"):FindFirstChild("Hud")
popup = popup and popup:FindFirstChild("Root") and popup.Root:FindFirstChild("BackpackPopup")
local panel = popup and popup:FindFirstChild("Panel")
if not panel then
	return "no StarterGui.Hud.Root.BackpackPopup.Panel"
end
panel:Destroy()
return "removed the old Backpack panel: now run uibake.luau"
