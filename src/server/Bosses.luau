-- Bosses, on the server: each is an invisible anchored body in workspace.Bosses (its
-- hitbox and position, replicated), with attributes Kind, Health, MaxHealth and Radius
-- (the HUD's boss bar shows its health: client/Hud.luau). Every client draws and animates the actual model on it
-- (client/BossView.luau), like the horses.
--
-- A boss chases the nearest living player at Speed, turning toward them (Turn), and
-- stops StopAt studs short. Slashes hurt it through Bosses.slash (the server checks the
-- reach and the arc); at 0 health it's removed.
--
--   Bosses.spawn(kind, player)          -- in front of the player (the /boss command)
--   Bosses.slash(player, yaw, c)        -- a player's slash along world yaw `yaw`

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ChickenModel = require(ReplicatedStorage.Shared.Animals.ChickenModel)

local Bosses = {}

local MODELS = { Chicken = ChickenModel }

local folder = Instance.new("Folder")
folder.Name = "Bosses"
folder.Parent = workspace

local live = {} -- [body] = { kind, settings, yaw, bar }

-- the drawing's box (studs, at 1x), for the body's size
local function extent(data)
	local hi = Vector3.zero
	for _, part in data.parts do
		local p, h = part.cframe.Position, part.size / 2
		hi = hi:Max(Vector3.new(math.abs(p.X) + h.X, p.Y + h.Y, math.abs(p.Z) + h.Z))
	end
	return hi
end

function Bosses.spawn(kind, player)
	local c = Config.Bosses[kind]
	local data = MODELS[kind]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (c and data and root) then
		return nil
	end
	local box = extent(data) * c.Size
	local size = Vector3.new(c.Radius * 2, box.Y, c.Radius * 2)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.new(0, 0, -1)
	local at = root.Position * Vector3.new(1, 0, 1) + look * 30
	local yaw = math.atan2(look.X, look.Z) -- (facing back toward the player)

	local body = Instance.new("Part")
	body.Name = kind .. "Boss"
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.Transparency = 1
	body.Size = size
	body.CFrame = CFrame.new(at + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0)
	body:SetAttribute("Kind", kind)
	body:SetAttribute("Health", c.Health)
	body:SetAttribute("MaxHealth", c.Health)
	body:SetAttribute("Radius", c.Radius)
	body.Parent = folder
	live[body] = { kind = kind, c = c, yaw = yaw }
	return body
end

local function hurt(body, amount)
	local health = math.max(0, body:GetAttribute("Health") - amount)
	body:SetAttribute("Health", health)
	if health <= 0 then
		live[body] = nil
		task.delay(0.6, function() -- (time for clients to play its death)
			body:Destroy()
		end)
	end
end

-- A player's slash along world yaw `yaw`: it catches every boss whose body is within
-- the arc's reach (Forward + Radius, plus the boss's own radius and a little slack) and
-- inside its sweep (half the Arc either side, plus slack for the boss's width).
function Bosses.slash(player, yaw, c)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local look = CFrame.Angles(0, yaw, 0).LookVector
	local reach = c.Forward + c.Radius * 1.15 + 2
	for body, b in live do
		local offset = (body.Position - root.Position) * Vector3.new(1, 0, 1)
		local distance = offset.Magnitude
		if distance - b.c.Radius <= reach then
			local angle = if distance > 1e-3 then math.deg(math.acos(math.clamp(offset.Unit:Dot(look), -1, 1))) else 0
			local slack = math.deg(math.atan2(b.c.Radius, math.max(distance, 1)))
			if angle <= c.Arc / 2 + slack + 10 then
				hurt(body, c.Damage)
			end
		end
	end
end

local function nearestPlayer(position)
	local best, bestDist = nil, math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			local d = ((root.Position - position) * Vector3.new(1, 0, 1)).Magnitude
			if d < bestDist then
				best, bestDist = root, d
			end
		end
	end
	return best, bestDist
end

RunService.Heartbeat:Connect(function(dt)
	for body, b in live do
		local c = b.c
		local pos = body.Position
		local target, distance = nearestPlayer(pos)
		if target then
			local offset = (target.Position - pos) * Vector3.new(1, 0, 1)
			local want = math.atan2(-offset.X, -offset.Z)
			local turn = (want - b.yaw + math.pi) % (2 * math.pi) - math.pi
			b.yaw += turn * (1 - math.exp(-dt * c.Turn))
			if distance - c.Radius > c.StopAt then
				local step = math.min(c.Speed * dt, distance - c.Radius - c.StopAt)
				-- (it walks where it faces, so it curves round rather than sliding sideways)
				pos += CFrame.Angles(0, b.yaw, 0).LookVector * step
			end
		end
		body.CFrame = CFrame.new(pos) * CFrame.Angles(0, b.yaw, 0)
	end
end)

return Bosses
