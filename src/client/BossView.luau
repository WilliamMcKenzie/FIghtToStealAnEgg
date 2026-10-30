-- Draws every boss and training mob: the server only has an invisible body in
-- workspace.Bosses (server/Bosses.luau) or workspace.Mobs (server/Training.luau); here
-- each gets its model (the Horse driver with the animal's own data from Shared/Animals,
-- by its Model, ModelSize and Tint attributes, so idle, walk and gallop blend by its speed),
-- stood on the ground under the body and facing its way. When its Health drops it
-- flashes red and the damage pops up over its head; at 0 it stays red as it sinks and shrinks.
-- A burrowing boss (the Sandworm: its Burrow attribute, Server/Bosses) stands reared up out
-- of the ground in its Config Burrow.Pose (no hole drawn: QM), rises out of the ground as
-- it surfaces (head pointing up, then bending forward to look at you) and drops back down,
-- and isn't drawn while it tunnels: LassoAPet's burrow runs over the ground instead
-- (client/BurrowFx).
-- Also hands the /boss chat command to the server (BossRequest), and B does the same;
-- /reboss goes as RebossRequest
-- (a key that works whatever chat the place uses).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Horse = require(Shared.Animals.Horse)
local BossTuning = require(Shared.BossTuning)
local BurrowFx = require(script.Parent.BurrowFx)
local DamageNumbers = require(script.Parent.DamageNumbers)
local OnScreen = require(script.Parent.OnScreen)

-- Recolours (a mob's Tint): each part's colour through fn, the rest of the data shared
local TINTS = {
	-- the Desert's sand crabs: the King Crab's red shell gone sandy (QM, Oct 24); its
	-- greys and blacks (eyes) stay
	Sand = function(c)
		local h, s, v = c:ToHSV()
		if s < 0.25 then
			return c
		end
		return Color3.fromHSV(0.09 + (h > 0.5 and 0 or h * 0.1), s * 0.55, math.min(1, v * 1.02 + 0.06))
	end,
}
local kinds = {} -- [model .. size .. tint] = Horse variant
local function kindOf(body)
	local model, size, tint = body:GetAttribute("Model"), body:GetAttribute("ModelSize") or 1, body:GetAttribute("Tint")
	if not model then
		return nil
	end
	if body.Parent and body.Parent.Name == "Bosses" and body.Parent.Parent == workspace then
		size *= BossTuning.scale() -- (workspace.BossTuning's BossScale: Shared/BossTuning)
	end
	local key = model .. " " .. size .. " " .. tostring(tint)
	if kinds[key] == nil then
		local module = Shared.Animals:FindFirstChild(model .. "Model")
		local data = module and require(module)
		if data and tint and TINTS[tint] then
			local parts = {}
			for i, part in data.parts do
				local copy = table.clone(part)
				if copy.color then
					copy.color = TINTS[tint](copy.color)
				end
				parts[i] = copy
			end
			local tinted = table.clone(data)
			tinted.parts = parts
			data = tinted
		end
		kinds[key] = if data then Horse.variant(model, data, "Boss", { size = size }) else false
	end
	return kinds[key] or nil
end
-- a hit tints it red and the tint fades back out, restarting on every hit; the same as
-- QM's kingdom game (its colour multiplied by #FFB3B3, easing back to its own over 300 ms)
local FLASH = 0.3 -- seconds a hit's tint takes to fade
local FLASH_TINT = Color3.fromRGB(255, 179, 179)
-- (damage numbers: client/DamageNumbers)
local NUMBER_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local DEATH = 0.5 -- seconds it takes to shrink away
local SLEEP = Config.BossSleep
local INTRO = Config.BossIntro
local HATCH = Config.Hatch
local ZZZ = SLEEP.Zzz
-- Zzz: outlined Montserrat, warm light at the top going cool blue at the bottom (QM's UI)
local ZZZ_GRADIENT = ColorSequence.new(Color3.fromRGB(255, 246, 232), Color3.fromRGB(143, 180, 255))
local ZZZ_OUTLINE = Color3.fromRGB(27, 31, 74)
local SHUT_COLOUR = Color3.fromRGB(30, 23, 40) -- a shut eye's line

local views = {} -- [body] = { animal, last position, colours, hitAt, diedAt }

local function damageNumber(body, amount)
	DamageNumbers.pop(body, amount, body.Size.Y / 2 + 1)
end

-- one Z drifting up off a sleeping boss's head (the i-th of its run, each bigger), growing
-- in and fading out
local function zed(view, i)
	local animal = view.animal
	local k = animal.size * animal.scale
	local at = animal.model.PrimaryPart.CFrame.Rotation * (view.pose.Zzz * k)
	local size = ZZZ.Size * k * (1 + 0.25 * (i - 1))
	local gui = Instance.new("BillboardGui")
	gui.Adornee = animal.neck
	gui.LightInfluence = 0
	gui.Size = UDim2.fromScale(size * 0.5, size * 0.5)
	gui.StudsOffsetWorldSpace = at
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = NUMBER_FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 1
	label.Text = "Z"
	local gradient = Instance.new("UIGradient")
	gradient.Color = ZZZ_GRADIENT
	gradient.Rotation = 90
	gradient.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = ZZZ_OUTLINE
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = animal.model
	local rise = ZZZ.Rise * k
	local drift = animal.model.PrimaryPart.CFrame.RightVector * rise / 2
	TweenService:Create(gui, TweenInfo.new(ZZZ.Life, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = at + drift + Vector3.new(0, rise, 0),
	}):Play()
	TweenService:Create(gui, TweenInfo.new(ZZZ.Life / 4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(size, size),
	}):Play()
	local appear = TweenInfo.new(ZZZ.Life / 6)
	TweenService:Create(label, appear, { TextTransparency = 0 }):Play()
	TweenService:Create(stroke, appear, { Transparency = 0 }):Play()
	local fade =
		TweenInfo.new(ZZZ.Life / 3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, ZZZ.Life * 2 / 3)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	task.delay(ZZZ.Life, gui.Destroy, gui)
end

local function add(body)
	if not body:IsA("BasePart") then
		return
	end
	local kind = kindOf(body)
	if not kind then
		return
	end
	local animal = kind.new()
	animal.model.Name = body.Name .. "View"
	animal.model.Parent = workspace
	local colours = {}
	for _, part in animal.model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			colours[part] = part.Color
		end
	end
	local view = {
		animal = animal,
		last = body.Position,
		-- where the server last put it (its body's CFrame as it last arrived), when, and how
		-- fast it was going between the last two (see SMOOTH)
		sample = body.CFrame,
		sampleAt = os.clock(),
		velocity = Vector3.zero,
		shown = body.CFrame,
		colours = colours,
		health = body:GetAttribute("Health"),
	}
	-- (the head, for snoring: the neck bone and everything hung off it, their sizes and
	-- joint offsets as built, so it can swell about the neck's pivot)
	-- (a Model with a sleeping pose lies down in it instead: its eyes to shut and pupils to
	-- hide while it does)
	local pose = SLEEP.Poses[body:GetAttribute("Model")]
	if pose then
		view.pose = pose
		view.phase = math.random() -- (so a server's bosses don't all breathe together)
		view.shut, view.hidden = {}, {}
		-- (sizes as built, at this scale: Model:ScaleTo scales from whatever a part's size is
		-- now, so a shut or opened eye is sized for the animal's scale at the time, or the
		-- intro's grow from tiny blows it up 20x)
		view.shutScale = animal.scale
		view.eyesShut = false
		for _, part in animal.model:GetChildren() do
			if table.find(pose.Shut, part.Name) then
				-- (a shut eye squashes along whichever of its two broad sides stands most upright)
				local size, cf = part.Size, part.CFrame
				local axes = { cf.RightVector, cf.UpVector, cf.LookVector }
				local sides = { size.X, size.Y, size.Z }
				local thin = table.find(sides, math.min(size.X, size.Y, size.Z))
				local best, squash = -1, 2
				for i = 1, 3 do
					local up = math.abs(axes[i]:Dot(animal.model.PrimaryPart.CFrame.UpVector))
					if i ~= thin and up > best then
						best, squash = up, i
					end
				end
				local k = { 1, 1, 1 }
				k[squash] = 0.18
				view.shut[part] = { size = size, squashed = size * Vector3.new(k[1], k[2], k[3]) }
			elseif table.find(pose.Hide, part.Name) then
				view.hidden[part] = part.Transparency
			end
		end
	end
	local neck = not pose and animal.model:FindFirstChild("neckBone")
		or animal.model:FindFirstChild("HeadBone")
		or animal.model:FindFirstChild("FlowerBone") -- (the Rafflesia's head is its flower)
	if neck then
		local inHead = { [neck] = true }
		local head = {}
		for _, part in animal.model:GetDescendants() do
			if part:IsA("BasePart") then
				local p, chain = part, {}
				while p and p ~= neck and not inHead[p] do
					table.insert(chain, p)
					local joint = p:FindFirstChildWhichIsA("JointInstance")
					p = joint and joint.Part0
				end
				if p == neck or inHead[p] then
					for _, q in chain do
						inHead[q] = true
					end
				end
			end
		end
		for part in inHead do
			local joint = part:FindFirstChildWhichIsA("JointInstance")
			table.insert(
				head,
				{ part = part, size = part.Size, joint = joint, c0 = joint and joint.C0, c1 = joint and joint.C1 }
			)
		end
		view.head = head
		view.headRoot = neck
	end
	view.sleep = if body:GetAttribute("Asleep") then 1 else 0
	-- (a boss just summoned rises up out of its dais, growing, once the camera's on it:
	-- client/BossIntro)
	if body:GetAttribute("Intro") then
		view.appearAt = os.clock() + INTRO.PanIn
		view.appearFor = INTRO.Appear
	end
	-- (a boss's minion drops out of the sky onto its spot, its shadow growing under it:
	-- Server/Minions. On server time, so one that's already landed is just stood there)
	local dropAt = body:GetAttribute("DropAt")
	if dropAt and workspace:GetServerTimeNow() < dropAt + body:GetAttribute("Drop") then
		view.drop = {
			at = dropAt,
			time = body:GetAttribute("Drop"),
			from = body:GetAttribute("DropFrom") or 60,
			dust = body:GetAttribute("Dust") or Color3.fromRGB(226, 190, 128),
			radius = body:GetAttribute("Radius") or 2,
		}
	end
	-- (a pen pet just hatched: hidden till its egg's top pops off, then it jumps out,
	-- LassoAPet's hatch; server time HatchPop, from HatchFrom studs up: Server/Pens)
	local pop = body:GetAttribute("HatchPop")
	if pop and workspace:GetServerTimeNow() < pop + HATCH.JumpTime then
		view.hatchPop, view.hatchFrom = pop, body:GetAttribute("HatchFrom") or 0
		animal.model.Parent = nil
	end
	if body:GetAttribute("Burrow") then
		local c = Config.Bosses[body:GetAttribute("Kind")]
		view.burrow = c and c.Burrow and { cfg = c.Burrow, radius = body:GetAttribute("Radius") or 4 }
	end
	views[body] = view
	view.healthChanged = body:GetAttributeChangedSignal("Health"):Connect(function()
		local health = body:GetAttribute("Health")
		if health < view.health then
			view.hitAt = os.clock()
			damageNumber(body, view.health - health)
		end
		view.health = health
		if health <= 0 and not view.diedAt then
			view.diedAt = os.clock()
		end
	end)
end

local function remove(body)
	local view = views[body]
	if view then
		local w = view.burrow
		if w and w.mound then
			w.mound:stop()
		end
		if view.drop and view.drop.shadow then
			view.drop.shadow:Destroy()
		end
		if view.shield then
			view.shield:Destroy()
		end
		view.healthChanged:Disconnect()
		view.animal.model:Destroy()
		views[body] = nil
	end
end

for _, name in { "Bosses", "Mobs", "PenPets" } do
	task.spawn(function()
		local folder = workspace:WaitForChild(name)
		for _, body in folder:GetChildren() do
			add(body)
		end
		folder.ChildAdded:Connect(add)
		folder.ChildRemoved:Connect(remove)
	end)
end

-- workspace.BossTuning (Shared/BossTuning): a new BossScale redraws the bosses out now at
-- it, and its Boss line says which is out and the Config Size that scale comes to
local function tuned()
	local tuning, bossFolder = BossTuning.folder(), workspace:FindFirstChild("Bosses")
	if not (tuning and bossFolder) then
		return
	end
	local k = BossTuning.scale()
	local out = {}
	for _, body in bossFolder:GetChildren() do
		local c = Config.Bosses[body:GetAttribute("Kind")]
		if c then
			local size = (body:GetAttribute("ModelSize") or 1) * k
			local which = if c.StandIn and body:GetAttribute("Model") ~= c.Model then "StandIn size" else "Size"
			table.insert(out, string.format("%s: %s = %.3g", body:GetAttribute("Kind"), which, size))
		end
	end
	tuning:SetAttribute("Boss", table.concat(out, "; "))
end
task.spawn(function()
	local tuning = workspace:WaitForChild("BossTuning")
	local bossFolder = workspace:WaitForChild("Bosses")
	tuning:GetAttributeChangedSignal("BossScale"):Connect(function()
		for _, body in bossFolder:GetChildren() do
			if views[body] and not views[body].diedAt then
				remove(body)
				add(body)
			end
		end
		tuned()
	end)
	bossFolder.ChildAdded:Connect(tuned)
	bossFolder.ChildRemoved:Connect(tuned)
	tuned()
end)

-- a boss's Magic shot (Server/BossAttacks' BossShot): a Pulse attack pulses its head
task.spawn(function()
	ReplicatedStorage:WaitForChild("BossShot").OnClientEvent:Connect(function(body, i)
		local view = views[body]
		local c = view and Config.Bosses[body:GetAttribute("Kind")]
		local a = c and c.Attacks and c.Attacks[i]
		if a and a.Pulse then
			view.shotAt, view.shotGap = os.clock(), a.BurstGap or a.Every or 0.5
		end
	end)
end)

-- a boss's attack winding up (Server/BossAttacks' BossAnim): its model plays the attack's
-- animation, sped up or slowed so the animation's `hit` lands as the attack does
task.spawn(function()
	ReplicatedStorage:WaitForChild("BossAnim").OnClientEvent:Connect(function(body, name, windup)
		local view = views[body]
		local anim = view and view.animal.data.animations[name]
		if not anim then
			return
		end
		local rate = if anim.hit and windup and windup > 0 then math.clamp(anim.hit / windup, 0.35, 3) else 1
		view.animal:playOnce(name, rate)
	end)
end)

-- a Shield boss's bubble while its troops live (Server/Minions): a big soft force field ball
local SHIELD_COLOR = Color3.fromRGB(255, 120, 120)
local function shieldFrame(body, view, ground)
	local on = body:GetAttribute("Shielded") == true and not view.diedAt
	if on and not view.shield then
		local ball = Instance.new("Part")
		ball.Name = "Shield"
		ball.Shape = Enum.PartType.Ball
		ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
		ball.CastShadow = false
		ball.Material = Enum.Material.ForceField
		ball.Color = SHIELD_COLOR
		ball.Parent = workspace
		view.shield = ball
	elseif not on and view.shield then
		view.shield:Destroy()
		view.shield = nil
	end
	if view.shield then
		local size = math.max(body.Size.X, body.Size.Y) * 1.25
		view.shield.Size = Vector3.one * size
		view.shield.CFrame = CFrame.new(ground + Vector3.new(0, body.Size.Y / 2, 0))
	end
end

-- The server moves each body (anchored) a step at a time, and its moves arrive here a few
-- frames apart and unevenly: drawn straight there, a model would stutter
-- along and its gaits flicker between still and dashing. So it's drawn where its body
-- is heading (its last move carried on a moment, as long as moves keep coming) and eased
-- toward that, like LassoAPet's other riders; its speed is how fast it's drawn moving.
local SMOOTH = 12 -- how quickly the drawn model catches up (1/s; LassoAPet's riders')
local AHEAD = 0.25 -- seconds at most it's carried on past its last move
local STOPPED = 0.2 -- no move for this long and it has stopped
local SNAP = 30 -- studs off and it's put straight there (a teleport, a respawn)

local function follow(body, view, dt, now)
	local cf = body.CFrame
	if cf ~= view.sample then
		local gap = now - view.sampleAt
		view.velocity = if gap > 0 and gap < STOPPED
			then (cf.Position - view.sample.Position) * Vector3.new(1, 0, 1) / gap
			else Vector3.zero
		view.sample, view.sampleAt = cf, now
	elseif now - view.sampleAt > STOPPED then
		view.velocity = Vector3.zero
	end
	local want = CFrame.new(view.velocity * math.min(now - view.sampleAt, AHEAD)) * cf
	if (view.shown.Position - want.Position).Magnitude > SNAP then
		view.shown = want
	else
		view.shown = view.shown:Lerp(want, 1 - math.exp(-SMOOTH * dt))
	end
	return view.shown
end

local function smooth01(k)
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- a burrowing boss, this frame: its sand bursts and burrow -> how far out of the ground it
-- is (0 down its hole, 1 up) and its pose's neck bend (0 head straight up, 1 bent to you)
local function burrowFrame(body, view, dt, ground)
	local w = view.burrow
	local cfg = w.cfg
	local state = body:GetAttribute("Burrow")
	local t = workspace:GetServerTimeNow() - (body:GetAttribute("BurrowAt") or 0)
	local at = Vector3.new(body.Position.X, ground.Y, body.Position.Z)
	if state ~= w.state then
		if state == "Emerge" or (state == "Hide" and w.state ~= nil) then
			BurrowFx.burst(at, w.radius, cfg.Sand)
		end
		if state ~= "Under" and w.mound then
			w.mound:stop()
			w.mound = nil
		end
		w.state = state
	end
	if state == "Under" then
		w.mound = w.mound or BurrowFx.mound(cfg.Mound, { cfg.Sand, cfg.Sand2 })
		w.mound:place(ground)
		return 0, 0
	elseif state == "Emerge" then
		-- (shoots up out of the hole, overshooting a little, head first, then bends to look)
		local k = math.clamp(t / cfg.Emerge, 0, 1)
		local e = 1 + 2.70158 * (k - 1) ^ 3 + 1.70158 * (k - 1) ^ 2
		return e, smooth01((k - 0.35) / 0.65)
	elseif state == "Hide" then
		-- (rears its head back up, then drops straight down the hole)
		local k = math.clamp(t / cfg.Hide, 0, 1)
		return 1 - smooth01((k - 0.15) / 0.85) ^ 2, 1 - smooth01(k / 0.5)
	end
	return 1, 1
end

-- a minion dropping out of the sky, this frame: falls (speeding up, like it's dropped)
-- from its DropFrom studs up onto `ground`, with a dark shadow under it growing and
-- darkening as it comes down; on landing a puff of its Dust and a squash -> where to draw it
local LAND = 0.3 -- seconds the landing squash takes to spring back
local function dropFrame(view, ground)
	local d = view.drop
	local k = math.clamp((workspace:GetServerTimeNow() - d.at) / d.time, 0, 1)
	if not d.shadow then
		d.shadow = Instance.new("Part")
		d.shadow.Shape = Enum.PartType.Cylinder
		d.shadow.Anchored, d.shadow.CanCollide, d.shadow.CanQuery, d.shadow.CanTouch = true, false, false, false
		d.shadow.CastShadow = false
		d.shadow.Material = Enum.Material.SmoothPlastic
		d.shadow.Color = Color3.new(0, 0, 0)
		d.shadow.Parent = workspace
	end
	local size = d.radius * 2 * (0.35 + 0.65 * k)
	d.shadow.Size = Vector3.new(0.05, size, size)
	d.shadow.CFrame = CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	d.shadow.Transparency = 0.85 - 0.35 * k
	if k >= 1 then
		d.shadow:Destroy()
		BurrowFx.burst(ground, d.radius, d.dust)
		view.drop = nil
		view.landAt = os.clock()
		return ground
	end
	return ground + Vector3.new(0, d.from * (1 - k * k), 0)
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for body, view in views do
		local animal = view.animal
		local shown = follow(body, view, dt, now)
		local out, bend = 1, 1
		if view.burrow then
			if body:GetAttribute("Burrow") ~= "Under" then
				-- (it doesn't move while it's up: drawn right on its hole, only its turning eased)
				shown = CFrame.new(body.Position) * shown.Rotation
				view.shown, view.last = shown, body.Position
			end
			out, bend = burrowFrame(body, view, dt, shown.Position - Vector3.new(0, body.Size.Y / 2, 0))
			local hidden = out <= 0 and body:GetAttribute("Burrow") == "Under"
			animal.model.Parent = if hidden then nil else workspace
			if hidden then
				continue
			end
		end
		local pos = shown.Position
		local speed = ((pos - view.last) * Vector3.new(1, 0, 1)).Magnitude / math.max(dt, 1e-3)
		view.last = pos
		-- (off screen, both where it is and where it was last drawn: not animated or moved
		-- this frame, QM Oct 27: dozens of animals' joints every frame lagged the game. It's
		-- always drawn once first, or a new one off screen would hang where its model was
		-- built, all of them in a floating clump)
		local reach = body.Size.Magnitude + 6
		if
			view.drawnAt
			and not view.diedAt
			and not view.appearAt
			and not view.hatchPop
			and not view.drop
			and not view.landAt
			and not OnScreen.near(pos, reach)
			and not OnScreen.near(view.drawnAt, reach)
		then
			view.sleep = if body:GetAttribute("Asleep") then 1 else 0
			continue
		end
		view.drawnAt = pos
		animal:update(dt, speed, 0)
		if view.diedAt then
			local k = math.clamp((now - view.diedAt) / DEATH, 0, 1)
			animal:setScale(math.max(1 - k, 0.05))
		end
		local ground = pos - Vector3.new(0, body.Size.Y / 2, 0)
		if view.appearAt then
			local k = math.clamp((now - view.appearAt) / view.appearFor, 0, 1)
			-- (overshooting a little and settling: an ease-out "back")
			local e = 1 + 2.70158 * (k - 1) ^ 3 + 1.70158 * (k - 1) ^ 2
			animal:setScale(math.max(e, 0.05))
			ground -= Vector3.new(0, body.Size.Y * (1 - math.min(e, 1)), 0)
			if k >= 1 then
				animal:setScale(1)
				view.appearAt = nil
			end
		end
		if view.drop then
			ground = dropFrame(view, ground)
		end
		if view.landAt then
			-- (squashed a little by the landing, springing back to size)
			local k = math.clamp((now - view.landAt) / LAND, 0, 1)
			animal:setScale(1 - 0.18 * (1 - k) * math.cos(k * math.pi * 1.5))
			if k >= 1 then
				animal:setScale(1)
				view.landAt = nil
			end
		end
		-- a Leap (Server/BossAttacks): up in an arc from LeapAt for LeapTime seconds
		local leapAt = body:GetAttribute("LeapAt")
		if leapAt then
			local t = (workspace:GetServerTimeNow() - leapAt) / (body:GetAttribute("LeapTime") or 1)
			if t > 0 and t < 1 then
				ground += Vector3.new(0, (body:GetAttribute("LeapHeight") or 20) * 4 * t * (1 - t), 0)
				view.leaping = true
			elseif t >= 1 and view.leaping then
				-- (landed: a puff and a squash)
				view.leaping = nil
				view.landAt = now
				BurrowFx.burst(ground, body:GetAttribute("Radius") or 4, Color3.fromRGB(200, 196, 190))
			end
		end
		-- a Blink: shrinks away where it was, pops up where it's gone (Server/BossAttacks)
		local blinkAt = body:GetAttribute("BlinkAt")
		if blinkAt then
			local t = (workspace:GetServerTimeNow() - blinkAt) / (body:GetAttribute("BlinkTime") or 1)
			if t >= 0 and t < 1 then
				view.blinking = true
				if t >= 0.5 then
					view.shown = body.CFrame -- (straight there, no sliding over)
					ground = body.Position - Vector3.new(0, body.Size.Y / 2, 0)
				end
				animal:setScale(math.max(math.abs(1 - 2 * t), 0.05))
			elseif view.blinking then
				view.blinking = nil
				animal:setScale(1)
			end
		end
		shieldFrame(body, view, ground)
		if view.hatchPop then
			-- out of the egg in an arc, growing to full size, landing on the spot (LassoAPet's)
			local t = (workspace:GetServerTimeNow() - view.hatchPop) / HATCH.JumpTime
			if t < 0 then
				continue
			end
			t = math.min(t, 1)
			animal.model.Parent = workspace
			animal:setScale(0.2 + 0.8 * (1 - (1 - t) ^ 3))
			ground += Vector3.new(0, view.hatchFrom * (1 - t) + HATCH.JumpHeight * 4 * t * (1 - t), 0)
			if t >= 1 then
				animal:setScale(1)
				view.hatchPop = nil
			end
		end
		-- asleep: settled low, snoring (eased in and out as it nods off or gets up)
		local want = if body:GetAttribute("Asleep") then 1 else 0
		view.sleep += math.clamp(want - view.sleep, -dt / SLEEP.Settle, dt / SLEEP.Settle)
		local s = view.sleep * view.sleep * (3 - 2 * view.sleep)
		if not view.pose then
			ground -= Vector3.new(0, body.Size.Y * SLEEP.Sink * s, 0)
		end
		-- (its root's CFrame, not PivotTo: the root is anchored and every other part hangs off
		-- it by a joint, so this moves the whole model at once, as LassoAPet places its animals)
		if view.burrow then
			-- (down in its hole by however far it is from being up)
			local cfg = view.burrow.cfg
			ground -= Vector3.new(0, cfg.Depth * animal.size * animal.scale * (1 - out), 0)
		end
		animal.model.PrimaryPart.CFrame = CFrame.new(ground) * shown.Rotation
		if view.pose and s > 0 then
			-- lying in its pose, breathing (over whatever idle had it doing, by how asleep it is)
			local pose = view.pose
			local clock = now / SLEEP.Breath + view.phase
			local breath = 0.5 - 0.5 * math.cos(clock * 2 * math.pi)
			local sc = animal.scale * animal.size
			for bone, motor in animal.bones do
				local p, a, b = animal.pose[bone], pose.Bones[bone], pose.Breathe[bone]
				local v = view.blend or {}
				view.blend = v
				for i = 1, 6 do
					v[i] = p[i] + ((a and a[i] or 0) + (b and b[i] * breath or 0) - p[i]) * s
				end
				motor.Transform = CFrame.new(v[1] * sc, v[2] * sc, v[3] * sc) * CFrame.Angles(v[4], v[5], v[6])
			end
			-- a run of Zs as each breath goes out, while it's properly asleep
			local run = math.floor(clock + 0.5)
			if pose.Zzz and run ~= view.zzzRun then
				if view.zzzRun and want == 1 and s > 0.5 then
					for i = 1, ZZZ.Count do
						task.delay((i - 1) * ZZZ.Gap, function()
							if views[body] == view and body:GetAttribute("Asleep") then
								zed(view, i)
							end
						end)
					end
				end
				view.zzzRun = run
			end
		end
		if view.burrow then
			-- reared up out of its hole (its Pose over the animation; the neck's bend by `bend`)
			local sc = animal.scale * animal.size
			for bone, a in view.burrow.cfg.Pose do
				local motor, p = animal.bones[bone], animal.pose[bone]
				if motor and p then
					local k = if bone == "neck" then bend else 1
					motor.Transform = CFrame.new((p[1] + a[1] * k) * sc, (p[2] + a[2] * k) * sc, (p[3] + a[3] * k) * sc)
						* CFrame.Angles(p[4] + a[4] * k, p[5] + a[5] * k, p[6] + a[6] * k)
				end
			end
		end
		if view.pose then
			local shut = s > 0.5
			if shut ~= view.eyesShut then
				view.eyesShut = shut
				for part, eye in view.shut do
					part.Size = (if shut then eye.squashed else eye.size) * (animal.scale / view.shutScale)
					part.Color = if shut then SHUT_COLOUR else view.colours[part]
				end
				for part, transparency in view.hidden do
					part.Transparency = if shut then 1 else transparency
				end
			end
		end
		if view.head then
			local k = 1 + (SLEEP.Snore - 1) * s * (0.5 - 0.5 * math.cos(now / SLEEP.Breath * 2 * math.pi))
			-- (a Pulse attack's shot: its head pulses like a bow, client/BowPulse)
			if view.shotAt then
				local t = (now - view.shotAt) / view.shotGap
				local p = Config.Shots.Pulse
				if t >= p.SettleAt then
					view.shotAt = nil
				elseif t < p.PeakAt then
					k *= p.From + (p.Peak - p.From) * (t / p.PeakAt)
				else
					k *= p.Peak + (1 - p.Peak) * (t - p.PeakAt) / (p.SettleAt - p.PeakAt)
				end
			end
			if math.abs(k - (view.headScale or 1)) > 1e-4 then
				view.headScale = k
				for _, h in view.head do
					h.part.Size = h.size * k
					-- (a joint inside the head swells with it: its offsets from the neck scale too)
					if h.joint and h.part ~= view.headRoot then
						h.joint.C0 = CFrame.new(h.c0.Position * k) * h.c0.Rotation
						h.joint.C1 = CFrame.new(h.c1.Position * k) * h.c1.Rotation
					end
				end
			end
		end
		-- (dying, it holds the full tint while it shrinks away)
		local tint = if view.diedAt then 1 elseif view.hitAt then math.max(1 - (now - view.hitAt) / FLASH, 0) else 0
		if tint > 0 or view.tinted then
			view.tinted = tint > 0
			local g, b = 1 - (1 - FLASH_TINT.G) * tint, 1 - (1 - FLASH_TINT.B) * tint
			for part, colour in view.colours do
				if view.eyesShut and view.shut[part] then
					colour = SHUT_COLOUR -- (a shut eye keeps its dark line under the tint)
				end
				part.Color = Color3.new(colour.R, colour.G * g, colour.B * b)
			end
		end
	end
end)

-- /boss (TextChatService runs a command's Triggered where it's typed: pass it on)
task.spawn(function()
	local request = ReplicatedStorage:WaitForChild("BossRequest")
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.B then
			request:FireServer()
		end
	end)
	local command = TextChatService:FindFirstChild("BossCommand", true)
	local commands = TextChatService:FindFirstChild("TextChatCommands")
	if not command and commands then
		command = commands:WaitForChild("BossCommand", 10)
	end
	if not command then
		command = TextChatService:WaitForChild("BossCommand", 10)
	end
	if command then
		command.Triggered:Connect(function()
			request:FireServer()
		end)
	end
	-- /reboss (the game's owner, or a Studio playtest: the server checks)
	local reboss = (commands or TextChatService):WaitForChild("RebossCommand", 10)
	local rebossRequest = ReplicatedStorage:WaitForChild("RebossRequest", 10)
	if reboss and rebossRequest then
		reboss.Triggered:Connect(function()
			rebossRequest:FireServer()
		end)
	end
end)

return {}
