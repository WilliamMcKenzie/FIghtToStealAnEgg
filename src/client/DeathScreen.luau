-- The death screen (QM, Nov 3: "like in lasso a pet add a continue button and a revive
-- button, revive being 29R to revive to full health from where you died. copy lasso a pet
-- pretty closely in terms of format/pop in animations"). LassoAPet's crash screen, laid out
-- the same (its 1320 x 800 design, scaled up to ours): the title a little above the middle,
-- Revive and Continue stacked low down, Continue under Revive; nothing else on screen (every
-- other ScreenGui is hidden while it's up), the world and you lying on the floor behind it.
--
-- Pop-in, as Lasso's: the title comes in squashed thin and tilted, stretches wide past its
-- size, the buttons pop up (0.85 -> 1, Back), the title squashes tall, then rebounds to rest.
--
-- It opens when your character is knocked down (Server/Death: its Downed attribute), once
-- you've fallen over (Config.Death.Revive.ScreenDelay). Revive (green, Robux price) asks the
-- server for the Revive product's prompt; Continue (red) gives up and sends you home. While
-- the prompt's up both are greyed out. Revive is left out when it can't be bought (no
-- product id yet in a live game: the player's CanRevive attribute), Continue then sits alone.
--
-- Its own ScreenGui (StarterGui > DeathScreen, made with Ui.make like the HUD, so QM can edit
-- it in Studio: tools/studio/uibake.luau bakes it with the HUD).
--
--   DeathScreen.init(scaleFor)  -- client/Hud, in Play and in Edit; scaleFor(h) = Hud.scaleFor

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)
local UiFx = require(script.Parent.UiFx)

local DeathScreen = {}

local REVIVE = Config.Death.Revive
local K = 1080 / 800 -- Lasso's design px to ours
local function px(n) -- Lasso px -> our design px
	return math.round(n * K)
end
local function figma(n) -- Lasso px -> Figma px (HudKit.button's sizes)
	return n * K * 2190 / 1080
end
local TITLE_W, TITLE_H = 400, 78 -- at rest (Lasso px)
local CONTROLS_W, CONTROLS_H = 470, 158
local BUTTON_TOP = 38 -- Revive's middle, down the controls
local BUTTON_LOW = 120 -- Continue's
local REVIVE_W, REVIVE_H = 236, 73
local CONTINUE_W, CONTINUE_H = 258, 72
local TITLE_TOP, TITLE_BOTTOM = Color3.fromHex("ff5a4a"), Color3.fromHex("c40000")
local TITLE_OUTLINE = 0.06 -- of the title's height (QM, Nov 3: 0.13 was too thick)
local ICON_OUTLINE = 3 -- px of black round the Robux icon (as the Shop's)
local PAD = 15 -- Lasso px of room round the buttons (the controls clip: a CanvasGroup, to grey them out)
local WAITING = 0.5 -- the buttons' transparency while the prompt's up (Lasso's)

local player = Players.LocalPlayer

local function gradient(parent, top, bottom)
	local g, fresh = Ui.make(parent, "Shade", "UIGradient")
	if fresh then
		g.Rotation = 90
		g.Color = ColorSequence.new(top, bottom)
	end
	return g
end

local function build()
	local gui = Ui.screen("DeathScreen", {
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local root, fresh = Ui.make(gui, "Root", "Frame")
	if fresh then
		root.BackgroundTransparency = 1
		root.Size = UDim2.fromScale(1, 1)
	end
	local fit = Ui.make(root, "Fit", "UIScale")

	-- the title: "You Died!", red, thick black outline
	local title = HudKit.label(root, "Title", {
		Text = "You Died!",
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.35),
		Size = UDim2.fromOffset(px(TITLE_W), px(TITLE_H)),
		ZIndex = 2,
	})
	gradient(title, TITLE_TOP, TITLE_BOTTOM)

	-- Revive over Continue
	local controls
	controls, fresh = Ui.make(root, "Controls", "CanvasGroup")
	if fresh then
		controls.BackgroundTransparency = 1
		controls.AnchorPoint = Vector2.new(0.5, 0.5)
		controls.Position = UDim2.fromScale(0.5, 0.77)
		controls.Size = UDim2.fromOffset(px(CONTROLS_W), px(CONTROLS_H + PAD * 2))
	end
	Ui.make(controls, "Pop", "UIScale")

	local revive = HudKit.button(controls, "Revive", figma(REVIVE_W), figma(REVIVE_H), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, px(BUTTON_TOP + PAD)),
		ZIndex = 3,
	}, "GreenEdged")
	local row
	row, fresh = Ui.make(revive, "Row", "Frame")
	if fresh then
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.5, 0.5)
		row.Size = UDim2.fromOffset(0, px(48))
		row.AutomaticSize = Enum.AutomaticSize.X
		row.ZIndex = 4
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, px(8))
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
	end
	HudKit.label(row, "Text", {
		Text = "Revive",
		TextSize = px(36),
		Size = UDim2.fromOffset(0, px(48)),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 1,
		ZIndex = 5,
	})
	local holder
	holder, fresh = Ui.make(row, "Robux", "Frame")
	if fresh then
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(px(32), px(35))
		holder.LayoutOrder = 2
		holder.ZIndex = 5
	end
	local icon = HudKit.art(holder, "RobuxIcon", { Size = UDim2.fromScale(1, 1), ZIndex = 6 })
	HudKit.outlineArt(icon, ICON_OUTLINE)
	local price = HudKit.label(row, "Price", {
		Text = tostring(REVIVE.Robux),
		TextSize = px(36),
		Size = UDim2.fromOffset(0, px(48)),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 3,
		ZIndex = 5,
	})

	local continueButton = HudKit.button(controls, "Continue", figma(CONTINUE_W), figma(CONTINUE_H), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, px(BUTTON_LOW + PAD)),
		ZIndex = 3,
	}, "Red")
	HudKit.label(continueButton, "Text", {
		Text = "Continue",
		TextSize = px(36),
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
	})

	if not Ui.live then
		return
	end
	gui.Enabled = false
	return gui, root, fit, title, controls, revive, continueButton, price
end

local function wire(scaleFor, gui, root, fit, title, controls, revive, continueButton, price)
	local remote = ReplicatedStorage:WaitForChild("Death", 30)
	local pop = controls:FindFirstChild("Pop")
	local stroke = title:FindFirstChild("Outline")
	local restSize = title.Size -- (QM's, if it was edited in Studio)
	local restW, restH = restSize.X.Offset, restSize.Y.Offset
	local function sized(w, h) -- Lasso's tween sizes, relative to the title's at rest
		return UDim2.fromOffset(math.round(restW * w / TITLE_W), math.round(restH * h / TITLE_H))
	end

	local function resize()
		local h = gui.AbsoluteSize.Y
		if h < 1 then
			h = workspace.CurrentCamera.ViewportSize.Y
		end
		fit.Scale = scaleFor(h)
		root.Size = UDim2.fromScale(1 / fit.Scale, 1 / fit.Scale)
	end
	resize()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)

	-- the outline follows the title's height as it squashes and stretches
	if stroke then
		title:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			stroke.Thickness = math.max(2, title.AbsoluteSize.Y / math.max(fit.Scale, 0.01) * TITLE_OUTLINE) -- (design px: the UIScale scales it)
		end)
	end

	-- the product's own price, once it has one
	if REVIVE.Product then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, REVIVE.Product, Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				price.Text = tostring(info.PriceInRobux)
			end
		end)
	end

	local tweens, hidden = {}, {}
	local run, holdHidden = 0, nil
	local waiting, canRevive = false, false
	local function tween(object, seconds, style, direction, props)
		local t = TweenService:Create(object, TweenInfo.new(seconds, style, direction), props)
		table.insert(tweens, t)
		t:Play()
		return t
	end

	local function refresh()
		revive.Visible = canRevive
		revive.Active = canRevive and not waiting
		continueButton.Active = not waiting
		controls.GroupTransparency = if waiting then WAITING else 0
		-- (alone, Continue moves up into Revive's place, as Lasso's buttons close up)
		continueButton.Position = UDim2.new(0.5, 0, 0, px((if canRevive then BUTTON_LOW else BUTTON_TOP) + PAD))
	end

	local function hide()
		run += 1
		for _, t in tweens do
			t:Cancel()
		end
		table.clear(tweens)
		if holdHidden then
			holdHidden:Disconnect()
			holdHidden = nil
		end
		if gui.Enabled then
			for g in hidden do
				if g.Parent then
					g.Enabled = true
				end
			end
			table.clear(hidden)
		end
		gui.Enabled = false
	end

	local function show()
		hide()
		canRevive, waiting = player:GetAttribute("CanRevive") == true, false
		refresh()
		-- (nothing else on screen: every other ScreenGui, kept hidden while it's up)
		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		local function hideAll()
			if not playerGui then
				return
			end
			for _, g in playerGui:GetChildren() do
				if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
					hidden[g] = true
					g.Enabled = false
				end
			end
		end
		hideAll()
		holdHidden = RunService.RenderStepped:Connect(hideAll)
		gui.Enabled = true
		UiFx.play("Open")
		local token = run
		title.Size, title.Rotation, title.TextTransparency = sized(220, 100), -6, 1
		if stroke then
			stroke.Transparency = 1
		end
		controls.Visible = false
		pop.Scale = 0.85
		-- Stretch into the entrance, squash at the overshoot, rebound, then settle (Lasso's).
		task.spawn(function()
			if stroke then
				tween(stroke, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Transparency = 0 })
			end
			tween(title, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				Size = sized(452, 62),
				Rotation = 2,
				TextTransparency = 0,
			}).Completed:Wait()
			if token ~= run then
				return
			end
			controls.Visible = true
			tween(pop, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
			tween(title, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				Size = sized(380, 86),
				Rotation = -1,
			}).Completed:Wait()
			if token ~= run then
				return
			end
			tween(title, 0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Size = restSize, Rotation = 0 })
		end)
	end

	revive.Activated:Connect(function()
		if not gui.Enabled or waiting or not canRevive or not remote then
			return
		end
		waiting = REVIVE.Product ~= nil -- (greyed out while the prompt's up)
		refresh()
		remote:FireServer("Revive")
	end)
	continueButton.Activated:Connect(function()
		if not gui.Enabled or waiting or not remote then
			return
		end
		waiting = true
		refresh()
		remote:FireServer("Continue")
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, id, bought)
		if userId == player.UserId and id == REVIVE.Product and not bought then
			waiting = false
			refresh()
		end
	end)

	-- knocked down: up it comes once you've fallen over; up again (revived) or dead for
	-- real, it goes
	local function watch(character)
		hide()
		local shown = 0
		local function changed()
			shown += 1
			local mine = shown
			if character:GetAttribute("Downed") then
				task.delay(REVIVE.ScreenDelay, function()
					if mine == shown and character:GetAttribute("Downed") and player.Character == character then
						show()
					end
				end)
			elseif waiting or gui.Enabled then
				-- (revived: gone at once; Continue: it stays till you're home)
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					hide()
				end
			end
		end
		character:GetAttributeChangedSignal("Downed"):Connect(changed)
		if character:GetAttribute("Downed") then
			changed()
		end
	end
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

function DeathScreen.init(scaleFor)
	local gui, root, fit, title, controls, revive, continueButton, price = build()
	if gui then
		task.spawn(wire, scaleFor, gui, root, fit, title, controls, revive, continueButton, price)
	end
end

return DeathScreen
