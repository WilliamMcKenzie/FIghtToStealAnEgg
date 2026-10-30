-- Enemies' melee swipes (Server/BossAttacks' Swipe; QM, Oct 30: no more hurting you just by
-- bumping into you). Every client draws each one from the EnemySwipe remote: first a red
-- telegraph on the ground in exactly the swipe's crescent (Shared/SlashFx's outline, rolled
-- from the same seed the server hits with), styled like the bombs' landing rings (client/
-- Bombs): an outline all round, a faint red fading in from its outer edge, and a fill that
-- grows from its inner edge out, reaching the outer edge just as it hits. Then the swipe
-- itself goes through it, white like yours.
--
-- Each layer of the telegraph is a run of flat Beams along the arc (one per strip of the
-- outline, the way SlashFx draws a slash), covering some share of the crescent's thickness.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SlashFx = require(Shared:WaitForChild("SlashFx"))

local folder = Instance.new("Folder")
folder.Name = "SwipeFx"
folder.Parent = workspace

local UP = Vector3.yAxis
-- (a flat Beam spans its width along each attachment's UpVector: SlashFx's place)
local function place(att, pos, across)
	local width = across.Unit
	att.CFrame = CFrame.fromMatrix(pos, width:Cross(UP).Unit, width)
end

-- the cuts in [u0, u1]: its ends and every strip cut of the outline between them
local function cutsIn(o, u0, u1)
	local out = { u0 }
	for _, u in o.at do
		if u > u0 + 1e-4 and u < u1 - 1e-4 then
			table.insert(out, u)
		end
	end
	table.insert(out, u1)
	return out
end

-- one layer: beams from u0 to u1 along the arc; draw(band) lays each between the shares of
-- the thickness band(thickness) gives ((f0, f1), 0 = inner edge, 1 = outer)
local function layer(parent, o, dir, u0, u1, color, transparency, zoffset)
	local us = cutsIn(o, u0, u1)
	local strips = {}
	for i = 1, #us - 1 do
		local a0 = Instance.new("Attachment")
		local a1 = Instance.new("Attachment")
		a0.Parent, a1.Parent = parent, parent
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.FaceCamera = false
		beam.Segments = 1
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = 0.3
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(transparency)
		beam.ZOffset = zoffset
		beam.Parent = parent
		strips[i] = { a0 = a0, a1 = a1, beam = beam, ua = us[i], ub = us[i + 1] }
	end
	local function ends(u, band)
		local outer, inner, radial = SlashFx.edges(o, u, dir)
		local across = outer - inner
		local f0, f1 = band(across.Magnitude)
		f0, f1 = math.clamp(f0, 0, 1), math.clamp(f1, 0, 1)
		local p0, p1 = inner + across * f0, inner + across * f1
		local w = (p1 - p0).Magnitude
		return (p0 + p1) / 2, if across.Magnitude > 1e-3 then across else radial, w
	end
	return function(band)
		for _, s in strips do
			local ca, da, wa = ends(s.ua, band)
			local cb, db, wb = ends(s.ub, band)
			place(s.a0, ca, da)
			place(s.a1, cb, db)
			s.beam.Width0, s.beam.Width1 = wa, wb
			s.beam.Enabled = wa > 1e-3 or wb > 1e-3
		end
	end
end

local active = {} -- { { part, fill, edge, start, windup, info, c } }

local function look(info)
	local c = table.clone(Config.EnemySwipe)
	for k, v in info.look do
		c[k] = v
	end
	return c
end

local function telegraph(info)
	local S = Config.EnemySwipe
	local c = look(info)
	local o = SlashFx.outline(c, info.seed)
	local dir = info.dir
	local part = Instance.new("Part")
	part.Name = "SwipeWarning"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.one * 0.2
	part.CFrame = info.origin + Vector3.new(0, S.Lift, 0)
	part.Parent = folder

	local function full()
		return 0, 1
	end
	-- the outline: its outer and inner edges, and both flat ends
	local w = S.OutlineWidth
	layer(part, o, dir, 0, 1, S.Warn, S.Outline, 3)(function(t)
		return 1 - w / t, 1
	end)
	layer(part, o, dir, 0, 1, S.Warn, S.Outline, 3)(function(t)
		return 0, w / t
	end)
	local arcLength = math.rad(o.c.Arc) * (o.c.Radius - o.c.Width / 2)
	local endShare = math.min(0.2, w / math.max(arcLength, 1))
	layer(part, o, dir, 0, endShare, S.Warn, S.Outline, 3)(full)
	layer(part, o, dir, 1 - endShare, 1, S.Warn, S.Outline, 3)(full)
	-- faint red fading in from the outer edge
	for k = 1, S.FadeBands do
		local t = (k - 1) / S.FadeBands
		local hi = 1 - (k - 1) / S.FadeBands * S.FadeDepth
		local lo = 1 - k / S.FadeBands * S.FadeDepth
		layer(part, o, dir, 0, 1, S.Warn, S.FadeEdge + (1 - S.FadeEdge) * t ^ 0.8, 0)(function()
			return lo, hi
		end)
	end
	-- the fill and its leading edge, grown every frame
	local fill = layer(part, o, dir, 0, 1, S.Warn, S.Fill, 1)
	local edge = layer(part, o, dir, 0, 1, S.Warn, S.Edge, 2)
	table.insert(active, {
		part = part,
		fill = fill,
		edge = edge,
		start = info.start,
		windup = info.windup,
		info = info,
		c = c,
	})
end

local function strike(a)
	local S = Config.EnemySwipe
	a.part:Destroy()
	-- (died winding up: no swipe, like no hit on the server)
	local body = a.info.body
	if not body or not body.Parent or (body:GetAttribute("Health") or 0) <= 0 then
		return
	end
	SlashFx.play(a.info.origin + Vector3.new(0, S.Height, 0), a.info.dir, a.c, nil, a.info.seed)
end

ReplicatedStorage:WaitForChild("EnemySwipe").OnClientEvent:Connect(function(info)
	local delay = info.start - workspace:GetServerTimeNow()
	if delay + info.windup <= 0 then
		return -- (it's already hit)
	end
	if delay > 0 then
		task.delay(delay, telegraph, info)
	else
		telegraph(info)
	end
end)

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local ew = Config.EnemySwipe.EdgeWidth
	for i = #active, 1, -1 do
		local a = active[i]
		local k = math.clamp((now - a.start) / a.windup, 0, 1)
		if k >= 1 then
			table.remove(active, i)
			strike(a)
			continue
		end
		a.fill(function()
			return 0, k
		end)
		a.edge(function(t)
			return k - ew / t, k
		end)
	end
end)

return {}
