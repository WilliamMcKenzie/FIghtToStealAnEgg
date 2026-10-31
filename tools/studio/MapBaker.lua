-- Map Baker (QM, Oct 24): a Studio plugin that bakes the map into the place in Edit mode,
-- so it's there to see and save without pressing Play.
--
-- Install: copy this file into Studio's plugins folder (Plugins tab > Plugins Folder;
-- on a Mac ~/Documents/Roblox/Plugins) and restart Studio. A "Map" toolbar appears:
--   Rebuild     bakes Shared/MapData (maps/world.map, as synced from the repo)
--   Import .map bakes a .map straight from disk (a download from the map editor), to
--               look at before it goes in the repo (tools/map_bake.py)
-- Either replaces workspace.Map (one undo step). Save the place afterwards. The game
-- plays on the baked map (Server/Map.ensure).

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StudioService = game:GetService("StudioService")

local toolbar = plugin:CreateToolbar("Map")
local rebuild = toolbar:CreateButton("MapBakerRebuild", "Bake Shared/MapData into workspace.Map", "", "Rebuild")
local import = toolbar:CreateButton("MapBakerImport", "Bake a .map file from disk into workspace.Map", "", "Import .map")
local petLineup = toolbar:CreateButton("MapBakerPetLineup", "Line up every pet in the base, sized by workspace.PetScale", "", "Pet Lineup")
rebuild.ClickableWhenViewportHidden = true
import.ClickableWhenViewportHidden = true
petLineup.ClickableWhenViewportHidden = true

-- Fresh copies of Server.Map and Shared, side by side (Map finds Shared beside it): a
-- module required from a plugin stays cached, so the originals would bake stale code.
local function fresh()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local server = ServerScriptService:FindFirstChild("Server")
	local mapModule = server and server:FindFirstChild("Map")
	assert(shared and mapModule, "needs ReplicatedStorage.Shared and ServerScriptService.Server.Map (sync src/ first)")
	local tmp = Instance.new("Folder")
	tmp.Name = "MapBakerTemp"
	shared:Clone().Parent = tmp
	mapModule:Clone().Parent = tmp
	tmp.Parent = ServerStorage
	return tmp
end

local function bake(label, text)
	if RunService:IsRunning() then
		warn("[Map Baker] stop Play first: the map is baked in Edit mode")
		return
	end
	local recording = ChangeHistoryService:TryBeginRecording(label)
	local tmp
	local ok, err = pcall(function()
		tmp = fresh()
		local Map = require(tmp.Map)
		local data = nil
		if text then
			data = require(tmp.Shared.MapFile).decode(text)
		end
		local started = os.clock()
		local map = Map.build(data)
		local parts = 0
		for _, d in map:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		print(string.format("[Map Baker] baked workspace.Map: %d parts in %.1fs. Save the place to keep it.", parts, os.clock() - started))
	end)
	if tmp then
		tmp:Destroy()
	end
	if recording then
		ChangeHistoryService:FinishRecording(
			recording,
			if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end
	if not ok then
		warn("[Map Baker] " .. tostring(err))
	end
end

rebuild.Click:Connect(function()
	rebuild:SetActive(false)
	bake("Bake map")
end)

import.Click:Connect(function()
	import:SetActive(false)
	local ok, file = pcall(StudioService.PromptImportFileAsync, StudioService, { "map", "json", "txt" })
	if not ok then
		-- (a type filter Studio doesn't take: pick any file)
		ok, file = pcall(StudioService.PromptImportFileAsync, StudioService)
	end
	if not ok then
		warn("[Map Baker] couldn't open the file picker: " .. tostring(file))
		return
	end
	if not file then
		return
	end
	print("[Map Baker] importing " .. file.Name)
	bake("Import " .. file.Name, file:GetBinaryContents())
	print("[Map Baker] to keep it in the game, send " .. file.Name .. " over to go in the repo (maps/world.map)")
end)

-- ---- the fight barriers' quasicrystal, in Edit mode ----------------------------------------
-- (QM, Oct 25: to see the red barriers as they'll look without pressing Play) Shared/
-- BarrierSwirl drawn on the first barrier in workspace.Map only (the base's gate: more
-- lags Studio, QM), its knobs live from
-- workspace.FightBarrierStyle. Its SurfaceGuis live in CoreGui, so nothing is
-- added to the place. A fresh copy of BarrierSwirl is required whenever the synced one
-- changes, so an update shows without restarting Studio.
local CoreGui = game:GetService("CoreGui")
local preview = Instance.new("Folder")
preview.Name = "BarrierSwirlPreview"
preview.Parent = CoreGui

local swirlModule, BarrierSwirl, swirlSource = nil, nil, nil
local function swirlCode()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("BarrierSwirl")
	if not (module and module:IsA("ModuleScript")) then
		return nil
	end
	if module ~= swirlModule or module.Source ~= swirlSource then
		local ok, loaded = pcall(require, module:Clone())
		swirlModule, swirlSource = module, module.Source
		BarrierSwirl = if ok then loaded else nil
		return BarrierSwirl, true
	end
	return BarrierSwirl, false
end

local swirls = {} -- [wall] = BarrierSwirl
local function clear()
	for wall, swirl in swirls do
		swirl:destroy()
		swirls[wall] = nil
	end
end

local offset, last = 0, 0
local beat
beat = RunService.Heartbeat:Connect(function(dt)
	if not preview.Parent then
		-- (its folder was taken away: a newer copy of this took over)
		beat:Disconnect()
		clear()
		return
	end
	if RunService:IsRunning() then
		clear()
		return
	end
	local code, changed = swirlCode()
	if changed then
		clear()
	end
	if not code then
		return
	end
	local style = workspace:FindFirstChild("FightBarrierStyle")
	offset += code.step(style, dt)
	local now = os.clock()
	if now - last < 1 / math.max(code.knob(style, "FPS"), 1) then
		return
	end
	last = now
	local map = workspace:FindFirstChild("Map")
	local markers = map and map:FindFirstChild("Biomes") and map.Biomes:FindFirstChild("Barriers")
	local seen = {}
	-- (just the base's gate into the Meadow, or else the first one)
	local list = if markers then markers:GetChildren() else {}
	-- (every barrier's floor shadow follows the style; cheap, so all of them)
	if code.shadows then
		for _, wall in list do
			code.shadows(wall, style, true)
		end
	end
	local first = nil
	for _, wall in list do
		if wall:IsA("BasePart") and (first == nil or wall:GetAttribute("South") == "Base") then
			first = wall
		end
	end
	for _, wall in { first } do
		if wall then
			seen[wall] = true
			swirls[wall] = swirls[wall] or code.new(wall, preview)
			local ok, err = pcall(swirls[wall].draw, swirls[wall], offset, style)
			if not ok then
				warn("[Map Baker] fight barrier preview: " .. tostring(err))
				clear()
				return
			end
		end
	end
	for wall, swirl in swirls do
		if not seen[wall] then
			swirl:destroy()
			swirls[wall] = nil
		end
	end
end)

-- ---- the studs, in Edit mode ---------------------------------------------------------------
-- (QM, Oct 30) workspace.StudStyle's knobs (ground and everything else: Transparency and
-- TileScale) hold for every stud Texture in Edit mode too: this makes them when the place
-- has none and repaints the place (Shared/StudStyle, a fresh copy each time, so an update
-- shows without restarting Studio) whenever one changes or the map is baked. During Play,
-- Shared/StudStyle does the same itself.
local studStyle, studConn = nil, nil

local function studCode()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("StudStyle")
	if not (module and module:IsA("ModuleScript")) then
		return nil, nil
	end
	local tmp = Instance.new("Folder")
	tmp.Name = "StudStyleTemp"
	local copy = module:Clone()
	copy.Parent = tmp
	local config = shared:FindFirstChild("Config")
	if config then
		config:Clone().Parent = tmp
	end
	local ok, code = pcall(require, copy)
	return if ok then code else nil, tmp
end

local function studPaint()
	if RunService:IsRunning() then
		return
	end
	local code, tmp = studCode()
	if code then
		local ok, err = pcall(function()
			code.ensure()
			code.applyAll()
		end)
		if not ok then
			warn("[Map Baker] StudStyle: " .. tostring(err))
		end
	end
	if tmp then
		tmp:Destroy()
	end
end

local function studHook()
	if RunService:IsRunning() then
		return
	end
	studPaint() -- (makes workspace.StudStyle if it's missing)
	local style = workspace:FindFirstChild("StudStyle")
	if style and style ~= studStyle then
		if studConn then
			studConn:Disconnect()
		end
		studStyle = style
		studConn = style.AttributeChanged:Connect(studPaint)
	end
end

task.defer(studHook)
workspace.ChildAdded:Connect(function(child)
	if child.Name == "StudStyle" or child.Name == "Map" then
		task.defer(studHook)
	end
end)
workspace.ChildRemoved:Connect(function(child)
	if child == studStyle then
		studStyle = nil
		if studConn then
			studConn:Disconnect()
			studConn = nil
		end
	end
end)

-- ---- the pet lineup, in Edit mode ----------------------------------------------------------
-- (QM, Oct 31) Pet Lineup (re)builds every pet in the base's dirt patch (Shared/PetLineup,
-- from a fresh copy of Shared); while workspace.PetLineup is there, changing a pet's
-- workspace.PetScale resizes it in the lineup, and ticking CopyValues prints the values as a
-- Config.AnimalScale line.
local lineupConn, lineupTmp = nil, nil

local function lineupCode()
	if lineupConn then
		lineupConn:Disconnect()
		lineupConn = nil
	end
	if lineupTmp then
		lineupTmp:Destroy()
		lineupTmp = nil
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	if not (shared and shared:FindFirstChild("PetLineup")) then
		return nil
	end
	lineupTmp = Instance.new("Folder")
	lineupTmp.Name = "PetLineupTemp"
	shared:Clone().Parent = lineupTmp
	lineupTmp.Parent = ServerStorage
	local ok, code = pcall(require, lineupTmp.Shared.PetLineup)
	lineupTmp.Parent = nil -- (kept for the watcher, not saved with the place)
	if not ok then
		warn("[Map Baker] PetLineup: " .. tostring(code))
		return nil
	end
	return code
end

local function lineupHook(rebuildIt)
	if RunService:IsRunning() then
		return
	end
	local code = lineupCode()
	if not code then
		return
	end
	local ok, err = pcall(function()
		if rebuildIt then
			code.build()
		end
		lineupConn = code.watch()
	end)
	if not ok then
		warn("[Map Baker] PetLineup: " .. tostring(err))
	end
end

petLineup.Click:Connect(function()
	local recording = ChangeHistoryService:TryBeginRecording("Pet Lineup")
	lineupHook(true)
	if recording then
		ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	end
end)
task.defer(function()
	if workspace:FindFirstChild("PetLineup") then
		lineupHook(false)
	end
end)
