-- The HUD (QM's Figma, Oct 24): the boss bar with the boss's name over it (top
-- centre), the Shop / Index / Rebirth buttons (stacked on the right edge), and the Power and Cash counters
-- (bottom left). Laid out in pixels at QM's 1080-tall design size, each image at its own
-- size, and scaled to the screen by a UIScale (screen height / 1080). Text is Montserrat
-- ExtraBold 45, white with a dark outline.
--
-- Counters show the player's Power and Cash attributes (abbreviated: 288T). The boss bar
-- follows the nearest awake boss in workspace.Bosses and hides when there's none (or a popup is open).
-- Under the red sits QM's trail bar, cut to wherever the red was TRAIL_LAG seconds ago,
-- so a hit drops the red and exposes the trail, which follows it down half a second on. The buttons don't open anything yet.
--
-- Images were uploaded from assets/ui (ids in assets/ui/ids.json). The button and counter icons
-- (client/HudIcons) have no outline of their own: client/Outline gives them all the same one,
-- tuned by the OutlineColor / OutlineThickness / TextOutlineThickness attributes on the Hud.
--
-- It's all real objects in StarterGui > Hud for QM to edit in Studio (client/Ui): Root holds
-- the BossBar, the ShopButton / IndexButton / RebirthButton / BackpackButton, the Power and
-- Cash counters, the EggHotbar and the popups. tools/studio/uibake.luau puts them there;
-- in Play this only fills in what's missing and wires them up.
--
--   Hud.start()  -- in Play (on require); tools/studio/uibake.luau calls it in Edit mode

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local HudIcons = require(script.Parent.HudIcons)
local Outline = require(script.Parent.Outline)
local Popups = require(script.Parent.Popups)
local Ui = require(script.Parent.Ui)
local Snappy = require(script.Parent.Snappy)

local Hud = {}

local IMAGES = {
	BossBarFill = "rbxassetid://139297500668654",
	BossBarBack = "rbxassetid://88593547866423",
	BossBarTrail = "rbxassetid://110382419429261", -- QM's TRAIL 1
}
local DESIGN_HEIGHT = 1080
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local TEXT = 45
local BAR_EASE = 25 -- how fast the red catches up with the health (quick, not a pop)
local TRAIL_LAG = 0.5 -- seconds the trail bar lags behind the red (QM, Oct 24)
local FILL_IN = 0.4 -- seconds the bar takes to fill from empty when a fight starts (QM, Oct 25)

local player = Players.LocalPlayer

local function text(parent, name, props)
	local label, fresh = Ui.make(parent, name, "TextLabel")
	Outline.text(label) -- (QM's one outline: client/Outline)
	if not fresh then
		return label
	end
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

-- 288, 1.5K, 12M, 288T ...
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
function Hud.abbreviate(n)
	n = math.floor(n or 0)
	local i = 1
	while math.abs(n) >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	local s = if math.abs(n) < 10 then string.format("%.1f", n) else tostring(math.floor(n))
	return (s:gsub("%.0$", "")) .. SUFFIXES[i]
end

-- hover and press (client/Snappy: a touch faded, no easing; QM wants it snappy)
local function bouncy(button)
	if Ui.live then
		Snappy.hook(button)
	end
end

function Hud.start()
	local gui = Ui.screen("Hud", {
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	Outline.settings(gui) -- (the outline's colour and widths, as attributes on the Hud)

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

	-- buttons: QM's icons with no outline of their own, Outline putting the same one on all of
	-- them, and the name under each as a label (Oct 26: the outlines had all been different).
	-- Each is a see-through ImageButton holding Art (Outline.icon: the ring, then the icon) and
	-- Label, laid out as in QM's Figma: a 128 icon with its 30px name `labelTop` px down it.
	local hudFrames = {} -- (hidden while a popup is open)
	local LABEL_TEXT = 30 -- (at the 128 icon size; scaled with the button)
	local function iconButton(name, art, labelTop, scale, props)
		local button, fresh = Ui.make(root, name, "ImageButton")
		if fresh then
			button.BackgroundTransparency = 1
			button.Image = ""
			button.Size = UDim2.fromOffset(math.round(128 * scale), math.round((labelTop + 37) * scale))
			for k, v in props do
				button[k] = v
			end
		end
		-- (the icon and label follow the button's size: resize the button and the icon grows with
		-- it, while its outline stays OutlineThickness wide)
		local height = labelTop + 37
		local holder = Outline.icon(button, "Art", HudIcons[art], HudIcons[art .. "Mask"], {
			AnchorPoint = Vector2.new(0.5, 0.5), -- (centred, so the hover grows and turns it in place)
			Position = UDim2.fromScale(0.5, 64 / height),
			Size = UDim2.fromScale(1, 128 / height),
		})
		Ui.make(holder, "Square", "UIAspectRatioConstraint")
		if holder.AnchorPoint == Vector2.new(0.5, 0) then
			-- (baked before the hover turned it: centre it, where it was, so it turns in place)
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position = UDim2.fromScale(0.5, 64 / height)
		end
		text(button, "Label", {
			Text = art,
			TextSize = math.round(LABEL_TEXT * scale),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, labelTop / height),
			Size = UDim2.fromOffset(math.round(200 * scale), math.round(37 * scale)),
			ZIndex = 3,
		})
		bouncy(button)
		if Ui.live then
			button.Activated:Connect(function()
				Popups.toggle(art)
			end)
		end
		table.insert(hudFrames, button)
		return button
	end

	-- stacked down the right edge, centred on the screen's middle (QM's mockup, Oct 26).
	-- They stay up during fights now, beside the boss bar, as in the mockup.
	local SIDE_SCALE = 0.75 -- times the 128 icon (QM, Oct 26: they were too big)
	local SIDE_MARGIN = 30 -- design px from the right edge
	local SIDE_GAP = math.round(165 * SIDE_SCALE) -- design px between the buttons' centres
	for i, b in { { "Shop", 100 }, { "Index", 99 }, { "Rebirth", 109 } } do
		iconButton(b[1] .. "Button", b[1], b[2], SIDE_SCALE, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -SIDE_MARGIN, 0.5, (i - 2) * SIDE_GAP),
		})
	end

	-- the Backpack button (QM, Oct 25), bottom centre: opens client/Backpack
	iconButton("BackpackButton", "Backpack", 109, 1, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
	})

	-- counters: the icon (outlined like the buttons) on a dark band that fades out to the right
	local counters = {}
	for i, name in { "Power", "Cash" } do
		local row
		row, fresh = Ui.make(root, name, "Frame")
		if fresh then
			row.BackgroundTransparency = 1
			row.AnchorPoint = Vector2.new(0, 1)
			row.Position = UDim2.new(0, 0, 1, -8 - (2 - i) * 103)
			row.Size = UDim2.fromOffset(411, 103)
		end
		table.insert(hudFrames, row)
		local band
		band, fresh = Ui.make(row, "Band", "Frame")
		if fresh then
			-- (QM's Figma band: black at 30% to about halfway, then fading to nothing)
			band.BackgroundColor3 = Color3.new(0, 0, 0)
			band.BorderSizePixel = 0
			band.Position = UDim2.fromOffset(0, 19)
			band.Size = UDim2.new(1, 0, 0, 72)
			local fade = Instance.new("UIGradient")
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.52, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = band
		end
		Outline.icon(row, "Art", HudIcons[name], HudIcons[name .. "Mask"], {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 16, 0.5, 0),
			Size = UDim2.fromOffset(96, 96),
			ZIndex = 2,
		})
		counters[name] = text(row, "Value", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 136, 0.5, 0),
			Size = UDim2.fromOffset(270, 60),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "0",
			ZIndex = 3,
		})
	end

	Popups.abbreviate = Hud.abbreviate
	Popups.init(root, hudFrames)
	require(script.Parent.Backpack).init()
	require(script.Parent.Hotbar).init(root, hudFrames) -- (stolen eggs, right of the Backpack button)
	if not Ui.live then
		return gui
	end

	local function count(name)
		counters[name].Text = Hud.abbreviate(player:GetAttribute(name))
		player:GetAttributeChangedSignal(name):Connect(function()
			counters[name].Text = Hud.abbreviate(player:GetAttribute(name))
		end)
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
		bar.Visible = best ~= nil and not Popups.isOpen()
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
