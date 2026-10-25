-- Draws Ranged and Magic shots (QM, Oct 25: arrows like Archero's, and slightly homing
-- missiles that look good but stay cheap). Each shot runs the same maths as the server's
-- (Shared/Projectiles) against the bosses and mobs this client sees, so it flies, bends
-- and stops where the server's does without anything but the trigger being sent.
--
-- Cheap on purpose: a shot is one to three anchored blocks moved once a frame and a Trail
-- (FaceCamera, so it reads from any angle). Every Ranged weapon shoots the same arrow
-- (QM, Oct 25: its Size and TrailColor differ). Magic is built from its numbers
-- (Config.Shots.Magic, tunable live): a neon core, a ForceField shell for shimmer, a
-- trail, a few default sparkles, little bits orbiting it, and a flicker for lightning; a
-- Bomb is a dark ball with a lit fuse. Hits flash a neon ball that swells and fades;
-- splashes add a flat ring.
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

-- a shot's look, as a model whose PrimaryPart is moved each frame (facing -Z = its way).
-- Returns the drawing: { model, spin = { speed, axis }, core, shell, orbit = { parts },
-- orbitRadius, flicker, color }
local function build(s)
	local look = s.Look or "Arrow"
	local size = s.Size or 1
	local color = s.Color or WHITE
	local color2 = s.Color2 or WHITE
	local model = Instance.new("Model")
	local d = { model = model, color = color }
	local root
	if look == "Arrow" or look == "Bolt" or look == "Needle" then
		-- (every Ranged weapon's arrow: QM, Oct 25; Size scales it, TrailColor tints its trail)
		local len = (if look == "Needle" then 1.3 else 2.2) * size
		local thick = (if look == "Needle" then 0.09 else 0.12) * size
		local shaft = if look == "Needle" then Color3.fromRGB(246, 236, 210) else Color3.fromRGB(117, 71, 34)
		root = block(model, Vector3.new(thick, thick, len), CFrame.new(), shaft)
		if look ~= "Needle" then
			block(model, Vector3.one * 0.3 * size, CFrame.new(0, 0, -len / 2) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(200, 206, 216))
			block(model, Vector3.new(0.04, 0.42, 0.5) * size, CFrame.new(0, 0, len / 2 - 0.2 * size), WHITE)
		end
		local tint = s.TrailColor or (if look == "Needle" then Color3.fromRGB(150, 255, 120) else WHITE)
		trail(root, 0.35 * size, tint, s.TrailLength or 0.12)
		d.color = tint
	elseif look == "Bomb" then
		-- a bomb: a dark ball with a lit fuse, tumbling
		local r = 0.9 * size
		root = block(model, Vector3.one * r, CFrame.new(), color, { Shape = Enum.PartType.Ball })
		block(model, Vector3.new(0.12, 0.3, 0.12) * size, CFrame.new(0, r * 0.55, 0), Color3.fromRGB(120, 90, 60))
		local spark = block(model, Vector3.one * 0.2 * size, CFrame.new(0, r * 0.55 + 0.18 * size, 0), color2, {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
		})
		sparkles(spark, color2, (s.SparkleSize or 0.35) * size, s.Sparkles or 20)
		trail(root, r * 0.6, color2, s.TrailLength or 0.15, 0.6)
		d.spin = { speed = math.rad(s.Spin or 0), axis = "X" }
		d.color = color2
	elseif look == "Petal" then
		root = block(model, Vector3.new(0.75, 0.12, 0.5) * size, CFrame.new(), color, { Material = Enum.Material.Neon })
		trail(root, 0.4 * size, ColorSequence.new(color2, color), s.TrailLength or 0.18, 1)
		d.spin = { speed = 14, axis = "Y" }
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
		d.spin = if look == "Horn" then { speed = 25, axis = "Z" } else { speed = 12, axis = "X" }
		d.color = if look == "Horn" then WHITE else Color3.fromRGB(255, 220, 90)
	else
		-- magic (Orb, Fireball): built from its numbers (Config.Shots.Magic)
		local core = 0.8 * size
		root = block(model, Vector3.one * core, CFrame.new(), color, { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon })
		d.core, d.coreSize = root, core
		local shell = s.ShellSize or 1.6
		if shell > 0 then
			d.shell = block(model, Vector3.one * core * shell, CFrame.new(), color, {
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.ForceField,
				Transparency = s.ShellTransparency or 0.1,
			})
			d.shellSize = core * shell
		end
		trail(root, core * (s.TrailWidth or 1.1), ColorSequence.new(color2, color), s.TrailLength or 0.2, 1)
		if (s.Sparkles or 0) > 0 then
			sparkles(root, color2, (s.SparkleSize or 0.35) * size, s.Sparkles)
		end
		d.flicker = s.Flicker or 0
		d.orbit = {}
		for _ = 1, math.floor(s.Orbit or 0) do
			table.insert(d.orbit, block(folder, Vector3.one * core * 0.35, CFrame.new(), color2, {
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.Neon,
			}))
		end
		d.orbitRadius = core * (s.OrbitRadius or 1)
		d.spinRate = math.rad(s.Spin or 0)
	end
	model.PrimaryPart = root
	model.Parent = folder
	return d
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
	local w = Weapons.get(id) -- (with any live tuning: client/WeaponTuning)
	if not (root and w.Shot) then
		return
	end
	local hips = Riding.hips(character)
	local y = (if hips then hips.Y else root.Position.Y) + Config.Shots.Height
	local origin = Vector3.new(root.Position.X, y, root.Position.Z)
	for _, shot in Projectiles.spawn(id, origin, yaw, seed) do
		local d = build(w.Shot)
		d.shot, d.s = shot, w.Shot
		table.insert(active, d)
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
			pop(at, a.color, 1.2 * (a.s.Size or 1))
			if shot.splash then
				ring(Vector3.new(at.X, at.Y - 1.5, at.Z), a.color, shot.splash)
			end
		end
		local cf = CFrame.lookAt(shot.pos, shot.pos + shot.dir)
		if a.spin and a.spin.speed ~= 0 then
			local t = shot.age * a.spin.speed
			cf *= if a.spin.axis == "Y"
				then CFrame.Angles(0, t, 0)
				elseif a.spin.axis == "X" then CFrame.Angles(t, 0, 0)
				else CFrame.Angles(0, 0, t)
		end
		a.model:PivotTo(cf)
		-- (lightning: the core and shell jitter in size)
		if a.flicker and a.flicker > 0 then
			local k = 1 + (math.random() * 2 - 1) * a.flicker
			a.core.Size = Vector3.one * a.coreSize * k
			if a.shell then
				a.shell.Size = Vector3.one * a.shellSize * (2 - k)
			end
		end
		-- (bits circling it, in the flat plane, round its path)
		if a.orbit then
			local n = #a.orbit
			for k, part in a.orbit do
				local angle = shot.age * a.spinRate + (k - 1) * 2 * math.pi / n
				part.CFrame = cf * CFrame.new(math.cos(angle) * a.orbitRadius, math.sin(angle) * a.orbitRadius, 0)
			end
		end
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
			for _, part in a.orbit or {} do
				part:Destroy()
			end
		end
	end
end)

return Shots
