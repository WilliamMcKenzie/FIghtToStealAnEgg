-- The feel of the screen UI (QM, Oct 30: "make sure the buttons are satisfying to click/use
-- and all the popups feel dynamic while also being snappy (as in they pop in yk)"): UI
-- sounds, the press on every button and the pop of every popup. Shared by the HUD, the
-- side panels, the Weapon Shop and anything new (the Shop and Index screens): use these
-- rather than tweening a popup's Visible yourself.
--
--   UiFx.play(name)              -- a UI sound, 2D (not Sfx.play's on-screen world logic):
--                                -- Click, Hover, Open, Close, Buy, Claim, Error, Equip
--                                -- (ids in Config.UiSounds)
--   UiFx.centre(b)               -- anchors b on its middle (0.5, 0.5) without moving it, so a
--                                -- UIScale grows it from there, not its top left (QM, Oct 30).
--                                -- UiFx.button does it to every button
--   UiFx.button(b, sound?)       -- a button that ducks in when pressed and bounces back on
--                                -- release, with a click (`sound`, default "Click"; false:
--                                -- silent) and a soft tick when the mouse comes onto it.
--                                -- Works with HudKit's hover (they share its Hover UIScale);
--                                -- once per button, a second call does nothing
--   UiFx.popIn(gui, sound?)      -- shows a popup: it pops from small past full size and
--                                -- settles (POP_IN), with the Open sound
--   UiFx.popOut(gui, sound?)     -- shrinks it away quickly (POP_OUT) and hides it, with Close
--   UiFx.toggle(gui) -> open     -- popIn if hidden, else popOut
--   UiFx.isOpen(gui)
--   UiFx.shake(guiObject)        -- a quick no-no wiggle sideways (a failed buy), with Error
--
-- popIn/popOut scale the popup's UIScale (its Pop, made if it has none), so its Size and
-- Position stay what QM set in Studio.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local UiFx = {}

local SOUNDS = Config.UiSounds or {}
local PRESS = 0.88 -- a pressed button's size, of its normal (or hovered) one
local PRESS_IN = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_OUT = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out) -- (the bounce)
local POP_FROM = 0.6 -- a popup starts this size...
local POP_IN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out) -- ...overshoots and settles
local POP_TO = 0.7 -- and shrinks to this as it goes
local POP_OUT = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local HOVER_GAP = 0.05 -- seconds between hover ticks (sweeping over a row stays quiet)

-- ---- sounds -----------------------------------------------------------------------------

-- (only in Play: required while the UI's baked in Edit too, and that mustn't add to the place)
local live = RunService:IsRunning()
local folder = Instance.new("Folder")
folder.Name = "UiSounds"
folder.Parent = if live then SoundService else nil

local made = {} -- [name] = the Sound copied for each play
for name, s in if live then SOUNDS else {} do
	if type(s) == "table" and type(s.id) == "string" and s.id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = s.id
		sound.Volume = s.volume or 0.5
		sound.PlaybackSpeed = s.speed or 1
		sound.Parent = folder
		made[name] = sound
	end
end
task.spawn(function()
	local list = {}
	for _, sound in made do
		table.insert(list, sound)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, list)
end)

local lastHover = 0
function UiFx.play(name)
	local sound = made[name]
	if not sound then
		return
	end
	if name == "Hover" then
		local now = os.clock()
		if now - lastHover < HOVER_GAP then
			return
		end
		lastHover = now
	end
	-- (a copy each time, so quick clicks overlap instead of cutting each other off)
	local s = sound:Clone()
	local start = (SOUNDS[name] or {}).start
	if start then
		s.TimePosition = start
	end
	s.Parent = folder
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	task.delay(5, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- ---- buttons ----------------------------------------------------------------------------

local wired = setmetatable({}, { __mode = "k" })

function UiFx.centre(b)
	local a = b.AnchorPoint
	if a == Vector2.new(0.5, 0.5) then
		return
	end
	-- (a list or grid places its children itself, by their top left: leave those be)
	local parent = b.Parent
	if parent and parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return
	end
	local size, pos = b.Size, b.Position
	b.Position = UDim2.new(
		pos.X.Scale + (0.5 - a.X) * size.X.Scale,
		pos.X.Offset + math.round((0.5 - a.X) * size.X.Offset),
		pos.Y.Scale + (0.5 - a.Y) * size.Y.Scale,
		pos.Y.Offset + math.round((0.5 - a.Y) * size.Y.Offset)
	)
	b.AnchorPoint = Vector2.new(0.5, 0.5)
end

function UiFx.button(b, sound)
	if wired[b] then
		return
	end
	wired[b] = true
	UiFx.centre(b)
	local scale = b:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "Hover"
		scale.Parent = b
	end
	local pressed = false
	-- (the size it rests at: HudKit.hover keeps its grow in the HoverScale attribute)
	local function rest()
		return b:GetAttribute("HoverScale") or 1
	end
	local function release()
		if not pressed then
			return
		end
		pressed = false
		TweenService:Create(scale, PRESS_OUT, { Scale = rest() }):Play()
	end
	b.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			pressed = true
			TweenService:Create(scale, PRESS_IN, { Scale = rest() * PRESS }):Play()
			if sound ~= false then
				UiFx.play(sound or "Click")
			end
		elseif t == Enum.UserInputType.MouseMovement and not pressed then
			UiFx.play("Hover")
		end
	end)
	b.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			release()
		end
	end)
	b.MouseLeave:Connect(release)
	-- (a gamepad or keyboard press has no down and up: just the bounce)
	b.Activated:Connect(function(input)
		if not pressed and input and input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			scale.Scale = rest() * PRESS
			TweenService:Create(scale, PRESS_OUT, { Scale = rest() }):Play()
			if sound ~= false then
				UiFx.play(sound or "Click")
			end
		end
	end)
end

-- ---- popups -----------------------------------------------------------------------------

local function popScale(gui)
	local s = gui:FindFirstChild("Pop") or gui:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "Pop"
		s.Parent = gui
	end
	return s
end

local closing = setmetatable({}, { __mode = "k" }) -- [gui] = the tween hiding it

function UiFx.isOpen(gui)
	return gui.Visible and not closing[gui]
end

function UiFx.popIn(gui, sound)
	if UiFx.isOpen(gui) then
		return
	end
	local out = closing[gui]
	closing[gui] = nil
	if out then
		out:Cancel()
	end
	local s = popScale(gui)
	gui.Visible = true
	s.Scale = POP_FROM
	TweenService:Create(s, POP_IN, { Scale = 1 }):Play()
	if sound ~= false then
		UiFx.play(sound or "Open")
	end
end

function UiFx.popOut(gui, sound)
	if not UiFx.isOpen(gui) then
		return
	end
	local s = popScale(gui)
	local out = TweenService:Create(s, POP_OUT, { Scale = POP_TO })
	closing[gui] = out
	out.Completed:Connect(function(how)
		if how == Enum.PlaybackState.Completed and closing[gui] == out then
			closing[gui] = nil
			gui.Visible = false
			s.Scale = 1
		end
	end)
	out:Play()
	if sound ~= false then
		UiFx.play(sound or "Close")
	end
end

function UiFx.toggle(gui)
	if UiFx.isOpen(gui) then
		UiFx.popOut(gui)
		return false
	end
	UiFx.popIn(gui)
	return true
end

-- ---- feedback ---------------------------------------------------------------------------

function UiFx.shake(g)
	UiFx.play("Error")
	if g:GetAttribute("Shaking") then
		return
	end
	g:SetAttribute("Shaking", true)
	local at = g.Position
	task.spawn(function()
		for _, dx in { 10, -8, 6, -3, 0 } do
			TweenService:Create(g, TweenInfo.new(0.035), { Position = at + UDim2.fromOffset(dx, 0) }):Play()
			task.wait(0.035)
		end
		g.Position = at
		g:SetAttribute("Shaking", nil)
	end)
end

return UiFx
