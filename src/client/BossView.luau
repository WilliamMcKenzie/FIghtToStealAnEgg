-- Draws every boss and training mob: the server only has an invisible body in
-- workspace.Bosses (server/Bosses.luau) or workspace.Mobs (server/Training.luau); here
-- each gets its model (the Horse driver with the animal's own data from Shared/Animals,
-- by its Model, ModelSize and Tint attributes, so idle, walk and gallop blend by its speed),
-- stood on the ground under the body and facing its way. When its Health drops it
-- flashes white and the damage pops up over its head; at 0 it sinks and shrinks. A
-- sleeping boss (Asleep) has Zzz floating over it.
-- Also hands the /boss chat command to the server (BossRequest), and B does the same;
-- /reboss goes as RebossRequest
-- (a key that works whatever chat the place uses).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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
local FLASH = 0.08 -- seconds a hit flashes white
-- damage numbers: red Montserrat with a black outline, popping up over its head (QM)
local NUMBER_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local NUMBER_SIZE = 20
local NUMBER_RISE = 3 -- studs it floats up
local NUMBER_LIFE = 0.7 -- seconds on screen
local DEATH = 0.5 -- seconds it takes to shrink away

local views = {} -- [body] = { animal, last position, colours, flashUntil, diedAt }

-- "-10" over the boss's head: pops in, floats up a little off to one side, fades
local function damageNumber(body, amount)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = body
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(160, 40)
	local x = (math.random() - 0.5) * 3
	gui.StudsOffset = Vector3.new(x, body.Size.Y / 2 + 1, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = NUMBER_FONT
	label.TextSize = NUMBER_SIZE
	label.TextColor3 = Color3.fromRGB(255, 50, 50)
	label.Text = "-" .. tostring(math.round(amount))
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	label.Parent = gui
	gui.Parent = body
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService:Create(gui, TweenInfo.new(NUMBER_LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = gui.StudsOffset + Vector3.new(x * 0.3, NUMBER_RISE, 0),
	}):Play()
	local fade =
		TweenInfo.new(NUMBER_LIFE * 0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, NUMBER_LIFE * 0.6)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	task.delay(NUMBER_LIFE, gui.Destroy, gui)
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
		flashUntil = 0,
		health = body:GetAttribute("Health"),
	}
	views[body] = view
	-- sleeping: Zzz over its head
	local zzz = Instance.new("BillboardGui")
	zzz.Name = "Zzz"
	zzz.Adornee = body
	zzz.Size = UDim2.fromOffset(120, 60)
	zzz.StudsOffset = Vector3.new(2, body.Size.Y / 2 + 2, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = NUMBER_FONT
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(200, 225, 255)
	label.Text = "Zzz"
	local zStroke = Instance.new("UIStroke")
	zStroke.Thickness = 2
	zStroke.Parent = label
	label.Parent = zzz
	zzz.Parent = body
	view.zzz = zzz
	local function sleep()
		zzz.Enabled = body:GetAttribute("Asleep") == true
	end
	sleep()
	body:GetAttributeChangedSignal("Asleep"):Connect(sleep)
	body:GetAttributeChangedSignal("Health"):Connect(function()
		local health = body:GetAttribute("Health")
		if health < view.health then
			view.flashUntil = os.clock() + FLASH
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

for _, name in { "Bosses", "Mobs" } do
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
		if view.zzz.Enabled then
			view.zzz.StudsOffset =
				Vector3.new(2 + math.sin(now * 1.3) * 0.6, body.Size.Y / 2 + 2 + math.sin(now * 2) * 0.4, 0)
		end
		if view.diedAt then
			local k = math.clamp((now - view.diedAt) / DEATH, 0, 1)
			animal:setScale(math.max(1 - k, 0.05))
		end
		local ground = pos - Vector3.new(0, body.Size.Y / 2, 0)
		animal.model:PivotTo(CFrame.new(ground) * body.CFrame.Rotation)
		local flashing = now < view.flashUntil
		if flashing ~= view.flashing then
			view.flashing = flashing
			for part, colour in view.colours do
				part.Color = if flashing then Color3.new(1, 1, 1) else colour
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
