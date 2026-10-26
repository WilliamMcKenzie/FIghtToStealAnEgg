-- Draws every boss and training mob: the server only has an invisible body in
-- workspace.Bosses (server/Bosses.luau) or workspace.Mobs (server/Training.luau); here
-- each gets its model (the Horse driver with the animal's own data from Shared/Animals,
-- by its Model, ModelSize and Tint attributes, so idle, walk and gallop blend by its speed),
-- stood on the ground under the body and facing its way. When its Health drops it
-- flashes red and the damage pops up over its head; at 0 it stays red as it sinks and shrinks.
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
-- damage numbers: white Montserrat with a soft drop shadow down-right (QM), popping up over its head
local NUMBER_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local NUMBER_SIZE = 20
local NUMBER_SHADOW = 2 -- px the shadow sits down and right
local NUMBER_SHADOW_ALPHA = 0.6 -- shadow transparency
local NUMBER_RISE = 3 -- studs it floats up
local NUMBER_LIFE = 0.7 -- seconds on screen
local DEATH = 0.5 -- seconds it takes to shrink away
local SLEEP = Config.BossSleep
local INTRO = Config.BossIntro
local ZZZ = SLEEP.Zzz
-- Zzz: outlined Montserrat, warm light at the top going cool blue at the bottom (QM's UI)
local ZZZ_GRADIENT = ColorSequence.new(Color3.fromRGB(255, 246, 232), Color3.fromRGB(143, 180, 255))
local ZZZ_OUTLINE = Color3.fromRGB(27, 31, 74)
local SHUT_COLOUR = Color3.fromRGB(30, 23, 40) -- a shut eye's line

local views = {} -- [body] = { animal, last position, colours, hitAt, diedAt }

-- "-10" over the boss's head: pops in, floats up a little off to one side, fades
local function damageNumber(body, amount)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = body
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(160, 40)
	local x = (math.random() - 0.5) * 3
	gui.StudsOffset = Vector3.new(x, body.Size.Y / 2 + 1, 0)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	local function text(colour, offset, z)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Position = UDim2.fromOffset(offset, offset)
		label.ZIndex = z
		label.FontFace = NUMBER_FONT
		label.TextSize = NUMBER_SIZE
		label.TextColor3 = colour
		label.Text = "-" .. tostring(math.round(amount))
		label.Parent = holder
		return label
	end
	local shadow = text(Color3.new(0, 0, 0), NUMBER_SHADOW, 1)
	shadow.TextTransparency = NUMBER_SHADOW_ALPHA
	local label = text(Color3.new(1, 1, 1), 0, 2)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = holder
	holder.Parent = gui
	gui.Parent = body
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(gui, TweenInfo.new(NUMBER_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = gui.StudsOffset + Vector3.new(x * 0.3, NUMBER_RISE, 0),
	}):Play()
	local fade =
		TweenInfo.new(NUMBER_LIFE * 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, NUMBER_LIFE * 0.6)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(shadow, fade, { TextTransparency = 1 }):Play()
	task.delay(NUMBER_LIFE, gui.Destroy, gui)
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
			table.insert(head, { part = part, size = part.Size, joint = joint, c0 = joint and joint.C0, c1 = joint and joint.C1 })
		end
		view.head = head
		view.headRoot = neck
	end
	view.sleep = if body:GetAttribute("Asleep") then 1 else 0
	-- (a boss just summoned rises up out of its dais, growing, once the camera's on it:
	-- client/BossIntro)
	if body:GetAttribute("Intro") then
		view.appearAt = os.clock() + INTRO.PanIn
	end
	views[body] = view
	body:GetAttributeChangedSignal("Health"):Connect(function()
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

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for body, view in views do
		local animal = view.animal
		local pos = body.Position
		local speed = ((pos - view.last) * Vector3.new(1, 0, 1)).Magnitude / math.max(dt, 1e-3)
		view.last = pos
		animal:update(dt, speed, 0)
		if view.diedAt then
			local k = math.clamp((now - view.diedAt) / DEATH, 0, 1)
			animal:setScale(math.max(1 - k, 0.05))
		end
		local ground = pos - Vector3.new(0, body.Size.Y / 2, 0)
		if view.appearAt then
			local k = math.clamp((now - view.appearAt) / INTRO.Appear, 0, 1)
			-- (overshooting a little and settling: an ease-out "back")
			local e = 1 + 2.70158 * (k - 1) ^ 3 + 1.70158 * (k - 1) ^ 2
			animal:setScale(math.max(e, 0.05))
			ground -= Vector3.new(0, body.Size.Y * (1 - math.min(e, 1)), 0)
			if k >= 1 then
				animal:setScale(1)
				view.appearAt = nil
			end
		end
		-- asleep: settled low, snoring (eased in and out as it nods off or gets up)
		local want = if body:GetAttribute("Asleep") then 1 else 0
		view.sleep += math.clamp(want - view.sleep, -dt / SLEEP.Settle, dt / SLEEP.Settle)
		local s = view.sleep * view.sleep * (3 - 2 * view.sleep)
		if not view.pose then
			ground -= Vector3.new(0, body.Size.Y * SLEEP.Sink * s, 0)
		end
		animal.model:PivotTo(CFrame.new(ground) * body.CFrame.Rotation)
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
