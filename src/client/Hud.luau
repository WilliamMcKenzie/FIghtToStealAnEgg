-- The HUD (QM's NewUI Figma page, Oct 27, after the old UI was wiped): the boss bar with the
-- boss's name over it (top centre); the green Shop and blue Index buttons (left middle); the
-- red Eggs and orange Pets buttons (right middle); the Power counter, with its little orange
-- + button, and the Cash counter (bottom left); and the hotbar (bottom centre: client/Hotbar).
-- None of the buttons do anything yet (QM, Oct 27: Shop/Index, and the pen tools on the
-- right, come later).
--
-- Laid out in pixels at a 1080-tall design size and scaled to the screen by a UIScale
-- (screen height / 1080). QM's Figma frame is 2190 tall, so its numbers go through fig().
-- The buttons' backs are built natively to QM's Figma (client/HudKit); the icons are its layers exported as they are
-- (assets/ui/hud, ids in client/HudImages; the icons at 64px, QM: less lag). Text is
-- Montserrat ExtraBold, white with a black outline; the counters' is italic. Shop's and
-- Index's white icons get their outline here; the rest have theirs drawn in.
--
-- The boss bar follows the nearest awake boss in workspace.Bosses and hides when there's none.
-- It pops in (a UIScale, Pop) when a fight starts and pops out when it ends, after showing
-- the bar empty for a moment if the boss died. It's QM's old bar rebuilt natively (Oct 27: HudKit's BossRed, BossTrail and BossEmpty
-- looks, the weld texture where their dots were; Oct 27 again: their Figma Bossbar, with a
-- red glow and the bull's head over the middle, its eyes X'd once the boss is dead). Under the red sits the trail bar, cut to wherever the red was TRAIL_LAG seconds ago,
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
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local HudImages = require(script.Parent.HudImages)
local HudKit = require(script.Parent.HudKit)
local Hotbar = require(script.Parent.Hotbar)
local Ui = require(script.Parent.Ui)
local RegionBlocker = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("RegionBlocker"))

local Hud = {}

local BAR_W, BAR_H = 634, 60 -- the boss bar inside its 6px outline (QM's Figma: 646 x 72 with it)
local GLOW = { 6, 12, 18, 24 } -- px of the red glow's rings round the bar (Figma: 16 spread, 16 blur, 25%)
local GLOW_ALPHA = 0.93 -- each ring's transparency (they stack, densest at the bar)
local DESIGN_HEIGHT = 1080
local ITALIC = HudKit.ITALIC
local BLACK = HudKit.BLACK
local fig = HudKit.fig
local BAR_EASE = 25 -- how fast the red catches up with the health (quick, not a pop)
local TRAIL_LAG = 0.5 -- seconds the trail bar lags behind the red (QM, Oct 24)
local FILL_IN = 0.4 -- seconds the bar takes to fill from empty when a fight starts (QM, Oct 25)
-- (QM, Oct 27: it pops in when a fight starts and out when it ends; after a kill it stays,
-- empty, for LINGER seconds first)
local POP_IN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local LINGER = 0.9

local player = Players.LocalPlayer

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
		bar.Position = UDim2.new(0.5, 0, 0, 56)
		bar.Size = UDim2.fromOffset(BAR_W, BAR_H)
		bar.Visible = not Ui.live -- (shown in Studio to edit; in Play only in a fight)
	end
	-- (the old bar's images, baked before it was native)
	for _, old in { "BossBarBack", "BossBarFill", "BossBarTrail" } do
		local found = bar:FindFirstChild(old, true)
		if found and found:IsA("ImageLabel") then
			found:Destroy()
		end
	end
	if bar.Size.Y.Offset ~= BAR_H then
		bar.Position, bar.Size = UDim2.new(0.5, 0, 0, 56), UDim2.fromOffset(BAR_W, BAR_H)
	end
	HudKit.back(bar, "BossEmpty", { Name = "BossBarBack" })
	local trailClip
	trailClip, fresh = Ui.make(bar, "TrailClip", "Frame")
	if fresh then
		trailClip.BackgroundTransparency = 1
		trailClip.ClipsDescendants = true
		trailClip.Size = UDim2.fromScale(1, 1)
	end
	trailClip.ZIndex = 2
	local trailImage = HudKit.back(trailClip, "BossTrail", { Name = "BossBarTrail", Size = UDim2.fromOffset(BAR_W, BAR_H), ZIndex = 2 })
	local clip
	clip, fresh = Ui.make(bar, "Clip", "Frame")
	if fresh then
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(1, 1)
	end
	clip.ZIndex = 3
	HudKit.back(clip, "BossRed", { Name = "BossBarFill", Size = UDim2.fromOffset(BAR_W, BAR_H), ZIndex = 3 })
	local old = bar:FindFirstChild("BossName") -- (the BOSS title, before the bull's head)
	if old then
		old:Destroy()
	end
	-- the glow: rings of red stroke round the bar, under it
	local glow
	glow, fresh = Ui.make(bar, "Glow", "Frame")
	if fresh then
		glow.BackgroundTransparency = 1
		glow.Size = UDim2.fromScale(1, 1)
		glow.ZIndex = 0
		for i, width in GLOW do
			local ring = Instance.new("Frame")
			ring.Name = "Ring" .. i
			ring.BackgroundTransparency = 1
			ring.Size = UDim2.fromScale(1, 1)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, fig(8)) -- (the bar's: the stroke rounds out from it)
			corner.Parent = ring
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Color = Color3.fromRGB(255, 0, 0)
			stroke.Transparency = GLOW_ALPHA
			stroke.Thickness = 6 + width
			stroke.Parent = ring
			ring.Parent = glow
		end
	end
	-- the bull's head (QM's Figma AliveIcon and DeadIcon, 146 x 83: assets/ui/hud), over the
	-- bar's middle, 26px above its outline
	local faces = {}
	for _, name in { "BossAliveIcon", "BossDeadIcon" } do
		local face = HudKit.art(bar, name, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -32),
			Size = UDim2.fromOffset(146, 83),
			Visible = name == "BossAliveIcon",
			ZIndex = 6,
		})
		if face.Image == "" then
			face.Image = HudImages[name] or "" -- (baked before it was uploaded)
		end
		faces[name] = face
	end
	local function dead(yes)
		faces.BossAliveIcon.Visible = not yes
		faces.BossDeadIcon.Visible = yes
		glow.Visible = not yes
	end


	-- ---- QM's NewUI ---------------------------------------------------------------------

	local art, label, button = HudKit.art, HudKit.label, HudKit.button

	-- Shop and Index, left middle: 384 x 128, the icon (88) 49 in, the name 174 in. Their
	-- white icons have no outline of their own (QM, Oct 27: add it in game), so each sits on
	-- black copies of itself nudged ICON_OUTLINE px out all round, the same black as the text's
	local ICON_OUTLINE = 3
	for i, name in { "Shop", "Index" } do
		local b = button(root, name .. "Button", 384, 128, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, fig(30), 0.5, (i - 1) * fig(172)),
		}, if name == "Shop" then "Green" else "Blue")
		local holder
		holder, fresh = Ui.make(b, name .. "Icon", "Frame")
		if fresh then
			holder.BackgroundTransparency = 1
			holder.AnchorPoint = Vector2.new(0, 0.5)
			holder.Position = UDim2.new(0, fig(49), 0.5, 0)
			holder.Size = UDim2.fromOffset(fig(88), fig(88))
			holder.ZIndex = 2
		end
		art(holder, name .. "Icon", { Size = UDim2.fromScale(1, 1), ZIndex = 2 })
		for k = 1, 8 do
			local a = (k - 1) * math.pi / 4
			art(holder, "Outline" .. k, {
				Image = HudImages[name .. "Icon"] or "",
				ImageColor3 = BLACK,
				Position = UDim2.fromOffset(
					math.round(math.cos(a) * ICON_OUTLINE),
					math.round(math.sin(a) * ICON_OUTLINE)
				),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
			})
		end
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
		}, if name == "Eggs" then "Red" else "Orange")
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
			}, "Amber")
			label(add, "Plus", {
				Text = "+",
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
			})
		end
	end

	Hotbar.init(root, fig)
	require(script.Parent.WeaponShop).init(root) -- (Carl's: opened by Talking to him)

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
	local pop = Ui.make(bar, "Pop", "UIScale")
	local state = "hidden" -- "shown", "lingering" (its boss died), "out" (popping out), "hidden"
	local leftAt = 0
	local function popIn()
		state = "shown"
		bar.Visible = true
		dead(false)
		pop.Scale = 0
		TweenService:Create(pop, POP_IN, { Scale = 1 }):Play()
	end
	local function popOut()
		state = "out"
		local tween = TweenService:Create(pop, POP_OUT, { Scale = 0 })
		tween.Completed:Connect(function(how)
			if how == Enum.PlaybackState.Completed and state == "out" then
				state = "hidden"
				bar.Visible = false
			end
		end)
		tween:Play()
	end
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
		local now = os.clock()
		local fraction
		if best then
			if state == "hidden" or state == "out" then
				popIn()
			elseif state == "lingering" then
				dead(false) -- (another boss, while the last one's bar was still up)
			end
			state = "shown"
			fraction = math.clamp(best:GetAttribute("Health") / best:GetAttribute("MaxHealth"), 0, 1)
			if best ~= following then
				following = best
				shown = 0
				filling = now
				table.clear(history)
			end
		else
			if state == "shown" then
				-- (killed: it stays, emptying, then pops out; walked off or it slept: out now)
				local dead = following == nil
					or following.Parent == nil
					or (following:GetAttribute("Health") or 0) <= 0
				if dead then
					state = "lingering"
					dead(true)
					leftAt = now
				else
					popOut()
				end
			end
			if state ~= "lingering" then
				return
			end
			fraction = 0
			if now - leftAt >= LINGER then
				following = nil
				popOut()
			end
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
