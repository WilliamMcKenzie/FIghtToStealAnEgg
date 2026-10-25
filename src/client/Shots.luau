-- Draws Ranged and Magic shots (QM, Oct 25: arrows like Archero's, and slightly homing
-- missiles that look good but stay cheap). Each shot runs the same maths as the server's
-- (Shared/Projectiles) against the bosses and mobs this client sees, so it flies, bends
-- and stops where the server's does without anything but the trigger being sent.
--
-- Cheap on purpose: a shot is one to three anchored blocks moved once a frame, a Trail
-- (FaceCamera, so it reads from any angle) and, for magic, a ForceField shell for shimmer
-- and a few default sparkles. Hits flash a neon ball that swells and fades; splashes add
-- a flat ring.
--
--   Shots.fire(character, id, yaw, seed)   -- a weapon's volley from that rider (seed: its
--                                          magic shots' random launch angles)

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Projectiles = require(Shared.Projectiles)
local Weapons = require(Shared.Weapons.Weapons)
local Riding = require(script.Parent.Riding)

local Shots = {}

local folder = Instance.new("Folder")
folder.Name = "Shots"
folder.Parent = workspace

local WHITE = Color3.new(1, 1, 1)
local active = {} -- { { shot, model, spin, look, color } }

local function block(model, size, cf, color, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props or {} do
		p[k] = v
	end
	p.Parent = model
	return p
end

local function trail(part, width, color, lifetime, emission)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(width / 2, 0, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-width / 2, 0, 0)
	a1.Parent = part
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.FaceCamera = true
	t.Lifetime = lifetime
	t.LightEmission = emission or 0.6
	t.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(color)
	t.Transparency = NumberSequence.new(0.2, 1)
	t.WidthScale = NumberSequence.new(1, 0)
	t.Parent = part
	return t
end

local function sparkles(part, color, size, rate)
	local e = Instance.new("ParticleEmitter") -- (Roblox's default sparkle texture)
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(size, 0)
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Lifetime = NumberRange.new(0.25, 0.4)
	e.Rate = rate
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = part
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 200)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 120)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(120, 230, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 140, 255)),
})

-- a shot's look, as a model whose PrimaryPart is moved each frame (facing -Z = its way)
local function build(id, s)
	local look = s.Look or "Arrow"
	local size = s.Size or 1
	local color = s.Color or WHITE
	local model = Instance.new("Model")
	local root
	local spin = nil -- (radians a second, and round which axis)
	if look == "Arrow" or look == "Bolt" or look == "Needle" then
		local len = if look == "Arrow" then 2.2 elseif look == "Bolt" then 1.5 else 1.3
		local thick = if look == "Bolt" then 0.18 elseif look == "Needle" then 0.09 else 0.12
		local shaft = if look == "Needle" then Color3.fromRGB(246, 236, 210) else Color3.fromRGB(117, 71, 34)
		root = block(model, Vector3.new(thick, thick, len), CFrame.new(), shaft)
		if look ~= "Needle" then
			block(model, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0, -len / 2) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(200, 206, 216))
			block(model, Vector3.new(0.04, 0.42, 0.5), CFrame.new(0, 0, len / 2 - 0.2), if look == "Bolt" then Color3.fromRGB(200, 40, 40) else WHITE)
		end
		trail(root, if look == "Needle" then 0.25 else 0.35, if look == "Needle" then Color3.fromRGB(150, 255, 120) else WHITE, 0.12)
	elseif look == "Orb" or look == "Fireball" then
		local core = 0.8 * size
		root = block(model, Vector3.one * core, CFrame.new(), color, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon })
		block(model, Vector3.one * core * 1.6, CFrame.new(), color, {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.ForceField,
			Transparency = 0.1,
		})
		local tail = if look == "Fireball"
			then ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 50, 20))
			else ColorSequence.new(WHITE, color)
		trail(root, core * 1.1, tail, if look == "Fireball" then 0.3 else 0.2, 1)
		sparkles(root, color, 0.35 * size, if look == "Fireball" then 30 else 14)
	elseif look == "Petal" then
		root = block(model, Vector3.new(0.75, 0.12, 0.5), CFrame.new(), color, { Material = Enum.Material.Neon })
		trail(root, 0.4, ColorSequence.new(Color3.fromRGB(255, 200, 210), color), 0.18, 1)
		spin = { speed = 14, axis = "Y" }
	elseif look == "Horn" or look == "Egg" then
		root = block(model, Vector3.one * 0.2, CFrame.new(), WHITE, { Transparency = 1 })
		local held = Weapons.makeModel(if look == "Horn" then "UnicornHorn" else "GoldenEgg", if look == "Horn" then 0.9 else 1.3 * size)
		-- (its blade end, +Y, out front along -Z; the Egg just tumbles)
		held:PivotTo(CFrame.Angles(-math.pi / 2, 0, 0))
		for _, part in held:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CastShadow = false
				part.CanQuery = false
			end
		end
		held.Parent = model
		trail(root, 0.6, if look == "Horn" then RAINBOW else ColorSequence.new(Color3.fromRGB(255, 220, 90)), 0.22, 0.8)
		spin = if look == "Horn" then { speed = 25, axis = "Z" } else { speed = 12, axis = "X" }
	end
	model.PrimaryPart = root
	model.Parent = folder
	return model, spin, color
end

local function pop(at, color, size)
	local p = block(folder, Vector3.one * size, CFrame.new(at), color, {
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	TweenService:Create(p, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size * 2.4,
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, 0.2)
end

local function ring(at, color, radius)
	local p = block(folder, Vector3.new(0.2, 1, 1), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), color, {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(p, 0.32)
end

function Shots.fire(character, id, yaw, seed)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local w = Config.Weapons[id]
	if not (root and w and w.Shot) then
		return
	end
	local hips = Riding.hips(character)
	local y = (if hips then hips.Y else root.Position.Y) + Config.Shots.Height
	local origin = Vector3.new(root.Position.X, y, root.Position.Z)
	for _, shot in Projectiles.spawn(id, origin, yaw, seed) do
		local model, spin, color = build(id, w.Shot)
		table.insert(active, { shot = shot, model = model, spin = spin, color = color, s = w.Shot })
	end
end

-- what a shot can hit here: every living boss and mob (flat circles)
local function targets()
	local list = {}
	for _, name in { "Bosses", "Mobs" } do
		local f = workspace:FindFirstChild(name)
		for _, body in if f then f:GetChildren() else {} do
			if body:IsA("BasePart") and (body:GetAttribute("Health") or 0) > 0 then
				table.insert(list, { body = body, pos = body.Position, radius = body:GetAttribute("Radius") or 0 })
			end
		end
	end
	return list
end

RunService.RenderStepped:Connect(function(dt)
	if #active == 0 then
		return
	end
	local list = targets()
	for i = #active, 1, -1 do
		local a = active[i]
		local shot = a.shot
		for _ in Projectiles.step(shot, dt, list) do
			local at = shot.pos
			pop(at, if a.s.Look == "Arrow" or a.s.Look == "Bolt" then WHITE else a.color, if a.s.Size then 1.2 * a.s.Size else 1.2)
			if shot.splash then
				ring(Vector3.new(at.X, at.Y - 1.5, at.Z), a.color, shot.splash)
			end
		end
		local cf = CFrame.lookAt(shot.pos, shot.pos + shot.dir)
		if a.spin then
			local t = shot.age * a.spin.speed
			cf *= if a.spin.axis == "Y"
				then CFrame.Angles(0, t, 0)
				elseif a.spin.axis == "X" then CFrame.Angles(t, 0, 0)
				else CFrame.Angles(0, 0, t)
		end
		a.model:PivotTo(cf)
		if shot.dead then
			table.remove(active, i)
			-- (the trail's tail fades out on its own)
			for _, part in a.model:GetDescendants() do
				if part:IsA("BasePart") then
					part.Transparency = 1
				elseif part:IsA("ParticleEmitter") then
					part.Enabled = false
				end
			end
			Debris:AddItem(a.model, 0.5)
		end
	end
end)

return Shots
