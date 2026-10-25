-- Draws every egg (QM, Oct 25): the server only has an invisible box where each egg stands
-- (tagged "Egg": in a nest, on a back, in a pen; Server/Eggs), with its animal in EggKind
-- and its size in EggScale. Here each gets LassoAPet's egg for that animal (Shared/Eggs),
-- stood on the box's bottom face and following it, twitching now and then while it waits
-- (its AFK animation; the hatch one is there for when hatching comes).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Egg = require(Shared.Eggs.Egg)

local TWITCH = Config.Eggs.Twitch

local views = {} -- [box] = { egg, next twitch (clock) }

local function add(box)
	if views[box] or not box:IsA("BasePart") then
		return
	end
	local ok, egg = pcall(Egg.new, box:GetAttribute("EggKind") or "Pig", box:GetAttribute("EggScale") or 1)
	if not ok then
		warn("EggView: " .. tostring(egg))
		return
	end
	for _, part in egg.model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	egg.model.Parent = workspace
	views[box] = { egg = egg, nextTwitch = os.clock() + math.random() * TWITCH[2] }
end

local function remove(box)
	local view = views[box]
	views[box] = nil
	if view then
		view.egg.model:Destroy()
	end
end

CollectionService:GetInstanceAddedSignal("Egg"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Egg"):Connect(remove)
for _, box in CollectionService:GetTagged("Egg") do
	add(box)
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for box, view in views do
		if not box.Parent then
			remove(box)
			continue
		end
		local egg = view.egg
		egg.model:PivotTo(box.CFrame * CFrame.new(0, -box.Size.Y / 2, 0))
		if now >= view.nextTwitch then
			egg:play("twitch")
			view.nextTwitch = now + TWITCH[1] + math.random() * (TWITCH[2] - TWITCH[1])
		end
		egg:update(dt)
	end
end)

return nil
