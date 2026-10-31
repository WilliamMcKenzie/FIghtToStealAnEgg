-- Your pen glows while you hold an egg (QM, Oct 31: "a glow effect on the inside of
-- players own pen when they are holding an egg to indicate that is where to place it, just
-- generally not just in tutorial"): a soft gold light rising off the inside of its four
-- sides and a faint wash over its floor, breathing in and out, only on your own pen and
-- only for you. On while your Holding attribute names an egg (Server/Hatchery), fading in
-- and out.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local COLOR = Color3.fromRGB(255, 226, 110)
local HEIGHT = 7 -- studs the sides' glow rises
local INSET = 2 -- studs in from the pen's Area sides: just inside its fence (Server/Map puts it 1 in, posts 1 thick)
local SIDE = 0.25 -- the sides' glow at its strongest, at the bottom (transparency)
local FLOOR = 0.82 -- the floor's wash (transparency)
local BREATHE = 0.25 -- how much it fades in and out, of what's left to see-through
local PERIOD = 1.6 -- seconds a breath takes
local FADE = 0.25 -- seconds to come on or go

local function myArea()
	local index = player:GetAttribute("Pen")
	local map = workspace:FindFirstChild("Map")
	local pens = map and map:FindFirstChild("Base") and map.Base:FindFirstChild("Pens")
	if not (index and pens) then
		return nil
	end
	for _, pen in pens:GetChildren() do
		if pen:GetAttribute("Index") == index then
			return pen:FindFirstChild("Area")
		end
	end
	return nil
end

local holder -- an invisible anchored part the beams hang off, or nil
local sides, floor = {}, nil
local builtFor -- the Area it was built for

local function beam(a0, a1, width)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Width0, b.Width1 = width, width
	b.FaceCamera = false
	b.Segments = 1
	b.Color = ColorSequence.new(COLOR)
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Parent = holder
	return b
end

local function attach(cf)
	local a = Instance.new("Attachment")
	a.CFrame = holder.CFrame:ToObjectSpace(cf)
	a.Parent = holder
	return a
end

local function build(area)
	if holder then
		holder:Destroy()
	end
	table.clear(sides)
	builtFor = area
	holder = Instance.new("Part")
	holder.Name = "PenGlow"
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.CFrame = area.CFrame
	local cf, size = area.CFrame, area.Size
	local up = Vector3.yAxis
	local y = -size.Y / 2 + 0.05 -- (the floor, in the Area's frame: as Server/Hatchery)
	local hx, hz = size.X / 2 - INSET, size.Z / 2 - INSET
	-- the four sides: a curtain from the floor straight up, as wide as the side (a beam's
	-- width runs along its attachments' UpVector)
	for _, s in
		{
			{ Vector3.new(hx, y, 0), Vector3.zAxis, size.Z },
			{ Vector3.new(-hx, y, 0), Vector3.zAxis, size.Z },
			{ Vector3.new(0, y, hz), Vector3.xAxis, size.X },
			{ Vector3.new(0, y, -hz), Vector3.xAxis, size.X },
		}
	do
		local at = cf:PointToWorldSpace(s[1])
		local along = cf:VectorToWorldSpace(s[2])
		local a0 = attach(CFrame.fromMatrix(at, up, along))
		local a1 = attach(CFrame.fromMatrix(at + up * HEIGHT, up, along))
		table.insert(sides, beam(a0, a1, s[3] - 2 * INSET))
	end
	-- the floor: flat across it
	local across = cf:VectorToWorldSpace(Vector3.xAxis)
	local along = cf:VectorToWorldSpace(Vector3.zAxis)
	local a0 = attach(CFrame.fromMatrix(cf:PointToWorldSpace(Vector3.new(0, y, -hz)), along, across))
	local a1 = attach(CFrame.fromMatrix(cf:PointToWorldSpace(Vector3.new(0, y, hz)), along, across))
	floor = beam(a0, a1, 2 * hx)
	holder.Parent = workspace
end

local shown = 0 -- 0 (gone) to 1 (on), eased
RunService.RenderStepped:Connect(function(dt)
	local want = player:GetAttribute("Holding") ~= nil
	shown = math.clamp(shown + (if want then dt else -dt) / FADE, 0, 1)
	if shown <= 0 then
		if holder then
			holder.Parent = nil
		end
		return
	end
	local area = myArea()
	if not area then
		return
	end
	if area ~= builtFor or not holder then
		build(area)
	end
	holder.Parent = workspace
	local breath = (1 - math.cos(os.clock() * 2 * math.pi / PERIOD)) / 2 -- 0 to 1
	local function see(base)
		local t = base + (1 - base) * BREATHE * breath
		return 1 - (1 - t) * shown
	end
	local sideSeq = NumberSequence.new({
		NumberSequenceKeypoint.new(0, see(SIDE)),
		NumberSequenceKeypoint.new(0.35, see(0.65)),
		NumberSequenceKeypoint.new(1, 1),
	})
	for _, b in sides do
		b.Transparency = sideSeq
	end
	floor.Transparency = NumberSequence.new(see(FLOOR))
end)

return nil
