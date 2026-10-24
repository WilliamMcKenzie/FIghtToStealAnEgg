-- Rebuilds workspace.Map in Edit mode from Shared/MapData, as the Map Baker plugin's Rebuild
-- button does (tools/studio/MapBaker.lua). Run with lu.py in Edit; tools/mapeditor/serve.py
-- runs it after every save.
if game:GetService("RunService"):IsRunning() then
	return "playing: stop Play first"
end
local ServerStorage = game:GetService("ServerStorage")
-- (fresh copies of Server.Map and Shared side by side: required modules stay cached)
local tmp = Instance.new("Folder")
tmp.Name = "MapBakerTemp"
game:GetService("ReplicatedStorage").Shared:Clone().Parent = tmp
game:GetService("ServerScriptService").Server.Map:Clone().Parent = tmp
tmp.Parent = ServerStorage
local ok, res = pcall(function()
	local map = require(tmp.Map).build()
	local parts = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return parts
end)
tmp:Destroy()
return if ok then "baked " .. res .. " parts" else "error: " .. tostring(res)
