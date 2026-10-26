-- One-off (Oct 26): takes the old HUD buttons and counters out of StarterGui.Hud, the ones whose
-- outline was baked into their image, so uibake.luau builds the new ones (client/Outline: the
-- same outline on every icon and label). Only removes the old style (no Art child), so running
-- it again does nothing. Run with lu.py in Edit after syncing src/, then uibake.luau, then save.
if game:GetService("RunService"):IsRunning() then
	return "playing: stop Play first"
end
local hud = game:GetService("StarterGui"):FindFirstChild("Hud")
local root = hud and hud:FindFirstChild("Root")
if not root then
	return "no StarterGui.Hud.Root: nothing to replace"
end
local gone = {}
for _, name in { "ShopButton", "IndexButton", "RebirthButton", "BackpackButton", "Power", "Cash" } do
	local old = root:FindFirstChild(name)
	if old and not old:FindFirstChild("Art") then
		old:Destroy()
		table.insert(gone, name)
	end
end
game:GetService("ChangeHistoryService"):SetWaypoint("Replace HUD icons")
return "removed " .. (if #gone > 0 then table.concat(gone, ", ") else "nothing") .. ": now run uibake.luau"
