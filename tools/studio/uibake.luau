-- Puts the game's UI into StarterGui as real objects, for QM to edit in Studio (client/Ui):
-- runs client/Hud's building code (just the boss bar since the Oct 27 UI wipe) in Edit mode.
-- Only adds what's missing, so it never undoes QM's edits: run it again after the UI code
-- gains new pieces. Run with lu.py in Edit (sync src/ first), then save the place.
if game:GetService("RunService"):IsRunning() then
	return "playing: stop Play first"
end
local StarterGui = game:GetService("StarterGui")
local client = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Client")
if not client then
	return "no StarterPlayerScripts.Client: sync src/ first"
end
local before = StarterGui:FindFirstChild("Hud")
local count = if before then #before:GetDescendants() else 0
-- (a fresh copy of the client modules: required modules stay cached, so the originals would
-- bake stale code)
local tmp = Instance.new("Folder")
tmp.Name = "UiBakeTemp"
local copy = Instance.new("Folder")
copy.Name = "Client"
for _, m in client:GetChildren() do
	if m:IsA("ModuleScript") then
		m:Clone().Parent = copy
	end
end
copy.Parent = tmp
tmp.Parent = game:GetService("ServerStorage")
-- (Shared too: its modules stay cached the same way, so a fresh copy stands in for it while
-- baking, and the real one goes back after)
local RS = game:GetService("ReplicatedStorage")
local shared = RS:FindFirstChild("Shared")
local fresh = shared and shared:Clone()
if fresh then
	shared.Parent = nil
	fresh.Parent = RS
end
local ok, res = pcall(function()
	return require(copy.Hud).start()
end)
if fresh then
	fresh:Destroy()
	shared.Parent = RS
end
tmp:Destroy()
if not ok then
	return "error: " .. tostring(res)
end
game:GetService("ChangeHistoryService"):SetWaypoint("Bake UI")
local added = #res:GetDescendants() - count
return string.format("StarterGui.Hud: %d objects (%d added)", #res:GetDescendants(), added)
