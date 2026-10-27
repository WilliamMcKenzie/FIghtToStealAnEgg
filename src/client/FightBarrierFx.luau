-- The red fight barriers' look in game (QM, Oct 25): Shared/BarrierSwirl's quasicrystal (his
-- LassoAPet portal swirl) on each barrier you're locked in by, or on all of them with
-- PreviewAll ticked. Its knobs are attributes on workspace.FightBarrierStyle
-- (listed in Shared/BarrierSwirl); change them in Studio's Properties, in Edit or while
-- playing, and the barriers follow at once. (client/Barriers makes the same barriers
-- solid for you; in Edit mode the Map Baker plugin draws them.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BarrierSwirl = require(Shared:WaitForChild("BarrierSwirl"))
local Config = require(Shared:WaitForChild("Config"))

local NEAR = 400 -- studs: no drawing further off

local player = Players.LocalPlayer
local map = workspace:WaitForChild("Map")
local style = workspace:WaitForChild("FightBarrierStyle", 10)

local swirls = {} -- [wall] = BarrierSwirl

-- (not where that region's buy wall is still up for you: one wall's enough, QM)
local function locked(region)
	local cost = Config.Regions.Cost[region]
	return cost ~= nil and cost > 0 and player:GetAttribute("Region" .. region) ~= true
end

local function shownFor(wall)
	if locked(wall:GetAttribute("North")) or locked(wall:GetAttribute("South")) then
		return false
	end
	local biome = player:GetAttribute("LockedIn")
	return BarrierSwirl.knob(style, "PreviewAll")
		or (biome ~= nil and (wall:GetAttribute("South") == biome or wall:GetAttribute("North") == biome))
end

local function drop(wall)
	if swirls[wall] then
		swirls[wall]:destroy()
		swirls[wall] = nil
	end
end

-- every barrier's heavy maths once, when you join (QM, Oct 25), one a frame so joining
-- doesn't hitch; a fight starting later only has to show it
task.spawn(function()
	local biomes = map:WaitForChild("Biomes", 30)
	local markers = biomes and biomes:WaitForChild("Barriers", 30)
	for _, wall in if markers then markers:GetChildren() else {} do
		if wall:IsA("BasePart") and not swirls[wall] then
			local swirl = BarrierSwirl.new(wall)
			swirl:show(false)
			swirls[wall] = swirl
			swirl:prepare(style)
			task.wait()
		end
	end
end)

local offset = 0
local last = 0
local checked = 0
local camera = workspace.CurrentCamera
RunService.RenderStepped:Connect(function(dt)
	offset += BarrierSwirl.step(style, dt)
	local now = os.clock()
	-- (which barriers show: ten times a second is plenty, QM Oct 27)
	local markers = now - checked >= 0.1 and map:FindFirstChild("Biomes") and map.Biomes:FindFirstChild("Barriers")
	if markers then
		checked = now
	end
	for _, wall in if markers then markers:GetChildren() else {} do
		local want = shownFor(wall)
		BarrierSwirl.shadows(wall, style, want)
		-- (made the first time it's wanted, then only hidden: making one is the costly bit)
		if want and not swirls[wall] then
			swirls[wall] = BarrierSwirl.new(wall)
		end
		if swirls[wall] then
			swirls[wall]:show(want)
		end
	end
	if now - last < 1 / math.max(BarrierSwirl.knob(style, "FPS"), 1) then
		return
	end
	last = now
	for wall, swirl in swirls do
		if not wall.Parent then
			drop(wall)
			continue
		end
		if not swirl.shown then
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
