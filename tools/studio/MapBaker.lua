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
rebuild.ClickableWhenViewportHidden = true
import.ClickableWhenViewportHidden = true

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

-- ---- the studs' fade, in Edit mode ---------------------------------------------------------
-- (QM, Oct 30) workspace.StudStyle's Transparency is every stud Texture's, in Edit mode too:
-- this makes the knob when the place has none (seeded from Config.StudTransparency) and
-- repaints the place whenever it changes. During Play, Shared/StudStyle does the same.
local STUD_IMAGE = "rbxassetid://7447638591"
local studStyle, studConn = nil, nil

local function studSeed()
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local module = shared and shared:FindFirstChild("Config")
	if module and module:IsA("ModuleScript") then
		local ok, config = pcall(require, module:Clone())
		if ok and type(config) == "table" and type(config.StudTransparency) == "number" then
			return config.StudTransparency
		end
	end
	return 0.5
end

local function studPaint()
	local value = studStyle and studStyle:GetAttribute("Transparency")
	if typeof(value) ~= "number" or RunService:IsRunning() then
		return
	end
	local count = 0
	for _, thing in workspace:GetDescendants() do
		if thing:IsA("Texture") and thing.Texture == STUD_IMAGE and thing.Transparency ~= value then
			thing.Transparency = value
			count += 1
		end
	end
	if count > 0 then
		print(string.format("[Map Baker] StudStyle: %d stud textures at Transparency %s", count, tostring(value)))
	end
end

local function studHook()
	if RunService:IsRunning() then
		return
	end
	local style = workspace:FindFirstChild("StudStyle")
	if not style then
		style = Instance.new("Configuration")
		style.Name = "StudStyle"
		style:SetAttribute("Transparency", studSeed())
		style.Parent = workspace
	elseif typeof(style:GetAttribute("Transparency")) ~= "number" then
		style:SetAttribute("Transparency", studSeed())
	end
	if style ~= studStyle then
		if studConn then
			studConn:Disconnect()
		end
		studStyle = style
		studConn = style:GetAttributeChangedSignal("Transparency"):Connect(studPaint)
	end
	studPaint()
end

task.defer(studHook)
workspace.ChildAdded:Connect(function(child)
	if child.Name == "StudStyle" then
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
