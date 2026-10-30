-- A rarity's name drawn in its colours (Config.Rarities), the same everywhere: the Weapon
-- Shop's cards, nest eggs' labels, pets (QM, Oct 30: pets' rarities look like the tools').
-- Common is white fading to grey down the text; the rest are their text colour; from
-- Mythic up the text is white under a gradient with a band of text2 sweeping across it.
--
--   RarityLook.paint(label, rarity, stroke?)  -- colours a TextLabel (stroke: its UIStroke,
--                                             -- else the label's first one) and, for a
--                                             -- moving rarity, keeps its band sweeping
--   RarityLook.colour(rarity)                 -- its text colour (for a plain Color3)
--   RarityLook.sweep()                        -- the band's Offset.X right now (-1 to 1)

local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local SWEEP = 2.5 -- seconds a band takes across a moving rarity's text
local DARKEN = 0.6 -- a rarity's outline is its text colour this far toward black

local RarityLook = {}

local moving = setmetatable({}, { __mode = "k" }) -- [UIGradient] = true
local stepping

function RarityLook.sweep()
	return (os.clock() / SWEEP) % 1 * 2 - 1
end

function RarityLook.colour(rarity)
	local look = Config.Rarities[rarity] or Config.Rarities.Common
	return look.text
end

function RarityLook.paint(label, rarity, stroke)
	local look = Config.Rarities[rarity] or Config.Rarities.Common
	label.Text = rarity or "Common"
	stroke = stroke or label:FindFirstChildOfClass("UIStroke")
	local gradient = label:FindFirstChildOfClass("UIGradient")
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Parent = label
	end
	moving[gradient] = nil
	if not look.top then
		-- (Common: white at the top to grey at the bottom)
		label.TextColor3 = Color3.new(1, 1, 1)
		gradient.Enabled = true
		gradient.Rotation = 90
		gradient.Offset = Vector2.zero
		gradient.Color = ColorSequence.new(look.text, look.text2)
		if stroke then
			stroke.Color = look.stroke
		end
		return
	end
	if stroke then
		stroke.Color = look.text:Lerp(Color3.new(0, 0, 0), DARKEN)
	end
	if not look.move then
		label.TextColor3 = look.text
		gradient.Enabled = false
		return
	end
	-- (white text, coloured by its gradient: text, a band of text2, text; the gradient's
	-- off the text at both ends of the sweep, where it's all text, so the loop doesn't jump)
	label.TextColor3 = Color3.new(1, 1, 1)
	gradient.Enabled = true
	gradient.Rotation = 0
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, look.text),
		ColorSequenceKeypoint.new(0.5, look.text2),
		ColorSequenceKeypoint.new(1, look.text),
	})
	gradient.Offset = Vector2.new(RarityLook.sweep(), 0)
	moving[gradient] = true
	if not stepping and RunService:IsClient() then
		stepping = RunService.RenderStepped:Connect(function()
			local x = RarityLook.sweep()
			for g in moving do
				if g.Parent then
					g.Offset = Vector2.new(x, 0)
				else
					moving[g] = nil
				end
			end
		end)
	end
end

return RarityLook
