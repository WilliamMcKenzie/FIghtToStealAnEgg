-- One egg per player per round (QM, Oct 31): once you've taken an egg from a biome's
-- nests, its other nest eggs' Steal prompts are hidden for you until the next refill.
-- The server (Server/Eggs) enforces it and sets your TookEgg<Biome> attribute; this just
-- turns those prompts off on your screen while it's set.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function key(biome)
	return "TookEgg" .. string.gsub(biome, "[^%w_]", "")
end

local function apply(box)
	local biome = box:GetAttribute("Biome")
	local prompt = box:FindFirstChildOfClass("ProximityPrompt")
	if not (biome and prompt and box.Parent and CollectionService:HasTag(box.Parent, "Nest")) then
		return
	end
	if box:GetAttribute("Vanish") then
		return
	end
	prompt.Enabled = not player:GetAttribute(key(biome))
end

local function add(box)
	box.ChildAdded:Connect(function(child)
		if child:IsA("ProximityPrompt") then
			apply(box)
		end
	end)
	box.AncestryChanged:Connect(function()
		apply(box)
	end)
	apply(box)
end

CollectionService:GetInstanceAddedSignal("Egg"):Connect(add)
for _, box in CollectionService:GetTagged("Egg") do
	task.spawn(add, box)
end

player.AttributeChanged:Connect(function(name)
	if string.sub(name, 1, 7) ~= "TookEgg" then
		return
	end
	for _, box in CollectionService:GetTagged("Egg") do
		apply(box)
	end
end)

return nil
