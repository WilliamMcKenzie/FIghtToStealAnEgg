-- The six pens (two rows of three either side of the spawn; QM, Oct 24: 6 players a
-- server). Each player who joins gets the first free one (player attribute Pen) and its
-- sign shows their name; the eggs they bring home sit in rows inside it.
--
--   Pens.start(map)                       -- once, after Map.ensure()
--   Pens.of(player) -> the pen Model or nil
--   Pens.addEgg(player, makeEgg)   -- one more egg sat in their pen (makeEgg() -> its box)
--   Pens.addPet(player, kind)      -- a pet wandering in their pen (the /give command)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pets = require(Shared:WaitForChild("Pets"))
local Horse = require(Shared:WaitForChild("Animals"):WaitForChild("Horse"))

local Pens = {}

local pens = {} -- [index] = Model
local owners = {} -- [index] = player

local function setSign(pen, text)
	local sign = pen:FindFirstChild("OwnerSign")
	local board = sign and sign:FindFirstChild("Board")
	if board then
		for _, gui in board:GetChildren() do
			local label = gui:FindFirstChild("Text")
			if label then
				label.Text = text
			end
		end
	end
end

function Pens.of(player)
	local i = player:GetAttribute("Pen")
	return i and pens[i]
end

local function clearEggs(pen)
	local shown = pen:FindFirstChild("Eggs")
	if shown then
		shown:ClearAllChildren()
	end
end

function Pens.addEgg(player, makeEgg)
	local pen = Pens.of(player)
	local area = pen and pen:FindFirstChild("Area")
	if not area then
		return
	end
	local shown = pen:FindFirstChild("Eggs")
	if not shown then
		shown = Instance.new("Folder")
		shown.Name = "Eggs"
		shown.Parent = pen
	end
	local n = #shown:GetChildren()
	if n >= Config.Eggs.PenShows then
		shown:GetChildren()[1]:Destroy()
		n -= 1
	end
	-- (rows of 6, from the back of the pen)
	local col, row = n % 6, n // 6
	local half = area.Size.X / 2 - 8
	local egg = makeEgg()
	egg.Anchored = true
	local floor = area.Position.Y - area.Size.Y / 2 -- (the pen's floor: its Area marker's bottom)
	egg.CFrame = CFrame.new(
		area.Position.X - half + col * (2 * half / 5),
		floor + egg.Size.Y / 2,
		area.Position.Z - half + row * 7
	)
	egg.Parent = shown
end

-- Pets sat in your pen (QM, Oct 25: /give, until hatching), wandering about inside it:
-- each an invisible body in workspace.PenPets that client/BossView draws (Model is the
-- pet's kind, ModelSize its size), like the training mobs.
local petFolder = Instance.new("Folder")
petFolder.Name = "PenPets"
petFolder.Parent = workspace
local penPets = {} -- [body] = { owner, area, yaw, goal, wait, speed, rng }
local MAX_PETS = 12 -- most pets wandering a pen

function Pens.addPet(player, kind)
	local pen = Pens.of(player)
	local area = pen and pen:FindFirstChild("Area")
	if not area then
		return false
	end
	local class = Pets.class(kind)
	local count = 0
	local oldest = nil
	for body, p in penPets do
		if p.owner == player then
			count += 1
			oldest = oldest or body
		end
	end
	if count >= MAX_PETS and oldest then
		penPets[oldest] = nil
		oldest:Destroy()
	end
	local box = Horse.extent(class.data) * class.size
	local floor = area.Position.Y - area.Size.Y / 2
	local body = Instance.new("Part")
	body.Name = kind .. "Pet"
	body.Anchored, body.CanCollide, body.CanTouch, body.CanQuery = true, false, false, false
	body.Transparency = 1
	body.Size = Vector3.new(math.max(box.X, 1), math.max(box.Y, 1), math.max(box.Z, 1))
	local rng = Random.new()
	local half = area.Size.X / 2 - 8
	body.CFrame = CFrame.new(
		area.Position.X + rng:NextNumber(-half, half),
		floor + body.Size.Y / 2,
		area.Position.Z + rng:NextNumber(-half, half)
	)
	body:SetAttribute("Model", kind)
	body:SetAttribute("ModelSize", class.size)
	body:SetAttribute("Name", Pets.name(kind))
	body:SetAttribute("Owner", player.UserId)
	penPets[body] = { owner = player, area = area, yaw = rng:NextNumber(-math.pi, math.pi), wait = rng:NextNumber(0, 2), speed = 4, rng = rng }
	body.Parent = petFolder
	return true
end

local function clearPets(player)
	for body, p in penPets do
		if p.owner == player then
			penPets[body] = nil
			body:Destroy()
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	for body, p in penPets do
		if p.wait > 0 then
			p.wait -= dt
			continue
		end
		local pos = body.Position
		if not p.goal then
			local half = p.area.Size.X / 2 - 8
			p.goal = Vector3.new(
				p.area.Position.X + p.rng:NextNumber(-half, half),
				pos.Y,
				p.area.Position.Z + p.rng:NextNumber(-half, half)
			)
		end
		local offset = (p.goal - pos) * Vector3.new(1, 0, 1)
		if offset.Magnitude < 0.5 then
			p.goal = nil
			p.wait = p.rng:NextNumber(1, 5)
			continue
		end
		local want = math.atan2(-offset.X, -offset.Z)
		p.yaw += ((want - p.yaw + math.pi) % (2 * math.pi) - math.pi) * (1 - math.exp(-dt * 5))
		pos += offset.Unit * math.min(p.speed * dt, offset.Magnitude)
		body.CFrame = CFrame.new(pos) * CFrame.Angles(0, p.yaw, 0)
	end
end)

function Pens.start(map)
	for _, pen in map.Base.Pens:GetChildren() do
		pens[pen:GetAttribute("Index")] = pen
	end
	local function joined(player)
		for i = 1, #pens do
			if not owners[i] then
				owners[i] = player
				player:SetAttribute("Pen", i)
				setSign(pens[i], player.DisplayName .. "'s Pen")
				return
			end
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for i, owner in owners do
			if owner == player then
				owners[i] = nil
				setSign(pens[i], "")
				clearEggs(pens[i])
				clearPets(player)
			end
		end
	end)
end

return Pens
