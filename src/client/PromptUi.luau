--!nonstrict
-- LassoAPet's interact prompts (its client/PromptUi, QM Oct 27: the eggs' Hatch 1:1): Roblox's own prompt, 1:1, but with no dark panel
-- behind it. This is Roblox's ProximityPrompt CoreScript (Roblox Studio's
-- ExtraContent/scripts/CoreScripts/CoreScripts/ProximityPrompt.lua, Oct 9), made to run
-- as a game script (no CoreGui / CorePackages; its AppFonts medium is Builder Sans
-- Medium) and drawing Style Custom prompts instead of Default ones. The only change to
-- the look: the panel's BackgroundTransparency stays 1 (it was 0.2), and a soft dark
-- glow sits behind it instead, darkest in the middle (GLOW: assets/ui/PromptGlow.png,
-- made by script; QM, Oct 9). Ride, Carl's Talk, the eggs' Hatch and the egg
-- machine's Roll are Style Custom for this. Stronger (QM, Oct 10): the disc behind the
-- key is darker (KEY_DISC), and the two lines are the game's Montserrat ExtraBold with a
-- thin black outline, the name line in the prompt's "ObjectColor" attribute if it has
-- one (Ride: the pet's rarity colour), the action line in its "ActionColor" (LassoPrompt).
-- Here only the eggs' Hatch (client/PenEggs) is Style Custom.

local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
while LocalPlayer == nil do
	Players.ChildAdded:wait()
	LocalPlayer = Players.LocalPlayer
end

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local KeyboardButtonImage = {
	[Enum.KeyCode.Backspace] = "rbxasset://textures/ui/Controls/backspace.png",
	[Enum.KeyCode.Return] = "rbxasset://textures/ui/Controls/return.png",
	[Enum.KeyCode.LeftShift] = "rbxasset://textures/ui/Controls/shift.png",
	[Enum.KeyCode.RightShift] = "rbxasset://textures/ui/Controls/shift.png",
	[Enum.KeyCode.Tab] = "rbxasset://textures/ui/Controls/tab.png",
}


local KeyboardButtonIconMapping = {
	["'"] = "rbxasset://textures/ui/Controls/apostrophe.png",
	[","] = "rbxasset://textures/ui/Controls/comma.png",
	["`"] = "rbxasset://textures/ui/Controls/graveaccent.png",
	["."] = "rbxasset://textures/ui/Controls/period.png",
	[" "] = "rbxasset://textures/ui/Controls/spacebar.png",
}

local KeyCodeToTextMapping = {
	[Enum.KeyCode.LeftControl] = "Ctrl",
	[Enum.KeyCode.RightControl] = "Ctrl",
	[Enum.KeyCode.LeftAlt] = "Alt",
	[Enum.KeyCode.RightAlt] = "Alt",
	[Enum.KeyCode.F1] = "F1",
	[Enum.KeyCode.F2] = "F2",
	[Enum.KeyCode.F3] = "F3",
	[Enum.KeyCode.F4] = "F4",
	[Enum.KeyCode.F5] = "F5",
	[Enum.KeyCode.F6] = "F6",
	[Enum.KeyCode.F7] = "F7",
	[Enum.KeyCode.F8] = "F8",
	[Enum.KeyCode.F9] = "F9",
	[Enum.KeyCode.F10] = "F10",
	[Enum.KeyCode.F11] = "F11",
	[Enum.KeyCode.F12] = "F12",
}

KeyCodeToTextMapping[Enum.KeyCode.PageUp] = "PgUp"
KeyCodeToTextMapping[Enum.KeyCode.PageDown] = "PgDn"
KeyCodeToTextMapping[Enum.KeyCode.Home] = "Home"
KeyCodeToTextMapping[Enum.KeyCode.End] = "End"
KeyCodeToTextMapping[Enum.KeyCode.Insert] = "Ins"
KeyCodeToTextMapping[Enum.KeyCode.Delete] = "Del"

local KeyCodeToFontSize = {
	[Enum.KeyCode.LeftControl] = 12,
	[Enum.KeyCode.RightControl] = 12,
	[Enum.KeyCode.LeftAlt] = 12,
	[Enum.KeyCode.RightAlt] = 12,
	[Enum.KeyCode.F10] = 12,
	[Enum.KeyCode.F11] = 12,
	[Enum.KeyCode.F12] = 12,
	[Enum.KeyCode.PageUp] = 8,
	[Enum.KeyCode.PageDown] = 8,
	[Enum.KeyCode.Home] = 8,
	[Enum.KeyCode.End] = 10,
	[Enum.KeyCode.Insert] = 10,
	[Enum.KeyCode.Delete] = 10,
}

local GLOW = "rbxassetid://78103765703011" -- assets/ui/PromptGlow.png: black, fading out from the middle
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local OUTLINE = 1.5 -- the text's black outline, px
local KEY_DISC = 0.6 -- the disc behind the key: black, this see-through (about 40% dark: QM, Oct 10; was grey at 0.5)
local GLOW_SEEN = 0.45 -- its ImageTransparency while shown (about half dark at the middle)

-- Colors
local BackgroundColor = Color3.new(0.07, 0.07, 0.07)
local ContentColor = Color3.new(1, 1, 1)
local SecondaryContentColor = Color3.new(0.7, 0.7, 0.7)

-- TweenInfo presets
local tweenInfoQuick = TweenInfo.new(0.06, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
local tweenInfoOutHalfSecond = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tweenInfoFast = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function getScreenGui()
	local screenGui = PlayerGui:FindFirstChild("CustomProximityPrompts")
	if screenGui == nil then
		screenGui = Instance.new("ScreenGui")
		screenGui.Name = "CustomProximityPrompts" -- (not Roblox's own "ProximityPrompts")
		screenGui.ResetOnSpawn = false
		screenGui.Parent = PlayerGui
		screenGui.IgnoreGuiInset = true
	end
	return screenGui
end

local progressGradientFuzz = 0.01
local function createProgressBarGradient(parent, leftSide, tweensForFadeOut, tweensForFadeIn)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.5, 1)
	frame.Position = UDim2.fromScale(leftSide and 0 or 0.5, 0)
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true
	frame.Visible = false
	frame.Parent = parent

	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(2, 1)
	image.Position = UDim2.fromScale(leftSide and 0 or -1, 0)
	image.Image = "rbxasset://textures/ui/Controls/RadialFill.png"
	image.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new {
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.5 + progressGradientFuzz, 1),
		NumberSequenceKeypoint.new(1, 1)
	}
	gradient.Rotation = leftSide and 180 or 0
	gradient.Parent = image

	table.insert(tweensForFadeOut, TweenService:Create(image, tweenInfoQuick, { ImageTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(image, tweenInfoQuick, { ImageTransparency = 0 }))

	return gradient, frame
end

local function createCircularProgressBar(tweensForFadeOut, tweensForFadeIn)
	local bar = Instance.new("Frame")
	bar.Name = "CircularProgressBar"
	bar.Size = UDim2.fromOffset(58, 58)
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.BackgroundTransparency = 1

	local leftGradient, leftFrame = createProgressBarGradient(bar, true, tweensForFadeOut, tweensForFadeIn)
	local rightGradient, rightFrame = createProgressBarGradient(bar, false, tweensForFadeOut, tweensForFadeIn)

	local progress = Instance.new("NumberValue")
	progress.Name = "Progress"
	progress.Parent = bar
	progress.Changed:Connect(function(value)
		local angle = math.clamp(value * 360, 0, 360)
		leftFrame.Visible = progress.Value > 0.5
		leftGradient.Rotation = math.clamp(angle, 180, 360)
		rightFrame.Visible = progress.Value > progressGradientFuzz
		rightGradient.Rotation = math.clamp(angle, 0, 180)
	end)

	return bar
end

-- A thin black outline on a label, fading in and out with its text.
local function outline(label, tweensForFadeOut, tweensForFadeIn, tweensForButtonHoldBegin, tweensForButtonHoldEnd)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = OUTLINE
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Transparency = 1
	stroke.Parent = label
	local info = TweenInfo.new(0.06, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
	table.insert(tweensForButtonHoldBegin, TweenService:Create(stroke, info, { Transparency = 1 }))
	table.insert(tweensForButtonHoldEnd, TweenService:Create(stroke, info, { Transparency = 0 }))
	table.insert(tweensForFadeOut, TweenService:Create(stroke, info, { Transparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(stroke, info, { Transparency = 0 }))
end

local function createPrompt(prompt, inputType, gui)
	local tweensForButtonHoldBegin = {}
	local tweensForButtonHoldEnd = {}
	local tweensForFadeOut = {}
	local tweensForFadeIn = {}
	local tweenInfoInFullDuration = TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	local promptUI = Instance.new("BillboardGui")
	promptUI.Name = "Prompt"
	promptUI.AlwaysOnTop = true

	-- The dark glow behind it all (ours), a little bigger than the prompt.
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.Image = GLOW
	glow.ImageTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.5, 1.5)
	glow.ZIndex = 0
	glow.Parent = promptUI

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(0.5, 1)
	frame.BackgroundTransparency = 1
	frame.BackgroundColor3 = BackgroundColor
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0)
	frame.Size = UDim2.fromScale(0, 1)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Parent = promptUI

	-- Add right padding
	local padding = Instance.new("UIPadding")
	padding.Parent = frame

	local roundedCorner = Instance.new("UICorner")
	roundedCorner.Parent = frame

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.fromScale(1, 1)
	inputFrame.BackgroundTransparency = 1
	inputFrame.SizeConstraint = Enum.SizeConstraint.RelativeYY
	inputFrame.Parent = frame

	local resizeableInputFrame = Instance.new("Frame")
	resizeableInputFrame.Size = UDim2.fromScale(1, 1)
	resizeableInputFrame.Position = UDim2.fromScale(0.5, 0.5)
	resizeableInputFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	resizeableInputFrame.BackgroundTransparency = 1
	resizeableInputFrame.Parent = inputFrame

	local inputFrameScaler = Instance.new("UIScale")
	inputFrameScaler.Parent = resizeableInputFrame

	local inputFrameScaleFactor = inputType == Enum.ProximityPromptInputType.Touch and 1.6 or 1.33
	table.insert(tweensForButtonHoldBegin, TweenService:Create(inputFrameScaler, tweenInfoFast, { Scale = inputFrameScaleFactor }))
	table.insert(tweensForButtonHoldEnd, TweenService:Create(inputFrameScaler, tweenInfoFast, { Scale = 1 }))

	local actionText = Instance.new("TextLabel")
	actionText.Name = "ActionText"
	actionText.FontFace = FONT
	actionText.TextSize = 22
	actionText.BackgroundTransparency = 1
	actionText.TextTransparency = 1
	actionText.TextColor3 = ContentColor
	actionText.TextXAlignment = Enum.TextXAlignment.Left
	table.insert(tweensForButtonHoldBegin, TweenService:Create(actionText, tweenInfoFast, { TextTransparency = 1 }))
	table.insert(tweensForButtonHoldEnd, TweenService:Create(actionText, tweenInfoFast, { TextTransparency = 0 }))
	table.insert(tweensForFadeOut, TweenService:Create(actionText, tweenInfoFast, { TextTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(actionText, tweenInfoFast, { TextTransparency = 0 }))

	local objectText = Instance.new("TextLabel")
	objectText.Name = "ObjectText"
	objectText.FontFace = FONT
	objectText.TextSize = 16
	objectText.BackgroundTransparency = 1
	objectText.TextTransparency = 1
	objectText.TextColor3 = SecondaryContentColor
	objectText.TextXAlignment = Enum.TextXAlignment.Left

	-- Add list layout, as well a tween out to mimic old shrinking
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.Padding = UDim.new(-0.25, 0)
	listLayout.Parent = frame
	table.insert(tweensForButtonHoldBegin, TweenService:Create(listLayout, tweenInfoFast, { Padding = UDim.new(-0.25, 0) }))
	table.insert(tweensForButtonHoldEnd, TweenService:Create(listLayout, tweenInfoFast, { Padding = UDim.new(0, 0) }))
	table.insert(tweensForFadeOut, TweenService:Create(listLayout, tweenInfoFast, { Padding = UDim.new(-0.25, 0) }))
	table.insert(tweensForFadeIn, TweenService:Create(listLayout, tweenInfoFast, { Padding = UDim.new(0, 0) }))

	-- Add container for text labels
	local textFrame = Instance.new("Frame")
	textFrame.Name = "TextFrame"
	textFrame.Size = UDim2.fromScale(0, 1)
	textFrame.AutomaticSize = Enum.AutomaticSize.X
	textFrame.BackgroundTransparency = 1
	textFrame.Parent = frame

	-- ActionText and ObjectText automatic sizing, parent to textFrame
	actionText.Size = UDim2.fromScale(0, 1)
	actionText.AutomaticSize = Enum.AutomaticSize.X
	actionText.Parent = textFrame

	objectText.Size = UDim2.fromScale(0, 1)
	objectText.AutomaticSize = Enum.AutomaticSize.X
	objectText.Parent = textFrame

	table.insert(tweensForButtonHoldBegin, TweenService:Create(objectText, tweenInfoFast, { TextTransparency = 1 }))
	table.insert(tweensForButtonHoldEnd, TweenService:Create(objectText, tweenInfoFast, { TextTransparency = 0 }))
	table.insert(tweensForFadeOut, TweenService:Create(objectText, tweenInfoFast, { TextTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(objectText, tweenInfoFast, { TextTransparency = 0 }))
	outline(actionText, tweensForFadeOut, tweensForFadeIn, tweensForButtonHoldBegin, tweensForButtonHoldEnd)
	outline(objectText, tweensForFadeOut, tweensForFadeIn, tweensForButtonHoldBegin, tweensForButtonHoldEnd)

	table.insert(tweensForButtonHoldBegin, TweenService:Create(frame, tweenInfoFast, { BackgroundTransparency = 1 }))
	table.insert(tweensForButtonHoldEnd, TweenService:Create(frame, tweenInfoFast, { BackgroundTransparency = 1 })) -- (no panel: was 0.2)
	table.insert(tweensForFadeOut, TweenService:Create(frame, tweenInfoFast, { BackgroundTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(frame, tweenInfoFast, { BackgroundTransparency = 1 })) -- (no panel: was 0.2)
	table.insert(tweensForFadeIn, TweenService:Create(glow, tweenInfoFast, { ImageTransparency = GLOW_SEEN }))
	table.insert(tweensForFadeOut, TweenService:Create(glow, tweenInfoFast, { ImageTransparency = 1 }))

	local roundFrame = Instance.new("Frame")
	roundFrame.Name = "RoundFrame"
	roundFrame.Size = UDim2.fromOffset(48, 48)

	roundFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	roundFrame.Position = UDim2.fromScale(0.5, 0.5)
	roundFrame.BackgroundTransparency = 1
	roundFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	roundFrame.Parent = resizeableInputFrame

	local roundedFrameCorner = Instance.new("UICorner")
	roundedFrameCorner.CornerRadius = UDim.new(0.5, 0)
	roundedFrameCorner.Parent = roundFrame

	table.insert(tweensForFadeOut, TweenService:Create(roundFrame, tweenInfoQuick, { BackgroundTransparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(roundFrame, tweenInfoQuick, { BackgroundTransparency = KEY_DISC }))

	if inputType == Enum.ProximityPromptInputType.Gamepad then

		local mappedIconImage = UserInputService:GetImageForKeyCode(prompt.GamepadKeyCode)

		if mappedIconImage then
			local icon = Instance.new("ImageLabel")
			icon.Name = "ButtonImage"
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Size = UDim2.fromOffset(24, 24)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			icon.BackgroundTransparency = 1
			icon.ImageTransparency = 1
			icon.Image = mappedIconImage
			icon.Parent = resizeableInputFrame
			table.insert(tweensForFadeOut, TweenService:Create(icon, tweenInfoQuick, { ImageTransparency = 1 }))
			table.insert(tweensForFadeIn, TweenService:Create(icon, tweenInfoQuick, { ImageTransparency = 0 }))
		end
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		local buttonImage = Instance.new("ImageLabel")
		buttonImage.Name = "ButtonImage"
		buttonImage.BackgroundTransparency = 1
		buttonImage.ImageTransparency = 1
		buttonImage.Size = UDim2.fromOffset(25, 31)
		buttonImage.AnchorPoint = Vector2.new(0.5, 0.5)
		buttonImage.Position = UDim2.fromScale(0.5, 0.5)
		buttonImage.Image = "rbxasset://textures/ui/Controls/TouchTapIcon.png"
		buttonImage.Parent = resizeableInputFrame

		table.insert(tweensForFadeOut, TweenService:Create(buttonImage, tweenInfoQuick, { ImageTransparency = 1 }))
		table.insert(tweensForFadeIn, TweenService:Create(buttonImage, tweenInfoQuick, { ImageTransparency = 0 }))
	else
		local buttonImage = Instance.new("ImageLabel")
		buttonImage.Name = "ButtonImage"
		buttonImage.BackgroundTransparency = 1
		buttonImage.ImageTransparency = 1
		buttonImage.Size = UDim2.fromOffset(28, 30)
		buttonImage.AnchorPoint = Vector2.new(0.5, 0.5)
		buttonImage.Position = UDim2.fromScale(0.5, 0.5)
		buttonImage.Image = "rbxasset://textures/ui/Controls/key_single.png"
		buttonImage.Parent = resizeableInputFrame
		table.insert(tweensForFadeOut, TweenService:Create(buttonImage, tweenInfoQuick, { ImageTransparency = 1 }))
		table.insert(tweensForFadeIn, TweenService:Create(buttonImage, tweenInfoQuick, { ImageTransparency = 0 }))

		local buttonTextString = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)

		local buttonTextImage = KeyboardButtonImage[prompt.KeyboardKeyCode]
		if buttonTextImage == nil then
			buttonTextImage = KeyboardButtonIconMapping[buttonTextString]
		end

		if buttonTextImage == nil then
			local keyCodeMappedText = KeyCodeToTextMapping[prompt.KeyboardKeyCode]
			if keyCodeMappedText then
				buttonTextString = keyCodeMappedText
			end
		end

		if buttonTextImage then
			local icon = Instance.new("ImageLabel")
			icon.Name = "ButtonImage"
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Size = UDim2.fromOffset(36, 36)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			icon.BackgroundTransparency = 1
			icon.ImageTransparency = 1
			icon.Image = buttonTextImage
			icon.Parent = resizeableInputFrame
			table.insert(tweensForFadeOut, TweenService:Create(icon, tweenInfoQuick, { ImageTransparency = 1 }))
			table.insert(tweensForFadeIn, TweenService:Create(icon, tweenInfoQuick, { ImageTransparency = 0 }))
		elseif buttonTextString ~= nil and buttonTextString ~= '' then
			local buttonText = Instance.new("TextLabel")
			buttonText.Name = "ButtonText"
			buttonText.AutoLocalize = false
			buttonText.Position = UDim2.fromOffset(0, -1)
			buttonText.Size = UDim2.fromScale(1, 1)
			buttonText.Font = Enum.Font.BuilderSansMedium

			local buttonTextSize = KeyCodeToFontSize[prompt.KeyboardKeyCode]
			if buttonTextSize == nil then
				buttonTextSize = 14
			end
			buttonText.TextSize = buttonTextSize

			buttonText.BackgroundTransparency = 1
			buttonText.TextTransparency = 1
			buttonText.TextColor3 = ContentColor
			buttonText.TextXAlignment = Enum.TextXAlignment.Center
			buttonText.Text = buttonTextString
			buttonText.Parent = resizeableInputFrame
			table.insert(tweensForFadeOut, TweenService:Create(buttonText, tweenInfoQuick, { TextTransparency = 1 }))
			table.insert(tweensForFadeIn, TweenService:Create(buttonText, tweenInfoQuick, { TextTransparency = 0 }))
		else
			error("ProximityPrompt '" .. prompt.Name .. "' has an unsupported keycode for rendering UI: " .. tostring(prompt.KeyboardKeyCode))
		end
	end

	if inputType == Enum.ProximityPromptInputType.Touch or prompt.ClickablePrompt then
		local button = Instance.new("TextButton")
		button.BackgroundTransparency = 1
		button.TextTransparency = 1
		button.Size = UDim2.fromScale(1, 1)
		button.Parent = promptUI
		button.Selectable = false

		local buttonDown = false

		button.InputBegan:Connect(function(input)
			if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and
				input.UserInputState ~= Enum.UserInputState.Change then
				prompt:InputHoldBegin()
				buttonDown = true
			end
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				if buttonDown then
					buttonDown = false
					prompt:InputHoldEnd()
				end
			end
		end)

		promptUI.Active = true
	end

	if prompt.HoldDuration > 0 then
		local circleBar = createCircularProgressBar(tweensForFadeOut, tweensForFadeIn)
		circleBar.Parent = resizeableInputFrame
		table.insert(tweensForButtonHoldBegin, TweenService:Create(circleBar.Progress, tweenInfoInFullDuration, { Value = 1 }))
		table.insert(tweensForButtonHoldEnd, TweenService:Create(circleBar.Progress, tweenInfoOutHalfSecond, { Value = 0 }))
	end

	local holdBeganConnection
	local holdEndedConnection
	local triggeredConnection
	local triggerEndedConnection

	if prompt.HoldDuration > 0 then
		holdBeganConnection = prompt.PromptButtonHoldBegan:Connect(function()
			for _, tween in ipairs(tweensForButtonHoldBegin) do
				tween:Play()
			end
		end)

		holdEndedConnection = prompt.PromptButtonHoldEnded:Connect(function()
			for _, tween in ipairs(tweensForButtonHoldEnd) do
				tween:Play()
			end
		end)
	end

	triggeredConnection = prompt.Triggered:Connect(function()
		for _, tween in ipairs(tweensForFadeOut) do
			tween:Play()
		end
	end)

	triggerEndedConnection = prompt.TriggerEnded:Connect(function()
		for _, tween in ipairs(tweensForFadeIn) do
			tween:Play()
		end
	end)

	local function updateUIFromPrompt()
		local promptHeight = 72
		local promptWidth = 72
		local textPaddingRight = 24

		local actionTextYOffset = 0
		if prompt.ObjectText ~= nil and prompt.ObjectText ~= '' then
			actionTextYOffset = 9
		end

		actionText.Text = prompt.ActionText
		objectText.Text = prompt.ObjectText
		objectText.TextColor3 = prompt:GetAttribute("ObjectColor") or Color3.new(1, 1, 1)
		actionText.TextColor3 = prompt:GetAttribute("ActionColor") or ContentColor
		actionText.AutoLocalize = prompt.AutoLocalize
		actionText.RootLocalizationTable = prompt.RootLocalizationTable
		objectText.AutoLocalize = prompt.AutoLocalize
		objectText.RootLocalizationTable = prompt.RootLocalizationTable

		textPaddingRight = textPaddingRight - actionTextYOffset

		if
			(prompt.ActionText ~= nil and prompt.ActionText ~= '')
			or (prompt.ObjectText ~= nil and prompt.ObjectText ~= '')
		then
			padding.PaddingRight = UDim.new(0, textPaddingRight)
		else
			padding.PaddingRight = UDim.new(0, 0)
		end

		actionText.Position = UDim2.new(0, 0, 0, actionTextYOffset)
		objectText.Position = UDim2.new(0, 0, 0, -10)

		promptUI.Size = UDim2.fromOffset(promptWidth, promptHeight)
		promptUI.SizeOffset = Vector2.new(prompt.UIOffset.X / promptUI.Size.Width.Offset, prompt.UIOffset.Y / promptUI.Size.Height.Offset)

		-- BillboardGuis can't be automatically sized, so we need to calculate
		-- the size based on the automatically sized prompt frame.
		task.defer(function ()
			-- Automatic sizing takes approximately 2 render cycles to be calculated
			RunService.RenderStepped:Wait()
			RunService.RenderStepped:Wait()

			promptWidth = frame.AbsoluteSize.X
			promptUI.Size = UDim2.fromOffset(promptWidth, promptHeight)
			promptUI.SizeOffset = Vector2.new(prompt.UIOffset.X / promptUI.Size.Width.Offset, prompt.UIOffset.Y / promptUI.Size.Height.Offset)
		end)
	end

	local changedConnection = prompt.Changed:Connect(updateUIFromPrompt)
	updateUIFromPrompt()

	promptUI.Adornee = prompt.Parent
	promptUI.Parent = gui

	local function updateUIAncestry()
		promptUI.Adornee = prompt.Parent
	end
	local ancestryConnection = prompt.AncestryChanged:Connect(updateUIAncestry)

	for _, tween in ipairs(tweensForFadeIn) do
		tween:Play()
	end

	local function cleanup()
		if holdBeganConnection then
			holdBeganConnection:Disconnect()
		end

		if holdEndedConnection then
			holdEndedConnection:Disconnect()
		end

		triggeredConnection:Disconnect()
		triggerEndedConnection:Disconnect()
		changedConnection:Disconnect()
		ancestryConnection:Disconnect()

		for _, tween in ipairs(tweensForFadeOut) do
			tween:Play()
		end

		wait(0.2)

		promptUI.Parent = nil
	end

	return cleanup
end

local function createIndicator(prompt, gui)
	local tweensForFadeOut = {}
	local tweensForFadeIn = {}

	local indicatorUI = Instance.new("BillboardGui")
	indicatorUI.Name = "Indicator"
	indicatorUI.Size = UDim2.fromOffset(15, 15)
	indicatorUI.AlwaysOnTop = true

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BackgroundColor3 = BackgroundColor
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0)
	frame.Parent = indicatorUI

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame

    local stroke = Instance.new("UIStroke")
	stroke.Color = ContentColor
	stroke.Thickness = 1.5
	stroke.Transparency = 1
	stroke.Parent = frame

	table.insert(tweensForFadeOut, TweenService:Create(frame, tweenInfoQuick, { BackgroundTransparency = 1 }))
	table.insert(tweensForFadeOut, TweenService:Create(stroke, tweenInfoQuick, { Transparency = 1 }))
	table.insert(tweensForFadeIn, TweenService:Create(frame, tweenInfoQuick, { BackgroundTransparency = 0.2 }))
	table.insert(tweensForFadeIn, TweenService:Create(stroke, tweenInfoQuick, { Transparency = 0.2 }))

	indicatorUI.Adornee = prompt.Parent
	indicatorUI.Parent = gui

	local function updateUIAncestry()
		indicatorUI.Adornee = prompt.Parent
	end
	local ancestryConnection = prompt.AncestryChanged:Connect(updateUIAncestry)

	for _, tween in ipairs(tweensForFadeIn) do
		tween:Play()
	end

	local function cleanup()
		ancestryConnection:Disconnect()

		for _, tween in ipairs(tweensForFadeOut) do
			tween:Play()
		end

		wait(0.2)

		indicatorUI.Parent = nil
	end

	return cleanup
end

local function onLoad()
	-- Roblox's own prompts instead, to compare (QM, Oct 10: Config.NativePrompts): every
	-- Custom one is switched to Default as it comes into the world, and this draws none.
	if require(game:GetService("ReplicatedStorage").Shared.Config).NativePrompts then
		local function native(item)
			if item:IsA("ProximityPrompt") and item.Style == Enum.ProximityPromptStyle.Custom then
				item.Style = Enum.ProximityPromptStyle.Default
			end
		end
		for _, item in workspace:GetDescendants() do
			native(item)
		end
		workspace.DescendantAdded:Connect(native)
		return
	end
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return -- (Roblox draws the Default ones)
		end

		local gui = getScreenGui()

		local cleanupFunction = createPrompt(prompt, inputType, gui)

		-- Wait for either the prompt being hidden or destroyed
		local yield = Instance.new("BindableEvent")
		local con = prompt.PromptHidden:Connect(function()
			yield:Fire()
		end)
		local con2 = prompt.Destroying:Connect(function()
			yield:Fire()
		end)
		yield.Event:Wait()
		con:Disconnect()
		con2:Disconnect()

		cleanupFunction()
    end)

	ProximityPromptService.IndicatorShown:Connect(function(prompt)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return -- (Roblox draws the Default ones)
		end

		local gui = getScreenGui()

		local cleanupFunction = createIndicator(prompt, gui)

		-- Wait for either the indicator being hidden or the prompt is destroyed
		local yield = Instance.new("BindableEvent")
		local con = prompt.IndicatorHidden:Connect(function()
			yield:Fire()
		end)
		local con2 = prompt.Destroying:Connect(function()
			yield:Fire()
		end)
		yield.Event:Wait()
		con:Disconnect()
		con2:Disconnect()

		cleanupFunction()
	end)
end

onLoad()


return {}
