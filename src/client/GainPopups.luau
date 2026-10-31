-- The "+120" popups beside the Power and Cash counters (QM, Oct 30; their Figma page "Gained
-- Cash/Power popup"): each gain pops up just right of the counter's number, then straight away
-- floats up and fades, so the next one has room. Gains that land together (one swing hitting
-- 4 mobs, a pen's cash/s tick) are summed into one popup: the first gain opens a BATCH-second
-- window and everything that lands in it shows as one number. Losses (buying, rebirth) don't pop.
--
-- In Studio: StarterGui > Hud > Root > Power (and Cash) > GainTemplate is what every popup is
-- copied from (a CanvasGroup, so it fades as one): Amount, the italic number, and the icon
-- after it. The icon has no outline in Figma (QM: it should match the number's 1:1), so it gets
-- one here the same colour and thickness as the number's (HudKit.outlineArt).
-- Popups count from the server's Loaded attribute (Server/Data), so the saved Cash and
-- Power arriving on join don't pop up, nor does the offline pay (it has its own).
--
--   GainPopups.init(row, name, counter, color, band)  -- row: the counter's Frame; counter: its
--                                                     -- Value; band: its band's Figma y
--   GainPopups.expect(name, amount)  -- the next `amount` gained has its own popup (a boss's
--                                    -- bounty: client/BossBounty), so it doesn't pop here
--   GainPopups.parts(name) -> { row, template, counter } (once init'd)

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local HudKit = require(script.Parent.HudKit)
local Ui = require(script.Parent.Ui)
local Abbrev = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Abbrev"))

local GainPopups = {}

local fig = HudKit.fig
local BATCH = 0.1 -- seconds gains are summed over before their popup shows
local LIFE = 0.7 -- seconds a popup takes to float up and fade
local RISE = 120 -- how far it floats, in Figma px
local POP = TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FLOAT = TweenInfo.new(LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(LIFE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local PAD = 8 -- Figma px of room round it in the CanvasGroup, for the outlines
-- the counter's number in QM's Figma when the popup sits where the template does
local REFERENCE = "14K"

local player = Players.LocalPlayer
local expected = {} -- [name] = gain still to come that pops elsewhere
local parts = {} -- [name] = { row, template, counter }

function GainPopups.expect(name, amount)
	expected[name] = (expected[name] or 0) + amount
end

function GainPopups.parts(name)
	return parts[name]
end

-- the popup in its Figma px (the 25px number, then the 34px icon starting 8px before the
-- number's end), scaled up so the number is the counter's size, 60 (QM, Oct 30)
local function k(n)
	return fig(n * 60 / 25)
end
-- bumped when the template's look changes, so an older baked copy is rebuilt
local VERSION = 2

local function build(name, band, color)
	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0, 0.5)
	group.Position = UDim2.fromOffset(fig(336) - fig(PAD), fig(band + 36))
	group.Size = UDim2.fromOffset(0, k(34) + 2 * fig(PAD))
	group.AutomaticSize = Enum.AutomaticSize.X
	group.ZIndex = 6
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
		pad[side] = UDim.new(0, fig(PAD))
	end
	pad.Parent = group
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, -k(8))
	layout.Parent = group
	HudKit.label(group, "Amount", {
		Text = "+120",
		FontFace = HudKit.ITALIC,
		TextSize = k(25),
		TextColor3 = color,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, k(30)),
		LayoutOrder = 1,
		ZIndex = 8, -- (over the icon, QM)
	})
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(k(34), k(34))
	holder.LayoutOrder = 2
	holder.ZIndex = 7
	holder.Parent = group
	local icon = HudKit.art(holder, name .. "GainIcon", {
		Size = UDim2.fromScale(1, 1),
		ZIndex = 8,
	})
	HudKit.outlineArt(icon, HudKit.TEXT_OUTLINE)
	group:SetAttribute("Version", VERSION)
	return group
end

-- the counter's number's width at its own font and size (in its unscaled design px)
local function width(counter, text)
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = counter.FontFace
	params.Size = counter.TextSize
	params.Width = math.huge
	local ok, size = pcall(TextService.GetTextBoundsAsync, TextService, params)
	return if ok then size.X else 0
end

function GainPopups.init(row, name, counter, color, band)
	local old = row:FindFirstChild("GainTemplate")
	if old and old:GetAttribute("Version") ~= VERSION then
		old:Destroy()
	end
	local template = Ui.template(row, "GainTemplate", function()
		return build(name, band, color)
	end)
	if not Ui.live then
		return
	end
	parts[name] = { row = row, template = template, counter = counter }

	local function show(amount)
		local popup = Ui.copy(template, "Gain", row)
		popup.Amount.Text = "+" .. Abbrev(amount)
		-- (right of the number, however long it's got: the template's spot is for "14K")
		local extra = math.max(0, width(counter, counter.Text) - width(counter, REFERENCE))
		local at = template.Position + UDim2.fromOffset(extra, 0)
		popup.Position = at
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = popup
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
		TweenService:Create(popup, FLOAT, { Position = at - UDim2.fromOffset(0, fig(RISE)) }):Play()
		local fade = TweenService:Create(popup, FADE, { GroupTransparency = 1 })
		fade.Completed:Once(function()
			popup:Destroy()
		end)
		fade:Play()
	end

	local last = nil -- the value popups count from (nil until Server/Data has Loaded)
	local pending = 0
	local waiting = false
	local function changed()
		local value = player:GetAttribute(name) or 0
		if not player:GetAttribute("Loaded") then
			return
		end
		if last == nil then
			last = value
			return
		end
		local gain = value - last
		last = value
		if gain <= 0 then
			return
		end
		local skip = math.min(gain, expected[name] or 0)
		expected[name] = (expected[name] or 0) - skip
		gain -= skip
		if gain <= 0 then
			return
		end
		pending += gain
		if not waiting then
			waiting = true
			task.delay(BATCH, function()
				waiting = false
				-- (Strength comes in fractions: under 1 it waits for more rather than show +0)
				if pending >= 1 then
					local sum = pending
					pending = 0
					show(sum)
				end
			end)
		end
	end
	player:GetAttributeChangedSignal(name):Connect(changed)
	player:GetAttributeChangedSignal("Loaded"):Connect(changed)
	changed()
end

return GainPopups
