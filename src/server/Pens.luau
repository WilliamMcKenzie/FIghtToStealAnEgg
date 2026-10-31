-- The six pens (two rows of three either side of the spawn; QM, Oct 24: 6 players a
-- server). Each player who joins gets the first free one (player attribute Pen) and its
-- sign shows their name; the eggs they bring home sit in rows inside it.
--
--   Pens.start(map)                       -- once, after Map.ensure()
--   Pens.of(player) -> the pen Model or nil
--   Pens.addEgg(player, makeEgg)   -- one more egg sat in their pen (makeEgg() -> its box)
--   Pens.setPets(player, kinds)    -- these pets wandering in their pen (the ones they
--                                  -- equipped in the Backpack: Server/PetInventory)
--   Pens.clear(player)             -- no eggs or pets in it (the /reset command)
--   Pens.facing(pen) -> yaw        -- out of the pen, toward its gate (LassoAPet's facing)
--   Pens.hatching(player, kind, at, popAt, from) -- the next pet of this kind to come into
--                                  -- their pen jumps out of the egg hatching at `at`
--   Pens.mountSpot(player, body) -> CFrame or nil -- where their rider goes to sit on this
--                                  -- pen pet of theirs just as it stands (QM, Oct 30: ride
--                                  -- the pet where it is, no teleporting)
--   Pens.dismountAt(player, kind, cframe) -- the next pet of this kind to come into their
--                                  -- pen stands here (the one they got off), not anywhere
--   (every spawn, on join and after dying, puts the player in front of their own pen's
--   gate facing it: Shared/PenSpawn; client/SpawnCam turns the camera to match)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pets = require(Shared:WaitForChild("Pets"))
local Horse = require(Shared:WaitForChild("Animals"):WaitForChild("Horse"))
local PenSpawn = require(Shared:WaitForChild("PenSpawn"))

local Pens = {}

local pens = {} -- [index] = Model
local owners = {} -- [index] = player

-- who owns it, for client/PenCards: OwnerId (a UserId) and OwnerName (@name), or neither
local function setOwner(pen, player)
	pen:SetAttribute("OwnerId", player and player.UserId)
	pen:SetAttribute("OwnerName", player and player.Name)
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

-- Pets in your pen (QM, Oct 25: the ones equipped in your Backpack), wandering about
-- inside it: each an invisible body in workspace.PenPets that client/BossView draws (Model is the
-- pet's kind, ModelSize its size), like the training mobs.
local petFolder = Instance.new("Folder")
petFolder.Name = "PenPets"
petFolder.Parent = workspace
local penPets = {} -- [body] = { owner, area, yaw, goal, wait, speed, rng }

-- The pens' eggs and pets face out of the pen, toward its gate (where its owner's name
-- floats: Server/Map), as LassoAPet's face its open side. Yaw 0 faces -z.
function Pens.facing(pen)
	local area = pen:FindFirstChild("Area")
	local sign = pen:FindFirstChild("OwnerSign")
	local board = sign and sign:FindFirstChild("Board")
	if not (area and board) then
		return 0
	end
	local d = board.Position - area.Position
	return math.atan2(-d.X, -d.Z)
end

-- A hatched pet comes into the pen where its egg stood, facing out, and holds still there
-- while the client draws it jumping out of the egg (BossView: the body's HatchPop, the
-- server time it pops out, and HatchFrom, the egg's middle in studs, where it jumps from).
local hatches = {} -- [player] = { { kind, at, popAt, from, expires } }

function Pens.hatching(player, kind, at, popAt, from)
	hatches[player] = hatches[player] or {}
	table.insert(hatches[player], { kind = kind, at = at, popAt = popAt, from = from, expires = os.clock() + 5 })
end

local function takeHatch(player, kind)
	local list = hatches[player]
	for i, h in list or {} do
		if h.kind == kind and os.clock() < h.expires then
			table.remove(list, i)
			return h
		end
	end
	return nil
end

local dismounts = {} -- [player] = { kind, cframe, expires }

function Pens.mountSpot(player, body)
	local p = penPets[body]
	if not p or p.owner ~= player then
		return nil
	end
	p.mounted = true -- (this one goes, not another of its kind: setPets)
	local class = Pets.class(p.kind)
	local seat = class.seat * class.size
	local floor = body.Position.Y - body.Size.Y / 2
	-- (the rider's root over the pet's seat: client/Riding puts the pet's feet under it
	-- seat studs back, so the pet lands right where it stood, facing the same way)
	return CFrame.new(body.Position.X, floor, body.Position.Z) * CFrame.Angles(0, p.yaw, 0) * CFrame.new(seat.X, 0, seat.Z)
end

function Pens.dismountAt(player, kind, cframe)
	dismounts[player] = { kind = kind, cframe = cframe, expires = os.clock() + 2 }
end

local function spawnPet(player, area, kind)
	local class = Pets.class(kind)
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
	local yaw, wait = rng:NextNumber(-math.pi, math.pi), rng:NextNumber(0, 2)
	local hatch = takeHatch(player, kind)
	local off = dismounts[player]
	if off and off.kind == kind and os.clock() < off.expires then
		-- (the one just got off: standing where it was ridden, in the pen)
		dismounts[player] = nil
		local _, y = off.cframe:ToOrientation()
		local x = math.clamp(off.cframe.X, area.Position.X - half, area.Position.X + half)
		local z = math.clamp(off.cframe.Z, area.Position.Z - half, area.Position.Z + half)
		yaw, wait = y, rng:NextNumber(1, 3)
		body.CFrame = CFrame.new(x, floor + body.Size.Y / 2, z) * CFrame.Angles(0, yaw, 0)
	elseif hatch then
		yaw = Pens.facing(area.Parent)
		body.CFrame = CFrame.new(hatch.at.X, floor + body.Size.Y / 2, hatch.at.Z) * CFrame.Angles(0, yaw, 0)
		body:SetAttribute("HatchPop", hatch.popAt)
		body:SetAttribute("HatchFrom", hatch.from)
		-- (still till it's landed, then a rest as LassoAPet's do before wandering off)
		wait = hatch.popAt - workspace:GetServerTimeNow() + Config.Hatch.JumpTime + rng:NextNumber(1, 4)
	end
	penPets[body] = {
		owner = player,
		kind = kind,
		area = area,
		yaw = yaw,
		wait = wait,
		speed = 4,
		rng = rng,
	}
	body.Parent = petFolder
end

-- exactly these pets in their pen (a kind listed twice: two of them); the ones already
-- there stay where they are, only the difference comes and goes
function Pens.setPets(player, kinds)
	local pen = Pens.of(player)
	local area = pen and pen:FindFirstChild("Area")
	local want = {}
	if area then
		for _, kind in kinds do
			want[kind] = (want[kind] or 0) + 1
		end
	end
	for body, p in penPets do
		if p.owner == player then
			if (want[p.kind] or 0) > 0 and p.area == area and not p.mounted then
				want[p.kind] -= 1
			else
				penPets[body] = nil
				body:Destroy()
			end
		end
	end
	for kind, n in want do
		for _ = 1, n do
			spawnPet(player, area, kind)
		end
	end
end

local function clearPets(player)
	for body, p in penPets do
		if p.owner == player then
			penPets[body] = nil
			body:Destroy()
		end
	end
end

-- an empty pen: no eggs sat in it, no pets wandering (the /reset command)
function Pens.clear(player)
	clearPets(player)
	local pen = Pens.of(player)
	if pen then
		clearEggs(pen)
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

-- Each spawn (QM, Oct 31): in front of their own pen, turned to face it, standing on
-- whatever floor is there. The tutorial's on-foot start lands there too.
local function spawnAtPen(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not (root and humanoid) then
		return
	end
	if not character.Parent then
		character.AncestryChanged:Wait()
	end
	task.wait() -- (after the engine has put it on the SpawnLocation)
	local waited = 0
	while not Pens.of(player) and waited < 5 and player.Parent do
		waited += task.wait(0.1)
	end
	local spot = PenSpawn.spot(Pens.of(player))
	if not spot or player.Character ~= character or not character.Parent then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	params.FilterDescendantsInstances = { character, petFolder, workspace:FindFirstChild("Bosses") }
	local hit = workspace:Raycast(spot.Position + Vector3.new(0, 100, 0), Vector3.new(0, -200, 0), params)
	local ground = if hit then hit.Position.Y else 0
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(spot.Rotation + Vector3.new(spot.X, ground + humanoid.HipHeight + root.Size.Y / 2, spot.Z))
end

function Pens.start(map)
	for _, pen in map.Base.Pens:GetChildren() do
		pens[pen:GetAttribute("Index")] = pen
	end
	local function joined(player)
		player.CharacterAdded:Connect(function(character)
			spawnAtPen(player, character)
		end)
		if player.Character then
			task.spawn(spawnAtPen, player, player.Character)
		end
		for i = 1, #pens do
			if not owners[i] then
				owners[i] = player
				player:SetAttribute("Pen", i)
				setOwner(pens[i], player)
				return
			end
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		hatches[player] = nil
		for i, owner in owners do
			if owner == player then
				owners[i] = nil
				setOwner(pens[i], nil)
				clearEggs(pens[i])
				clearPets(player)
			end
		end
	end)
end

return Pens
