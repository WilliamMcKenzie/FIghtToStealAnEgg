-- The red fight barriers' look in game (QM, Oct 25): Shared/FightSwirl's quasicrystal (his
-- LassoAPet portal swirl) on each barrier you're locked in by, or on all of them with
-- PreviewAll ticked. Its knobs are attributes on ReplicatedStorage.FightBarrierStyle
-- (listed in Shared/FightSwirl); change them in Studio's Properties, in Edit or while
-- playing, and the barriers follow at once. (client/Barriers makes the same barriers
-- solid for you; in Edit mode the Map Baker plugin draws them.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FightSwirl = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FightSwirl"))

local NEAR = 400 -- studs: no drawing further off

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local style = ReplicatedStorage:WaitForChild("FightBarrierStyle", 10)

local swirls = {} -- [wall] = FightSwirl

local function shownFor(wall)
	local biome = player:GetAttribute("LockedIn")
	return FightSwirl.knob(style, "PreviewAll")
		or (biome ~= nil and (wall:GetAttribute("South") == biome or wall:GetAttribute("North") == biome))
end

local function drop(wall)
	if swirls[wall] then
		swirls[wall]:destroy()
		swirls[wall] = nil
	end
end

local offset = 0
local last = 0
local camera = workspace.CurrentCamera
RunService.RenderStepped:Connect(function(dt)
	offset += FightSwirl.step(style, dt)
	local markers = map:FindFirstChild("Biomes") and map.Biomes:FindFirstChild("Barriers")
	for _, wall in if markers then markers:GetChildren() else {} do
		local want = shownFor(wall)
		if want and not swirls[wall] then
			swirls[wall] = FightSwirl.new(wall)
		elseif not want and swirls[wall] then
			drop(wall)
		end
	end
	local now = os.clock()
	if now - last < 1 / math.max(FightSwirl.knob(style, "FPS"), 1) then
		return
	end
	last = now
	for wall, swirl in swirls do
		if not wall.Parent then
			drop(wall)
			continue
		end
		if (camera.CFrame.Position - wall.Position).Magnitude > NEAR then
			continue
		end
		local _, onScreen = camera:WorldToViewportPoint(wall.Position)
		if onScreen then
			swirl:draw(offset, style)
		end
	end
end)

return nil
