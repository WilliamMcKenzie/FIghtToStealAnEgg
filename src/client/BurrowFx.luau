-- A burrowing boss's ground effects (the Sandworm, QM Oct 27; client/BossView drives them
-- from its Burrow attribute):
--   a burst of sand thrown up and out as it bursts out of the ground or dives back in;
--   while it tunnels, LassoAPet's Sandworm burrow (its sprint special): dirt spraying up
--   over it and sand mounds pushing up along its path, sinking away behind it.
--
--   BurrowFx.burst(at, radius, sand)
--   BurrowFx.mound(scale, { sand, sand2 }) -> mound  -- scale: x the pet's burrow
--   mound:place(at)                                   -- every frame, at the ground over it
--   mound:stop()                                      -- the spray goes (the mounds sink
--                                                     -- away on their own)

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local BurrowFx = {}

local folder = Instance.new("Folder")
folder.Name = "BurrowFx"
folder.Parent = workspace

local DUST = "rbxasset://textures/particles/smoke_main.dds"

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

-- the tunnelling: LassoAPet's Sandworm burrow (its sprint special, LassoAPet
-- src/client/Burrow.luau) as it is there, scaled up by `scale`: dirt sprays up over
-- where it is, and a sand mound pushes up every MOUND_EVERY studs, the ones behind
-- slowly sinking back into the floor. Mound shapes: blocks of sand { x, z, height,
-- width } from the worm, one of the three at random each time (QM's pick there).
local MOUND_EVERY = 4.5
local MOUND_LIFE = 1.8
local MOUNDS = {
	{ { 0, 0, 2.2, 6 }, { -2.2, 0.8, 1.4, 4 }, { 2.2, -0.8, 1.4, 4 } },
	{ { 0, 0.5, 2.6, 5 }, { -1.6, -1.6, 1.6, 4.5 }, { 2.4, 0.6, 1, 3.5 }, { -2.6, 1.4, 0.8, 3 } },
	{ { 0.4, 0, 1.8, 7 }, { -1.8, -1.2, 1.2, 3.5 }, { 1.4, 1.8, 1.5, 3 } },
}
local rng = Random.new()

local function moundAt(at, scale, colours)
	local size = rng:NextNumber(0.8, 1.2) * scale -- (a little bigger or smaller each time)
	for k, shape in MOUNDS[rng:NextInteger(1, #MOUNDS)] do
		local x, z, h, w = shape[1] * size, shape[2] * size, shape[3] * size, shape[4] * size
		local p = part({
			Color = colours[(k % 2) + 1],
			Material = Enum.Material.SmoothPlastic,
			Size = Vector3.new(w, h, w * 0.8),
			CFrame = CFrame.new(at.X + x, at.Y + h / 2, at.Z + z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		})
		TweenService:Create(p, TweenInfo.new(MOUND_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = Vector3.new(p.Size.X * 0.6, 0.05, p.Size.Z * 0.6),
			CFrame = p.CFrame - Vector3.new(0, h / 2, 0),
		}):Play()
		Debris:AddItem(p, MOUND_LIFE)
	end
end

function BurrowFx.mound(scale, colours)
	local spray = part({ Transparency = 1, Size = Vector3.new(4, 1, 4) * scale })
	local dirt = Instance.new("ParticleEmitter")
	dirt.Texture = DUST
	dirt.Color = ColorSequence.new(colours[1], colours[2])
	dirt.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2 * scale),
		NumberSequenceKeypoint.new(1, 5 * scale),
	})
	dirt.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dirt.Lifetime = NumberRange.new(0.6, 1)
	dirt.Speed = NumberRange.new(2 * scale, 5 * scale)
	dirt.SpreadAngle = Vector2.new(80, 80)
	dirt.Rate = 25
	dirt.Parent = spray
	local mound = { at = nil } -- (where the last mound went up)
	local shown = colours[1]
	function mound.place(_, at)
		spray.CFrame = CFrame.new(at + Vector3.new(0, 0.5, 0))
		-- (colours can change as it goes: a rider's burrow takes the ground's, client/SprintAbility)
		if colours[1] ~= shown then
			shown = colours[1]
			dirt.Color = ColorSequence.new(colours[1], colours[2])
		end
		if not mound.at or ((at - mound.at) * Vector3.new(1, 0, 1)).Magnitude > MOUND_EVERY * scale then
			mound.at = at
			moundAt(at, scale, colours)
		end
	end
	function mound.stop()
		dirt.Enabled = false
		Debris:AddItem(spray, 1.1) -- (its last dirt settles)
	end
	return mound
end

return BurrowFx
