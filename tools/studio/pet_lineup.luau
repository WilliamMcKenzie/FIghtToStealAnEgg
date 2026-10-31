-- (QM, Oct 31) Builds the pet lineup in the base's dirt patch (Shared/PetLineup) and keeps
-- it following workspace.PetScale until Studio closes. Run in Studio's command bar in Edit
-- mode, or `python3 lu.py pet_lineup.luau`, after syncing src/. Re-runnable: it rebuilds
-- the lineup where it stands. (The Map Baker plugin's "Pet Lineup" button does the same,
-- and keeps it following after Studio restarts.) Save the place after.
local ServerStorage = game:GetService("ServerStorage")

if _G.PetLineupWatch then
	_G.PetLineupWatch:Disconnect()
	_G.PetLineupWatch = nil
end
-- (a fresh copy of Shared: a module required here stays cached, so the original could be stale)
local tmp = Instance.new("Folder")
tmp.Name = "PetLineupTemp"
game:GetService("ReplicatedStorage").Shared:Clone().Parent = tmp
tmp.Parent = ServerStorage
local ok, err = pcall(function()
	local PetLineup = require(tmp.Shared.PetLineup)
	PetLineup.build()
	_G.PetLineupWatch = PetLineup.watch()
end)
tmp.Parent = nil -- (kept alive for the watcher, not saved with the place)
if not ok then
	warn("[Pet lineup] " .. tostring(err))
else
	print("[Pet lineup] built: change workspace.PetScale to resize, tick CopyValues to print them")
end
