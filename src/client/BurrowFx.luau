-- A burrowing boss's ground effects (the Sandworm, QM Oct 27; client/BossView drives them
-- from its Burrow attribute):
--   a hole where it's up: a dark pit with a rim of piled sand, opening as it surfaces and
--   filling back in once it's gone down;
--   a burst of sand thrown up and out as it bursts out of the ground or dives back in;
--   a mound of sand running over the ground while it tunnels, throwing dust and clods
--   behind it, like the Sandworm pet's burrowing sprint.
--
--   BurrowFx.hole(at, radius, colour, sand) -> hole   -- at: the ground under it
--   hole:close()                                      -- fills in and goes
--   BurrowFx.burst(at, radius, sand)
--   BurrowFx.mound(radius, sand) -> mound
--   mound:place(at, dt)                               -- every frame, at the ground under it
--   mound:stop()                                      -- sinks away, its dust settling

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local BurrowFx = {}

local folder = Instance.new("Folder")
folder.Name = "BurrowFx"
folder.Parent = workspace

local DUST = "rbxasset://textures/particles/smoke_main.dds"
local FLAT = CFrame.Angles(0, 0, math.pi / 2) -- (a cylinder lying flat: its axis is X)

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = props.Parent or folder
	return p
end

-- sand dust rising off a part (rate a second; size in studs)
local function dust(holder, sand, size, rate, speed)
	local e = Instance.new("ParticleEmitter")
	e.Texture = DUST
	e.Color = ColorSequence.new(sand, sand:Lerp(Color3.new(1, 1, 1), 0.25))
	e.LightInfluence = 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.5),
		NumberSequenceKeypoint.new(1, size * 1.4),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Rate = rate
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -speed * 0.6, 0)
	e.Drag = 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = holder
	return e
end

-- a clod of sand thrown in an arc from `from`, out `dir` (flat) and up, landing and fading
local function clod(from, dir, sand, size, reach, height, life)
	local p = part({
		Size = Vector3.one * size,
		CFrame = CFrame.new(from) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
		Color = sand:Lerp(Color3.new(0, 0, 0), math.random() * 0.15),
		Material = Enum.Material.Sand,
	})
	local land = from + dir * reach
	local t0 = os.clock()
	local spin = CFrame.Angles(math.random() * 8 - 4, math.random() * 8 - 4, 0)
	task.spawn(function()
		while p.Parent do
			local k = (os.clock() - t0) / life
			if k >= 1 then
				break
			end
			local at = from:Lerp(land, k) + Vector3.new(0, height * 4 * k * (1 - k), 0)
			p.CFrame = CFrame.new(at) * spin:Lerp(CFrame.identity, 1 - k) * p.CFrame.Rotation
			task.wait()
		end
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(0.3), { Transparency = 1, Size = p.Size * 0.4 }):Play()
			Debris:AddItem(p, 0.32)
		end
	end)
end

function BurrowFx.hole(at, radius, colour, sand)
	local pit = part({
		Name = "Hole",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 0.1, 0.1),
		CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0)) * FLAT,
		Color = colour,
		Material = Enum.Material.SmoothPlastic,
	})
	local rim = part({
		Name = "HoleRim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 0.1, 0.1),
		CFrame = CFrame.new(at + Vector3.new(0, 0.05, 0)) * FLAT,
		Color = sand,
		Material = Enum.Material.Sand,
	})
	local open = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(pit, open, { Size = Vector3.new(0.12, radius * 2, radius * 2) }):Play()
	TweenService:Create(rim, open, { Size = Vector3.new(0.5, radius * 2.6, radius * 2.6) }):Play()
	local hole = {}
	function hole.close()
		local shut = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(pit, shut, { Size = Vector3.new(0.12, 0.1, 0.1), Color = sand }):Play()
		TweenService:Create(rim, shut, { Size = Vector3.new(0.5, radius * 0.5, radius * 0.5), Transparency = 1 }):Play()
		Debris:AddItem(pit, 0.62)
		Debris:AddItem(rim, 0.62)
	end
	return hole
end

function BurrowFx.burst(at, radius, sand)
	local holder = part({
		Transparency = 1,
		Size = Vector3.new(radius * 1.6, 0.2, radius * 1.6),
		CFrame = CFrame.new(at),
	})
	local e = dust(holder, sand, radius * 0.7, 0, radius * 1.4)
	e:Emit(26)
	Debris:AddItem(holder, 1.5)
	for _ = 1, 14 do
		local angle = math.random() * 2 * math.pi
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		clod(
			at + dir * radius * 0.6,
			dir,
			sand,
			radius * (0.12 + math.random() * 0.12),
			radius * (0.6 + math.random() * 0.9),
			radius * (0.5 + math.random() * 0.7),
			0.45 + math.random() * 0.25
		)
	end
end

function BurrowFx.mound(radius, sand)
	local hump = part({
		Name = "Mound",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * radius * 2,
		Color = sand,
		Material = Enum.Material.Sand,
	})
	local emitter = dust(hump, sand, radius * 0.9, 40, radius * 0.9)
	local mound = { last = nil, kick = 0, rise = 0 }
	function mound.place(_, at, dt)
		-- (rises up out of the ground as it sets off)
		mound.rise = math.min(1, mound.rise + dt / 0.2)
		hump.CFrame = CFrame.new(at - Vector3.new(0, radius * (1.25 - 0.6 * mound.rise), 0))
		-- clods kicked up behind it as it goes
		mound.kick -= dt
		if mound.last and mound.kick <= 0 then
			local back = (mound.last - at) * Vector3.new(1, 0, 1)
			if back.Magnitude > 1e-3 then
				mound.kick = 0.07
				local side = Vector3.new(-back.Z, 0, back.X).Unit * (math.random() * 2 - 1) * 0.8
				local dir = (back.Unit + side).Unit
				clod(at + dir * radius * 0.6, dir, sand, radius * 0.18, radius * 1.2, radius * 0.8, 0.4)
			end
		end
		mound.last = at
	end
	function mound.stop()
		emitter.Enabled = false
		TweenService:Create(hump, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = hump.CFrame - Vector3.new(0, radius * 1.3, 0),
		}):Play()
		Debris:AddItem(hump, 1.2) -- (its dust settles first)
	end
	return mound
end

return BurrowFx
