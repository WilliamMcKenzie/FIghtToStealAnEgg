-- The training grounds (QM, Oct 24): five pen-sized yards along the south of the base,
-- the free straw dummies and one per biome (Meadow pigs, Desert sand crabs, Ice
-- penguins, Lava rock hogs). Strength only ever comes from attacking (Server/Combat):
-- each hit trains the enemy's Strength (Config.Training.Grounds), so these are for
-- standing and swinging, RuneScape sand-crab style. A biome's ground is fenced off until
-- you buy it (Cost in cash, the prompt at its gate; player attribute Train<Name>, which a
-- rebirth will clear); the client keeps its gate solid for you until then
-- (client/Barriers.luau).
--
-- Mobs are invisible bodies in workspace.Mobs (attributes Model, ModelSize, Tint, Name,
-- Health, MaxHealth, Radius, Ground), drawn by client/BossView.luau like the bosses.
-- They amble about their yard; one that falls is back Respawn seconds later.
--
--   Training.start(map)   -- once, after Map.ensure()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local MapData = require(ReplicatedStorage.Shared.MapData)
local Combat = require(script.Parent.Combat)

local Training = {}

local folder = Instance.new("Folder")
folder.Name = "Mobs"
folder.Parent = workspace

local mobs = {} -- [body] = { ground, x, z, half, goal, wait, yaw, settings }

function Training.unlocked(player, name)
	local g = Config.Training.Grounds[name]
	return g ~= nil and (g.Cost <= 0 or player:GetAttribute("Train" .. name) == true)
end

local function spawnMob(name, x, z, half)
	local g = Config.Training.Grounds[name]
	local rng = Random.new()
	local radius = g.Radius or Config.Training.MobRadius
	local body = Instance.new("Part")
	body.Name = name .. "Mob"
	body.Anchored, body.CanCollide, body.CanTouch = true, false, false
	body.Transparency = 1
	body.Size = Vector3.new(radius * 2, 4, radius * 2)
	local at = Vector3.new(x + rng:NextNumber(-half, half), 0 + 2, z + rng:NextNumber(-half, half))
	local yaw = rng:NextNumber(-math.pi, math.pi)
	body.CFrame = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	body:SetAttribute("Model", g.Mob)
	body:SetAttribute("ModelSize", g.Size)
	body:SetAttribute("Tint", g.Tint)
	body:SetAttribute("Name", g.Name or g.Mob)
	body:SetAttribute("Health", g.Health)
	body:SetAttribute("MaxHealth", g.Health)
	body:SetAttribute("Radius", radius)
	body:SetAttribute("Ground", name)
	mobs[body] = { ground = name, x = x, z = z, half = half, wait = rng:NextNumber(0, 2), yaw = yaw, g = g, rng = rng }
	Combat.add(body, function(player, damage)
		if not mobs[body] or not Training.unlocked(player, name) then
			return
		end
		Combat.train(player, damage, g.Strength)
		local health = math.max(0, body:GetAttribute("Health") - damage)
		body:SetAttribute("Health", health)
		if health <= 0 then
			mobs[body] = nil
			Combat.remove(body)
			task.delay(0.6, body.Destroy, body)
			task.delay(Config.Training.Respawn, spawnMob, name, x, z, half)
		end
	end)
	body.Parent = folder
end

-- a straw dummy: never falls, wobbles when it's hit
local function dummyTarget(model)
	local pivot = model:GetPivot()
	local body = Instance.new("Part")
	body.Name = "DummyBody"
	body.Anchored, body.CanCollide, body.CanTouch, body.CanQuery = true, false, false, false
	body.Transparency = 1
	body.Size = Vector3.new(4, 9, 4)
	body.CFrame = CFrame.new(pivot.Position.X, 5.5, pivot.Position.Z)
	body:SetAttribute("Radius", 2)
	body:SetAttribute("Health", 1)
	body:SetAttribute("MaxHealth", 1)
	body:SetAttribute("Dummy", true)
	body.Parent = folder
	local wobbling = false
	Combat.add(body, function(player, damage)
		Combat.train(player, damage, Config.Training.Grounds.Dummies.Strength)
		local character = player.Character
		if wobbling or not character then
			return
		end
		wobbling = true
		local look = (pivot.Position - character:GetPivot().Position) * Vector3.new(1, 0, 1)
		local axis = if look.Magnitude > 0.01 then Vector3.new(0, 1, 0):Cross(look.Unit) else Vector3.xAxis
		for _, angle in { 12, -6, 3, 0 } do
			local base = CFrame.new(pivot.Position.X, pivot.Position.Y, pivot.Position.Z)
			model:PivotTo(base * CFrame.fromAxisAngle(axis, math.rad(angle)) * pivot.Rotation)
			task.wait(0.06)
		end
		wobbling = false
	end)
end

function Training.start(map)
	local base
	for _, a in MapData.Areas do
		if a.Name == "Base" then
			base = a
		end
	end
	local half = base.TrainSize / 2 - 6
	for _, t in base.Training do
		local name, x, z = t[1], t[2], t[3]
		local g = Config.Training.Grounds[name]
		local zone = map.Base.Training:FindFirstChild(name)
		if g and zone then
			if g.Mob then
				for _ = 1, g.Count do
					spawnMob(name, x, z, half)
				end
			end
			local dummies = zone:FindFirstChild("Dummies")
			for _, d in if dummies then dummies:GetChildren() else {} do
				dummyTarget(d)
			end
			-- buying it: the prompt at its gate
			local gate = zone:FindFirstChild("Gate")
			if gate and g.Cost > 0 then
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "Unlock"
				prompt.ActionText = "Unlock ($" .. tostring(g.Cost) .. ")"
				prompt.ObjectText = (Config.Regions.Names[name] or name) .. " Training"
				prompt.HoldDuration = 0.4
				prompt.MaxActivationDistance = 14
				prompt.RequiresLineOfSight = false
				prompt.Parent = gate
				prompt.Triggered:Connect(function(player)
					if Training.unlocked(player, name) then
						return
					end
					local cash = player:GetAttribute("Cash") or 0
					if cash >= g.Cost then
						player:SetAttribute("Cash", cash - g.Cost)
						player:SetAttribute("Train" .. name, true)
					end
				end)
			end
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		for body, m in mobs do
			if m.wait > 0 then
				m.wait -= dt
				continue
			end
			local pos = body.Position
			if not m.goal then
				m.goal =
					Vector3.new(m.x + m.rng:NextNumber(-m.half, m.half), pos.Y, m.z + m.rng:NextNumber(-m.half, m.half))
			end
			local offset = (m.goal - pos) * Vector3.new(1, 0, 1)
			if offset.Magnitude < 0.5 then
				m.goal = nil
				m.wait = m.rng:NextNumber(1, 4)
				continue
			end
			local want = math.atan2(-offset.X, -offset.Z)
			m.yaw += ((want - m.yaw + math.pi) % (2 * math.pi) - math.pi) * (1 - math.exp(-dt * 5))
			pos += offset.Unit * math.min(m.g.Speed * dt, offset.Magnitude)
			body.CFrame = CFrame.new(pos) * CFrame.Angles(0, m.yaw, 0)
		end
	end)

	local function joined(player)
		for name, g in Config.Training.Grounds do
			player:SetAttribute("Train" .. name, g.Cost <= 0 or player:GetAttribute("Train" .. name) == true)
		end
	end
	Players.PlayerAdded:Connect(joined)
	for _, player in Players:GetPlayers() do
		joined(player)
	end
end

return Training
