-- The HUD (QM's NewUI Figma page, Oct 27, after the old UI was wiped): the boss bar with the
-- boss's name over it (top centre); the green Shop and blue Index buttons (left middle); the
-- red Eggs and orange Pets buttons (right middle); the Power counter, with its little orange
-- + button, and the Cash counter (bottom left); and the hotbar (bottom centre: client/Hotbar).
-- The buttons don't open anything yet (their popups come next).
--
-- Laid out in pixels at a 1080-tall design size and scaled to the screen by a UIScale
-- (screen height / 1080). QM's Figma frame is 2190 tall, so its numbers go through fig().
-- The buttons' backs and the icons are QM's Figma layers exported as they are
-- (assets/ui/hud, ids in client/HudImages). Text is Montserrat ExtraBold, white with a black
-- outline; the counters' is italic.
--
-- The boss bar follows the nearest awake boss in workspace.Bosses and hides when there's none.
-- Under the red sits QM's trail bar, cut to wherever the red was TRAIL_LAG seconds ago,
-- so a hit drops the red and exposes the trail, which follows it down half a second on.
--
-- It's all real objects in StarterGui > Hud > Root for QM to edit in Studio (client/Ui):
-- BossBar, ShopButton, IndexButton, EggsButton, PetsButton, Power, Cash and Hotbar.
-- tools/studio/uibake.luau puts them there; in Play this only fills in what's missing and
-- wires them up.
--
--   Hud.start()  -- in Play (on require); tools/studio/uibake.luau calls it in Edit mode

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local HudImages = require(script.Parent.HudImages)
local Hotbar = require(script.Parent.Hotbar)
local Ui = require(script.Parent.Ui)
local RegionBlocker = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RegionBlocker"))

local Hud = {}

local IMAGES = {
	BossBarFill = "rbxassetid://139297500668654",
	BossBarBack = "rbxassetid://88593547866423",
	BossBarTrail = "rbxassetid://110382419429261", -- QM's TRAIL 1
}
local DESIGN_HEIGHT = 1080
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local TEXT = 47 -- (QM, Oct 26: 2px up)
local OUTLINE = Color3.fromRGB(4, 4, 53)
local ITALIC = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Italic)
local BLACK = Color3.new(0, 0, 0)
local FIGMA_HEIGHT = 2190 -- (QM's NewUI frame)
local HOVER_GROW = 1.08 -- a button grows this much under the mouse (QM: snappy)

-- Figma px to design px
local function fig(n)
	return math.round(n * DESIGN_HEIGHT / FIGMA_HEIGHT)
end
local BAR_EASE = 25 -- how fast the red catches up with the health (quick, not a pop)
local TRAIL_LAG = 0.5 -- seconds the trail bar lags behind the red (QM, Oct 24)
local FILL_IN = 0.4 -- seconds the bar takes to fill from empty when a fight starts (QM, Oct 25)

local player = Players.LocalPlayer

local function text(parent, name, props)
	local label, fresh = Ui.make(parent, name, "TextLabel")
	if not fresh then
		return label
	end
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = OUTLINE
	stroke.Thickness = 3
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextSize = TEXT
	label.TextColor3 = Color3.new(1, 1, 1)
	for k, v in props do
		label[k] = v
	end
	return label
end

-- IMAGES[art] as `name`
local function image(parent, name, art, props)
	local img, fresh = Ui.make(parent, name, "ImageLabel")
	if fresh then
		img.BackgroundTransparency = 1
		img.Image = IMAGES[art]
		for k, v in props do
			img[k] = v
		end
	end
	return img
end

function Hud.start()
	local gui = Ui.screen("Hud", {
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- everything inside `root` is in design pixels; the UIScale fits it to the screen
	-- (set here in Play: in Studio it's left at the size of the window it was baked in)
	local root, fresh = Ui.make(gui, "Root", "Frame")
	if fresh then
		root.BackgroundTransparency = 1
		root.Size = UDim2.fromScale(1, 1)
	end
	local uiScale = Ui.make(root, "Fit", "UIScale")
	local function fit()
		local h = workspace.CurrentCamera.ViewportSize.Y
		uiScale.Scale = h / DESIGN_HEIGHT
		-- (the root is scaled down, so it's made bigger by the same factor to fill the screen)
		root.Size = UDim2.fromScale(1 / uiScale.Scale, 1 / uiScale.Scale)
	end
	fit()
	if Ui.live then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- boss bar
	local bar
	bar, fresh = Ui.make(root, "BossBar", "Frame")
	if fresh then
		bar.BackgroundTransparency = 1
		bar.AnchorPoint = Vector2.new(0.5, 0)
		bar.Position = UDim2.new(0.5, 0, 0, 44)
		bar.Size = UDim2.fromOffset(646, 91)
		bar.Visible = not Ui.live -- (shown in Studio to edit; in Play only in a fight)
	end
	image(bar, "BossBarBack", "BossBarBack", { Size = UDim2.fromScale(1, 1) })
	local trailClip
	trailClip, fresh = Ui.make(bar, "TrailClip", "Frame")
	if fresh then
		trailClip.BackgroundTransparency = 1
		trailClip.ClipsDescendants = true
		trailClip.Size = UDim2.fromScale(1, 1)
	end
	local trailImage = image(trailClip, "BossBarTrail", "BossBarTrail", { Size = UDim2.fromOffset(646, 91) })
	local clip
	clip, fresh = Ui.make(bar, "Clip", "Frame")
	if fresh then
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(1, 1)
	end
	image(clip, "BossBarFill", "BossBarFill", { Size = UDim2.fromOffset(646, 91) })
	local bossName = text(bar, "BossName", {
		Text = "BOSS",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(600, 50),
		ZIndex = 3,
	})


	-- ---- QM's NewUI ---------------------------------------------------------------------

	-- a Figma layer exported as it is (HudImages[name])
	local function art(parent, name, props)
		local img, fresh = Ui.make(parent, name, "ImageLabel")
		if fresh then
			img.BackgroundTransparency = 1
			img.Image = HudImages[name] or ""
			img.ScaleType = Enum.ScaleType.Fit
			for k, v in props do
				img[k] = v
			end
		end
		return img
	end

	-- outlined text (Figma: Montserrat ExtraBold 60, a black outline)
	local function label(parent, name, props)
		local l, fresh = Ui.make(parent, name, "TextLabel")
		if fresh then
			local stroke = Instance.new("UIStroke")
			stroke.Name = "Outline"
			stroke.Color = BLACK
			stroke.Thickness = 3
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Parent = l
			l.BackgroundTransparency = 1
			l.FontFace = FONT
			l.TextSize = fig(60)
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextXAlignment = Enum.TextXAlignment.Left
			for k, v in props do
				l[k] = v
			end
		end
		return l
	end

	-- a see-through button `w` x `h` (Figma px) whose back is the exported layer (it holds
	-- the black outline, 8 Figma px past the button's edge all round)
	local function button(parent, name, w, h, props)
		local b, fresh = Ui.make(parent, name, "ImageButton")
		if fresh then
			b.BackgroundTransparency = 1
			b.Image = ""
			b.AutoButtonColor = false
			b.Size = UDim2.fromOffset(fig(w), fig(h))
			for k, v in props do
				b[k] = v
			end
		end
		art(b, name, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, fig(16), 1, fig(16)),
			ScaleType = Enum.ScaleType.Stretch,
		})
		local grow = Ui.make(b, "Hover", "UIScale")
		if Ui.live then
			local function to(scale)
				TweenService:Create(grow, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = scale }):Play()
			end
			b.MouseEnter:Connect(function()
				to(HOVER_GROW)
			end)
			b.MouseLeave:Connect(function()
				to(1)
			end)
		end
		return b
	end

	-- Shop and Index, left middle: 384 x 128, the icon (88) 49 in, the name 174 in
	for i, name in { "Shop", "Index" } do
		local b = button(root, name .. "Button", 384, 128, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, fig(30), 0.5, (i - 1) * fig(172)),
		})
		art(b, name .. "Icon", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, fig(49), 0.5, 0),
			Size = UDim2.fromOffset(fig(88), fig(88)),
			ZIndex = 2,
		})
		label(b, "Label", {
			Text = name,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, fig(174), 0.5, 0),
			Size = UDim2.fromOffset(fig(190), fig(73)),
			ZIndex = 2,
		})
	end

	-- Eggs and Pets, right middle: 128 squares, a 96 icon in each
	for i, name in { "Eggs", "Pets" } do
		local b = button(root, name .. "Button", 128, 128, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -fig(30), 0.5, (i - 1) * fig(163)),
		})
		art(b, name .. "Icon", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(fig(96), fig(96)),
			ZIndex = 2,
		})
	end

	-- the counters, bottom left: a 160 icon on a black band fading out to the right, the
	-- number in italics (Cash's in green); Power has an orange + button over its icon
	local counters = {}
	for _, c in {
		{ name = "Power", bottom = 256, band = 66, text = 177, color = Color3.new(1, 1, 1) },
		{ name = "Cash", bottom = 81, band = 44, text = 185, color = Color3.fromRGB(0, 255, 0) },
	} do
		local row
		row, fresh = Ui.make(root, c.name, "Frame")
		if fresh then
			row.BackgroundTransparency = 1
			row.AnchorPoint = Vector2.new(0, 1)
			row.Position = UDim2.new(0, 0, 1, -fig(c.bottom))
			row.Size = UDim2.fromOffset(fig(411), fig(160))
		end
		local band
		band, fresh = Ui.make(row, "Band", "Frame")
		if fresh then
			-- (black at 30% to 54% of the way, then fading to nothing)
			band.BackgroundColor3 = BLACK
			band.BorderSizePixel = 0
			band.Position = UDim2.fromOffset(0, fig(c.band))
			band.Size = UDim2.new(1, 0, 0, fig(72))
			local fade = Instance.new("UIGradient")
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.54, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = band
		end
		art(row, c.name .. "Icon", {
			Position = UDim2.fromOffset(fig(11), 0),
			Size = UDim2.fromOffset(fig(160), fig(160)),
			ZIndex = 2,
		})
		counters[c.name] = label(row, "Value", {
			Text = "0",
			FontFace = ITALIC,
			TextColor3 = c.color,
			Position = UDim2.fromOffset(fig(c.text), fig(c.band)),
			Size = UDim2.fromOffset(fig(230), fig(72)),
			ZIndex = 3,
		})
		if c.name == "Power" then
			local add = button(row, "AddPowerButton", 64, 64, {
				Position = UDim2.fromOffset(fig(77), fig(107)),
				ZIndex = 4,
			})
			label(add, "Plus", {
				Text = "+",
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
			})
		end
	end

	Hotbar.init(root, fig)

	if not Ui.live then
		return gui
	end

	local function count(name)
		local function show()
			counters[name].Text = RegionBlocker.abbreviate(player:GetAttribute(name) or 0)
		end
		show()
		player:GetAttributeChangedSignal(name):Connect(show)
	end
	count("Power")
	count("Cash")

	-- (no Roblox health bar in the top right: QM, Oct 25)
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Health, false) then
				return
			end
			task.wait(1)
		end
	end)

	-- the boss bar follows the nearest living, awake boss within BAR_RANGE
	bar.Visible = false
	local BAR_RANGE = 260
	local shown = 1 -- the red's width
	local history = {} -- { { os.clock(), red width }, ... } over the last TRAIL_LAG seconds
	local following = nil
	local filling = 0 -- (os.clock() the bar started filling up from empty)
	RunService.RenderStepped:Connect(function(dt)
		local folder = workspace:FindFirstChild("Bosses")
		local character = player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart")
		local best, bestDist = nil, math.huge
		if folder and me then
			for _, body in folder:GetChildren() do
				-- (awake ones close enough to matter: the arenas' sleeping bosses don't count)
				if
					body:IsA("BasePart")
					and (body:GetAttribute("Health") or 0) > 0
					and not body:GetAttribute("Asleep")
				then
					local d = (body.Position - me.Position).Magnitude
					if d < bestDist and d < BAR_RANGE then
						best, bestDist = body, d
					end
				end
			end
		end
		bar.Visible = best ~= nil
		if not best then
			following = nil
			return
		end
		local fraction = math.clamp(best:GetAttribute("Health") / best:GetAttribute("MaxHealth"), 0, 1)
		local now = os.clock()
		if best ~= following then
			following = best
			shown = 0
			filling = now
			table.clear(history)
			bossName.Text = string.upper(best:GetAttribute("Name") or best:GetAttribute("Kind") or "Boss")
		end
		if now - filling < FILL_IN then
			-- (a new fight: up from empty, easing out, to its health)
			local t = (now - filling) / FILL_IN
			shown = fraction * (1 - (1 - t) ^ 3)
			table.clear(history)
		else
			shown += (fraction - shown) * (1 - math.exp(-dt * BAR_EASE))
		end
		clip.Size = UDim2.fromScale(shown, 1)

		-- the trail: the red's width TRAIL_LAG seconds ago (the oldest sample not newer)
		table.insert(history, { now, shown })
		local lagged = history[1][2]
		while #history > 1 and history[2][1] <= now - TRAIL_LAG do
			table.remove(history, 1)
			lagged = history[1][2]
		end
		-- (only the stretch the red has left behind: cropped from the left at the red's edge, so
		-- it never sits under the red, and it's gone when they meet; QM, Oct 25)
		local from, to = shown, math.max(lagged, shown)
		trailClip.Position = UDim2.fromScale(from, 0)
		trailClip.Size = UDim2.fromScale(to - from, 1)
		trailImage.Position = UDim2.fromOffset(-from * trailImage.Size.X.Offset, 0)
	end)
	return gui
end

if Ui.live then
	task.spawn(Hud.start) -- (it waits for StarterGui's copy, which comes with the character)
end

return Hud
