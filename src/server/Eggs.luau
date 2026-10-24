-- Eggs and the fight they start (QM, Oct 24). Every nest round a biome's edges holds an
-- egg. Hold E to steal it: it rides on your back, the biome's boss wakes, and you're
-- locked into its fight (player attribute LockedIn = the biome): red barriers across its
-- ways out, drawn and solid only for you (client/Barriers.luau), keep you in until the
-- boss is dead. Anyone who hits the boss is locked in too, so a group fights it together.
-- With the boss dead everyone in its fight goes free; carry the egg into your pen for
-- its reward (Config.Eggs.Reward). Die holding an egg and it's lost (and you're out of
-- the fight). A nest lays again Config.Eggs.Respawn seconds after it's robbed.
--
-- Player attributes: HeldEgg (biome name), LockedIn (biome name), Eggs (eggs brought home).
--
--   Eggs.start(map)   -- once, after Map.build()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Bosses = require(script.Parent.Bosses)
local Map = require(script.Parent.Map)
local Pens = require(script.Parent.Pens)

local Eggs = {}

local carried = {} -- [player] = egg part on their back

-- an egg: an oval, shell coloured by its biome, a few spots
function Eggs.make(biome)
	local egg = Instance.new("Part")
	egg.Name = biome .. "Egg"
	egg.Size = Config.Eggs.Size
	egg.Material = Enum.Material.SmoothPlastic
	egg.Color = Config.Eggs.Colors[biome] or Config.WorldColors.Egg
	egg.CanCollide = false
	egg.CanTouch = false
	egg.Massless = true
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere -- (stretched to the part's size: an oval)
	mesh.Parent = egg
	egg:SetAttribute("Biome", biome)
	return egg
end

local function lock(player, biome)
	if player:GetAttribute("LockedIn") ~= biome then
		player:SetAttribute("LockedIn", biome)
	end
end

local function drop(player)
	local egg = carried[player]
	carried[player] = nil
	if egg then
		egg:Destroy()
	end
	player:SetAttribute("HeldEgg", nil)
end

local function carry(player, biome)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local egg = Eggs.make(biome)
	egg.Anchored = false
	egg.CFrame = root.CFrame * CFrame.new(0, 3.2, 1.4) * CFrame.Angles(math.rad(-15), 0, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, egg
	weld.Parent = egg
	egg.Parent = player.Character
	carried[player] = egg
	player:SetAttribute("HeldEgg", biome)
	return true
end

-- a nest's egg and its prompt; robbed, it lays again after a while
local function lay(nest, biome)
	local x, z = nest:GetAttribute("EggX"), nest:GetAttribute("EggZ")
	local egg = Eggs.make(biome)
	egg.Anchored = true
	egg.CFrame = CFrame.new(x, 1 + egg.Size.Y / 2, z)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Steal"
	prompt.ObjectText = biome .. " Egg"
	prompt.HoldDuration = Config.Eggs.StealTime
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = egg
	egg.Parent = nest
	prompt.Triggered:Connect(function(player)
		if not egg.Parent or player:GetAttribute("HeldEgg") then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not (humanoid and humanoid.Health > 0) or not carry(player, biome) then
			return
		end
		egg:Destroy()
		-- (with its boss dead and not yet back, there's no fight: the egg's yours)
		if Bosses.alive(biome) then
			lock(player, biome)
			Bosses.wake(biome)
		end
		task.delay(Config.Eggs.Respawn, lay, nest, biome)
	end)
end

-- inside a pen's Area box (flat)
local function inside(part, position)
	local p = part.CFrame:PointToObjectSpace(position)
	return math.abs(p.X) <= part.Size.X / 2 and math.abs(p.Z) <= part.Size.Z / 2
end

function Eggs.start(map)
	for _, biome in map.Biomes:GetChildren() do
		local nests = biome:FindFirstChild("Nests")
		for _, nest in if nests then nests:GetChildren() else {} do
			lay(nest, biome.Name)
		end
		local spot = biome:FindFirstChild("BossSpot")
		local area = Map.area(biome.Name)
		if spot and area then
			Bosses.arena(biome.Name, spot.Position, area.Bounds)
		end
	end

	-- hitting a boss locks you into its fight; its death frees everyone in it
	Bosses.engaged.Event:Connect(lock)
	Bosses.defeated.Event:Connect(function(biome)
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("LockedIn") == biome then
				player:SetAttribute("LockedIn", nil)
			end
		end
	end)

	local function joined(player)
		player.CharacterAdded:Connect(function(character)
			-- (a new life: whatever you were carrying or fighting is gone)
			drop(player)
			player:SetAttribute("LockedIn", nil)
			local humanoid = character:WaitForChild("Humanoid")
			humanoid.Died:Connect(function()
				drop(player)
				player:SetAttribute("LockedIn", nil)
			end)
		end)
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		drop(player)
	end)

	-- bringing an egg home: free of the fight and inside your own pen
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < 0.25 then
			return
		end
		clock = 0
		for player, egg in carried do
			local biome = player:GetAttribute("HeldEgg")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local pen = Pens.of(player)
			local area = pen and pen:FindFirstChild("Area")
			if biome and root and area and not player:GetAttribute("LockedIn") and inside(area, root.Position) then
				carried[player] = nil
				egg:Destroy()
				player:SetAttribute("HeldEgg", nil)
				player:SetAttribute("Eggs", (player:GetAttribute("Eggs") or 0) + 1)
				player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + (Config.Eggs.Reward[biome] or 0))
				Pens.addEgg(player, biome, Eggs.make)
			end
		end
	end)
end

return Eggs
