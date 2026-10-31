-- The banner that sweeps across the top of the screen (QM, Oct 31: LassoAPet's tutorial
-- banner, with our own words): a band wider than the screen fades in and out while the
-- words fly straight across it from off the left to off the right, fast at both edges and
-- slowest in the middle (never stopping). Its ends never show. The band is QM's art
-- (HudImages PromptBanner1-3 for the tutorial, BossBanner1-3 for "Boss Defeated!"; a plain
-- red band till they're uploaded); the words are Montserrat ExtraBold, white, outlined black.
-- A new banner cuts off the one on screen.
--
--   Banner.show(text, look?)   -- look: "Prompt" (default) or "Boss"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local HudImages = require(script.Parent.HudImages)

local Banner = {}

local SIZE = Vector2.new(2587, 113) -- QM's art, in pixels
local STRIPS = { 862, 863, 862 } -- its thirds' widths
local WIDTH = 1.3 -- x the screen's width (so its ends are always off it)
local AT = 0.17 -- its middle, down the screen
local TRAVEL = 0.6 -- the words go from this far left of the middle to this far right, x the screen's width
local SPEED = { 2.592, 0.136 } -- A, B: the words' speed A (2u - 1)^2 + B of their average (A / 3 + B = 1)
local FADE = 0.16 -- of the sweep fading in, and again out
local TIME = 3 -- seconds, the whole sweep
local TEXT_TALL = 0.55 -- the words' height, of the band's
local STROKE = 0.06 -- their outline, of the band's height
local FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local FALLBACK = { Prompt = Color3.fromRGB(250, 62, 64), Boss = Color3.fromRGB(255, 0, 0) }

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Banner"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 45
gui.Parent = player:WaitForChild("PlayerGui")

-- one band per look, its pictures fading together (a CanvasGroup this wide didn't draw in
-- LassoAPet)
local bands = {}
local function band(look)
	if bands[look] then
		return bands[look]
	end
	local frame = Instance.new("Frame")
	frame.Name = look
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, AT)
	frame.Size = UDim2.fromScale(WIDTH, 1)
	frame.Visible = false
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = SIZE.X / SIZE.Y
	ratio.Parent = frame
	local fades = {} -- { { object, property, its shown value } }
	if (HudImages[look .. "Banner1"] or "") ~= "" then
		local from = 0
		for i, w in STRIPS do
			local piece = Instance.new("ImageLabel")
			piece.BackgroundTransparency = 1
			piece.Image = HudImages[look .. "Banner" .. i]
			piece.Position = UDim2.fromScale(from / SIZE.X, 0)
			piece.Size = UDim2.fromScale(w / SIZE.X, 1)
			piece.Parent = frame
			table.insert(fades, { piece, "ImageTransparency", 0 })
			from += w
		end
	else
		local plain = Instance.new("Frame")
		plain.BackgroundColor3 = FALLBACK[look] or FALLBACK.Prompt
		plain.Size = UDim2.fromScale(1, 1)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.15, 0)
		corner.Parent = plain
		local edge = Instance.new("UIStroke")
		edge.Thickness = 3
		edge.Parent = plain
		plain.Parent = frame
		table.insert(fades, { plain, "BackgroundTransparency", 0 })
		table.insert(fades, { edge, "Transparency", 0 })
	end
	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.Position = UDim2.fromScale(0.5, 0.5)
	words.Size = UDim2.fromScale(0.6, TEXT_TALL)
	words.FontFace = FONT
	words.TextColor3 = Color3.new(1, 1, 1)
	words.TextScaled = true
	words.ZIndex = 2
	local outline = Instance.new("UIStroke")
	outline.LineJoinMode = Enum.LineJoinMode.Round
	outline.Parent = words
	words.Parent = frame
	table.insert(fades, { words, "TextTransparency", 0 })
	table.insert(fades, { outline, "Transparency", 0 })
	frame.Parent = gui
	bands[look] = { frame = frame, words = words, outline = outline, fades = fades }
	return bands[look]
end

task.spawn(function() -- (the art loaded before it's needed)
	local labels = {}
	for _, look in { "Prompt", "Boss" } do
		for i = 1, 3 do
			local id = HudImages[look .. "Banner" .. i] or ""
			if id ~= "" then
				local label = Instance.new("ImageLabel")
				label.Image = id
				table.insert(labels, label)
			end
		end
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, labels)
end)

local sweep -- the RenderStepped connection of the one on screen
local shown -- its band

function Banner.show(text, look)
	look = look or "Prompt"
	if sweep then
		sweep:Disconnect()
		shown.frame.Visible = false
	end
	local b = band(look)
	shown = b
	b.words.Text = text
	b.frame.Visible = true
	local A, B = SPEED[1], SPEED[2]
	local started = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local u = math.min((os.clock() - started) / TIME, 1)
		local along = A * ((2 * u - 1) ^ 3 + 1) / 6 + B * u -- 0 to 1 (the speed's integral)
		b.words.Position = UDim2.fromScale(0.5 + (2 * along - 1) * TRAVEL / WIDTH, 0.5)
		b.outline.Thickness = math.max(2, b.frame.AbsoluteSize.Y * STROKE)
		local on = math.clamp(math.min(u / FADE, (1 - u) / FADE), 0, 1)
		for _, f in b.fades do
			f[1][f[2]] = 1 - on * (1 - f[3])
		end
		if u >= 1 then
			conn:Disconnect()
			b.frame.Visible = false
			if sweep == conn then
				sweep = nil
			end
		end
	end)
	sweep = conn
end

return Banner
