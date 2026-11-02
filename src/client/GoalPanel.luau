-- The Goal panel, top left (QM's Figma, Oct 31): a little orange "Goal", the goal's title
-- under it ("Train Power") and a lime bar towards it with "5.9K/10K" across it. What the
-- goal is comes from Shared/Goals (Config.Goals.List: train to level 2, steal 2 eggs,
-- unlock the Desert, buy an Uncommon weapon... on through the game). Finishing a goal
-- (QM, Nov 2) fills the bar, pulses the panel out with "Done!", swaps to the next goal
-- while it's big and settles back, with the Claim sound. Hidden during the tutorial
-- (client/Tutorial hides it too, by name), and gone once every goal's done (the last:
-- Collect Pets).
--
-- Real objects in StarterGui > Hud > Root > Goal for QM to edit (client/Ui): Band, Label,
-- Title, Track (Clip > Fill, Progress). Laid out in design px (1080 tall: the Root's UIScale).
--
--   GoalPanel.init(root)   -- client/Hud, in Play and while baking in Edit

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Goals = require(Shared:WaitForChild("Goals"))

local GoalPanel = {}

local TOP = 150 -- design px from the screen's top (under Roblox's buttons)
local W, H = 420, 160
local BAR_X, BAR_Y, BAR_W, BAR_H = 18, 94, 340, 52
local EASE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_UP = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP_DOWN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP = 1.15
-- finishing a goal (QM, Nov 2): fill, pulse out to PULSE, swap to the next goal, settle back
local DONE_FILL = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PULSE = 1.25
local PULSE_OUT = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PULSE_HOLD = 0.35 -- seconds big with "Done!" before the next goal shows
local PULSE_BACK = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local EVERY = 0.25 -- seconds between checks

function GoalPanel.init(root)
	local label = HudKit.label
	local panel, fresh = Ui.make(root, "Goal", "Frame")
	if fresh then
		panel.BackgroundTransparency = 1
		panel.Position = UDim2.fromOffset(0, TOP)
		panel.Size = UDim2.fromOffset(W, H)
	end

	-- a black band behind it, fading out to the right (like the counters')
	local band
	band, fresh = Ui.make(panel, "Band", "Frame")
	if fresh then
		band.BackgroundColor3 = HudKit.BLACK
		band.BorderSizePixel = 0
		band.Size = UDim2.fromScale(1, 1)
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.7),
			NumberSequenceKeypoint.new(0.54, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = band
	end

	local hadLabel = panel:FindFirstChild("Label") ~= nil
	local small = label(panel, "Label", {
		Text = "Goal",
		TextColor3 = Config.Goals.Color,
		TextSize = 32,
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.fromOffset(200, 34),
		ZIndex = 2,
	})
	if not hadLabel and small:FindFirstChild("Outline") then
		small.Outline.Thickness = 3
	end

	local hadTitle = panel:FindFirstChild("Title") ~= nil
	local title = label(panel, "Title", {
		RichText = true, -- (a weapon goal's rarity is in its colour)
		Text = "Train Power",
		TextSize = 46,
		TextScaled = true,
		Position = UDim2.fromOffset(16, 38),
		Size = UDim2.fromOffset(W - 24, 50),
		ZIndex = 2,
	})
	if not hadTitle then
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 46 -- (a long title shrinks to fit instead)
		cap.Parent = title
	end

	local track = HudKit.back(panel, "GoalTrack", {
		Name = "Track",
		Position = UDim2.fromOffset(BAR_X, BAR_Y),
		Size = UDim2.fromOffset(BAR_W, BAR_H),
		ZIndex = 2,
	})
	local clip
	clip, fresh = Ui.make(track, "Clip", "Frame")
	if fresh then
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Size = UDim2.fromScale(0.59, 1) -- (5.9K/10K, as in QM's Figma)
		clip.ZIndex = 3
	end
	-- (the lime keeps the whole track's size, so it's cut, not squashed)
	HudKit.back(clip, "GoalFill", { Name = "Fill", Size = UDim2.fromOffset(BAR_W, BAR_H), ZIndex = 3 })
	local progress = label(track, "Progress", {
		Text = "5.9K/10K",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 38,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})

	if not Ui.live then
		return panel
	end

	local player = Players.LocalPlayer
	local grow = Ui.make(panel, "Pop", "UIScale")
	local lastIndex, lastTitle, lastFraction = nil, nil, nil
	local busy = false -- (mid completion pulse: refresh leaves the panel alone)

	-- a small pop (a goal's title changed without finishing one)
	local function pop()
		local up = TweenService:Create(grow, POP_UP, { Scale = POP })
		up.Completed:Connect(function(how)
			if how == Enum.PlaybackState.Completed then
				TweenService:Create(grow, POP_DOWN, { Scale = 1 }):Play()
			end
		end)
		up:Play()
	end

	-- show a goal's title, text and bar (fresh: the bar fills up from empty)
	local function show(g, fresh)
		local fraction = if g.need > 0 then math.clamp(g.have / g.need, 0, 1) else 1
		if g.title ~= lastTitle then
			title.Text = g.title
		end
		progress.Text = g.text
		if fraction ~= lastFraction or fresh then
			if fresh then
				clip.Size = UDim2.fromScale(0, 1)
			end
			TweenService:Create(clip, EASE, { Size = UDim2.fromScale(fraction, 1) }):Play()
		end
		lastIndex, lastTitle, lastFraction = g.index, g.title, fraction
	end

	-- a goal's done (QM, Nov 2): the bar fills, the panel pulses out, swaps to the next
	-- goal while it's big, then settles back to its size
	local function complete()
		busy = true
		local fx = require(script.Parent.UiFx)
		fx.play("Claim")
		TweenService:Create(clip, DONE_FILL, { Size = UDim2.fromScale(1, 1) }):Play()
		progress.Text = "Done!"
		local out = TweenService:Create(grow, PULSE_OUT, { Scale = PULSE })
		out:Play()
		out.Completed:Wait()
		task.wait(PULSE_HOLD)
		local g = Goals.current(player)
		if g then
			show(g, true)
		end
		TweenService:Create(grow, PULSE_BACK, { Scale = 1 }):Play()
		task.wait(PULSE_BACK.Time)
		busy = false
	end

	local shown = nil -- (Visible as last set here: the tutorial's hide is left alone otherwise)
	local function refresh()
		if busy then
			return
		end
		local g = Goals.current(player)
		-- (gone during the tutorial, and for good once every goal's done: QM)
		local want = player:GetAttribute("Tutorial") ~= true and g ~= nil
		if want ~= shown then
			shown = want
			panel.Visible = want
		end
		if not g then
			lastIndex = nil
			return
		end
		if lastIndex ~= nil and g.index ~= lastIndex and shown then
			task.spawn(complete)
			return
		end
		local retitled = lastIndex ~= nil and g.title ~= lastTitle and shown
		show(g, lastIndex ~= nil and g.index ~= lastIndex)
		if retitled then
			pop()
			require(script.Parent.UiFx).play("Claim")
		end
	end
	refresh()
	task.spawn(function()
		while panel.Parent do
			task.wait(EVERY)
			refresh()
		end
	end)
	return panel
end

return GoalPanel
