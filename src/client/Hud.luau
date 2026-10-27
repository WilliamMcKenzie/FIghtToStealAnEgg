-- The HUD: for now only the boss bar (QM, Oct 27: the rest of the UI was deleted for a redo;
-- the old HUD, popups, Backpack and egg hotbar are in git history before this). The bar sits
-- top centre with the boss's name over it, laid out in pixels at QM's 1080-tall design size
-- and scaled to the screen by a UIScale (screen height / 1080). Text is Montserrat ExtraBold,
-- white with a dark outline.
--
-- The bar follows the nearest awake boss in workspace.Bosses and hides when there's none.
-- Under the red sits QM's trail bar, cut to wherever the red was TRAIL_LAG seconds ago,
-- so a hit drops the red and exposes the trail, which follows it down half a second on.
-- Images were uploaded from assets/ui (ids in assets/ui/ids.json).
--
-- It's real objects in StarterGui > Hud > Root > BossBar for QM to edit in Studio (client/Ui).
-- tools/studio/uibake.luau puts them there; in Play this only fills in what's missing and wires
-- them up.
--
--   Hud.start()  -- in Play (on require); tools/studio/uibake.luau calls it in Edit mode

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Ui = require(script.Parent.Ui)

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

	if not Ui.live then
		return gui
	end

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
