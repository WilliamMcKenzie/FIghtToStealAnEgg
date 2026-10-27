-- Draws Ranged and Magic shots (QM, Oct 25: arrows like Archero's, and slightly homing
-- missiles that look good but stay cheap). Each shot runs the same maths as the server's
-- (Shared/Projectiles) against the bosses and mobs this client sees, so it flies, bends
-- and stops where the server's does without anything but the trigger being sent.
--
-- Cheap on purpose: a shot is one to three anchored blocks moved once a frame and a Trail
-- (FaceCamera, so it reads from any angle). Every Ranged weapon shoots the same arrow
-- (QM, Oct 25: its Size and TrailColor differ). Magic is built from its numbers
-- (Config.Shots.Magic, tunable live): every staff fires the same orb, recoloured and
-- resized (QM), in one colour: a white core in a ring of the colour inside a fainter
-- halo of it, flares curling over it, a trail and sparkles. Hits flash a neon ball that swells and fades;
-- splashes add a flat ring.
--
--   Shots.fire(character, id, yaw, seed)   -- a weapon's volley from that rider (seed: its
--                                          magic shots' random launch angles)
--   Shots.boss(body, i, yaw, seed, origin) -- a boss's Magic attack (its Attacks[i]): the
--                                          same orbs, flying at the players in its fight
--                                          (the server's BossShot remote calls it)

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Projectiles = require(Shared.Projectiles)
local Weapons = require(Shared.Weapons.Weapons)
local Pets = require(Shared.Pets)
local Riding = require(script.Parent.Riding)

local Shots = {}

local folder = Instance.new("Folder")
folder.Name = "Shots"
folder.Parent = workspace

local WHITE = Color3.new(1, 1, 1)
local active = {} -- { { shot, model, spin, look, color, biome (a boss's: it flies at players) } }
local HORSE_HITBOX = Pets.stats("Horse").Hitbox
local PLAYER_RADIUS = 1 -- (as Server/BossAttacks)

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

local function trail(part, width, color, lifetime, emission, opacity)
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
	t.Transparency = NumberSequence.new(opacity or 0.2, 1)
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

-- a shot's look, as a model whose PrimaryPart is moved each frame (facing -Z = its way).
-- Returns the drawing: { model, color, spin = { speed, axis } } and, for the orb, its
-- core and flares to animate
local function build(s)
	local look = s.Look or "Arrow"
	local size = s.Size or 1
	local color = s.Color or WHITE
	local color2 = s.Color2 or WHITE
	local model = Instance.new("Model")
	local d = { model = model, color = color }
	local root
	if look == "Arrow" or look == "Bolt" then
		-- (every Ranged weapon's arrow: QM, Oct 25; Size scales it, TrailColor tints its trail)
		local len = 2.2 * size
		local thick = 0.12 * size
		local shaft = Color3.fromRGB(117, 71, 34)
		root = block(model, Vector3.new(thick, thick, len), CFrame.new(), shaft)
		block(model, Vector3.one * 0.3 * size, CFrame.new(0, 0, -len / 2) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(200, 206, 216))
		block(model, Vector3.new(0.04, 0.42, 0.5) * size, CFrame.new(0, 0, len / 2 - 0.2 * size), WHITE)
		local tint = s.TrailColor or WHITE
		trail(root, 0.35 * size, tint, s.TrailLength or 0.12, nil, s.TrailTransparency)
		d.color = tint
	elseif look == "Petal" then
		root = block(model, Vector3.new(0.75, 0.12, 0.5) * size, CFrame.new(), color, { Material = Enum.Material.Neon })
		trail(root, 0.4 * size, ColorSequence.new(color2, color), s.TrailLength or 0.18, 1)
		d.spin = { speed = 14, axis = "Y" }
	else
		-- every staff's orb (QM's purple orb reference, Oct 25), from Config.Shots.Magic, in
		-- one Color: glowing balls stacked inside each other (Neon, more see-through the
		-- further out), so the always-white core shows through a ring of Color, inside a
		-- fainter halo and haze of it; Beams curling over it for flares; a trail and
		-- sparkles. No textures: it's all built-in parts, beams and particles.
		local function ball(diameter, c, transparency)
			return block(model, Vector3.one * diameter, CFrame.new(), c, {
				Shape = Enum.PartType.Ball,
				Material = Enum.Material.Neon,
				Transparency = transparency,
			})
		end
		-- (the middle the rest hangs on: trail and flares)
		root = block(model, Vector3.one * 0.2, CFrame.new(), WHITE, { Transparency = 1 })
		-- the core: pure white (QM). Inside the coloured balls it'd be tinted by them, so it's
		-- drawn outside them instead, on the line from the camera to the orb's middle, just in
		-- front of the outermost ball and shrunk to look the same size (moved every frame)
		local coreSize = (s.CoreSize or 0.55) * size
		d.core = block(folder, Vector3.one * coreSize, CFrame.new(), WHITE, {
			Shape = Enum.PartType.Ball,
			Material = Enum.Material.Neon,
		})
		d.coreSize = coreSize
		d.front = math.max(s.RingSize or 1, s.HaloSize or 1.9, if (s.HazeSize or 0) > 0 then s.HazeSize else 0) * size / 2 + 0.05
		ball((s.RingSize or 1) * size, color, s.RingTransparency or 0.3)
		ball((s.HaloSize or 1.9) * size, color, s.HaloTransparency or 0.8)
		if (s.HazeSize or 0) > 0 then
			ball(s.HazeSize * size, color, s.HazeTransparency or 0.93)
		end
		-- flares: each a Beam from low on one side of the ring, bowing out and up over the
		-- top to a point further round, wide at its root and tapering to nothing
		local ring = (s.RingSize or 1) * size / 2
		d.flares = {}
		for k = 1, math.floor(s.Flares or 0) do
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Parent, a1.Parent = root, root
			local beam = Instance.new("Beam")
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.FaceCamera = true
			beam.Segments = 12
			beam.LightEmission = 1
			beam.Color = ColorSequence.new(color:Lerp(WHITE, 0.4), color)
			beam.Transparency = NumberSequence.new(s.FlareTransparency or 0.25, 1)
			beam.Width0 = (s.FlareWidth or 0.45) * size
			beam.Width1 = 0
			beam.CurveSize0 = (s.FlareLength or 1.6) * size * 0.6
			beam.Parent = root
			table.insert(d.flares, { a0 = a0, a1 = a1, base = (k - 1) * 2 * math.pi / s.Flares })
		end
		d.ring, d.flareLength = ring, (s.FlareLength or 1.6) * size
		d.flareSpin = math.rad(s.FlareSpin or 220)
		-- (the trail comes off the glow seamlessly, QM: as wide as the halo, its colour, as
		-- see-through, fading out behind; lit like the Neon balls are)
		local halo = (s.HaloSize or 1.9) * size
		trail(root, halo * (s.TrailWidth or 1), color, s.TrailLength or 0.25, 1, s.HaloTransparency or 0.8)
		if (s.Sparkles or 0) > 0 then
			sparkles(root, color:Lerp(WHITE, 0.4), (s.SparkleSize or 0.3) * size, s.Sparkles)
		end
		d.flicker = s.Flicker or 0
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

-- a sound from `parent` (a part), or at a point (an Attachment in Terrain, then gone)
local function sound(id, volume, parent, at)
	if type(id) ~= "string" or id == "" or (volume or 0) <= 0 then
		return
	end
	local holder = parent
	if not holder then
		holder = Instance.new("Attachment")
		holder.WorldPosition = at
		holder.Parent = workspace.Terrain
		Debris:AddItem(holder, 4)
	end
	local snd = Instance.new("Sound")
	snd.SoundId = id
	snd.Volume = volume
	snd.RollOffMinDistance = 10
	snd.RollOffMaxDistance = 150
	snd.Parent = holder
	snd:Play()
	Debris:AddItem(snd, 4)
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
	sound(w.Shot.FireSound, w.Shot.FireVolume, root) -- (once a volley, not once a shot)
	for _, shot in Projectiles.spawn(id, origin, yaw, seed) do
		local d = build(w.Shot)
		d.shot, d.s = shot, w.Shot
		table.insert(active, d)
	end
end

function Shots.boss(body, i, yaw, seed, origin)
	local c = body and Config.Bosses[body:GetAttribute("Kind")]
	local a = c and c.Attacks and c.Attacks[i]
	if not (a and typeof(origin) == "Vector3") then
		return
	end
	local s = Projectiles.bossShot(a)
	sound(s.FireSound, s.FireVolume, nil, origin)
	for _, shot in Projectiles.volley(s, true, origin, yaw, seed) do
		local look = s
		if shot.size ~= (s.Size or 1) then
			-- (drawn at its own random size: SizeMax)
			look = table.clone(s)
			look.Size = shot.size
		end
		local d = build(look)
		d.shot, d.s, d.biome = shot, look, body:GetAttribute("Biome") or false
		table.insert(active, d)
	end
end

-- what a boss's shot can hit here: every living player in its fight
local function players(biome)
	local list = {}
	for _, p in Players:GetPlayers() do
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 and p:GetAttribute("LockedIn") == biome then
			local extra = Pets.stats(p:GetAttribute("Pet") or "Horse").Hitbox - HORSE_HITBOX
			table.insert(list, { body = root, pos = root.Position, radius = PLAYER_RADIUS + extra })
		end
	end
	return list
end

-- what a shot can hit here: every living boss and mob (flat circles); a boss still
-- arriving (or asleep) isn't there to hit, shots pass over it
local function targets()
	local list = {}
	for _, name in { "Bosses", "Mobs" } do
		local f = workspace:FindFirstChild(name)
		for _, body in if f then f:GetChildren() else {} do
			if
				body:IsA("BasePart")
				and (body:GetAttribute("Health") or 0) > 0
				and not body:GetAttribute("Asleep")
				and not body:GetAttribute("Intro")
				and not body:GetAttribute("Burrowed") -- (a Sandworm tunnelling underground)
			then
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
	local fights = {} -- [biome] = its players, for bosses' shots
	for i = #active, 1, -1 do
		local a = active[i]
		local shot = a.shot
		local hits = list
		if a.biome ~= nil then
			fights[a.biome] = fights[a.biome] or players(a.biome)
			hits = fights[a.biome]
		end
		for _ in Projectiles.step(shot, dt, hits) do
			local at = shot.pos
			if a.s.Look ~= "Arrow" then -- (no burst where an arrow lands: QM)
				pop(at, a.color, 1.2 * (a.s.Size or 1))
			end
			sound(a.s.HitSound, a.s.HitVolume, nil, at)
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
		-- (the white core, in front of the coloured balls as the camera sees them: see build)
		if a.core then
			local toCam = workspace.CurrentCamera.CFrame.Position - shot.pos
			local dist = toCam.Magnitude
			local k = 1 + (math.random() * 2 - 1) * (a.flicker or 0)
			if dist > a.front + 0.5 then
				a.core.CFrame = CFrame.new(shot.pos + toCam.Unit * a.front)
				a.core.Size = Vector3.one * a.coreSize * k * (dist - a.front) / dist
			else
				a.core.CFrame = CFrame.new(shot.pos)
				a.core.Size = Vector3.one * a.coreSize * k
			end
		end
		-- (the flares turn round the orb, curling up over its top)
		for _, f in a.flares or {} do
			local t = f.base + shot.age * a.flareSpin
			local out0 = Vector3.new(math.cos(t), 0, math.sin(t))
			local t1 = t + math.rad(110)
			local p0 = out0 * a.ring + Vector3.new(0, -a.ring * 0.3, 0)
			local p1 = Vector3.new(math.cos(t1), 0, math.sin(t1)) * a.ring * 0.5 + Vector3.new(0, a.flareLength, 0)
			-- (Attachment0's X axis is where the beam bows: out and up)
			f.a0.CFrame = CFrame.fromMatrix(p0, (out0 + Vector3.yAxis * 0.6).Unit, Vector3.yAxis:Cross(out0).Unit)
			f.a1.Position = p1
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
			for _, beam in a.model:GetDescendants() do
				if beam:IsA("Beam") then
					beam.Enabled = false
				end
			end
			Debris:AddItem(a.model, 0.5)
			if a.core then
				a.core:Destroy()
			end
		end
	end
end)

ReplicatedStorage:WaitForChild("BossShot").OnClientEvent:Connect(Shots.boss)

return Shots
