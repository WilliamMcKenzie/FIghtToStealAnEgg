-- Damage numbers: "-10" popping up over whatever was hit (client/BossView's bosses in white;
-- client/PlayerBars' players in red, QM Oct 27).
--
--   DamageNumbers.pop(adornee, amount, height, colour?) -- height: studs over the adornee's
--     middle it starts; colour: white if left out

local TweenService = game:GetService("TweenService")

local DamageNumbers = {}

-- white (or `colour`) Montserrat with a soft drop shadow down-right (QM)
local NUMBER_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold)
local NUMBER_SIZE = 20
local NUMBER_SHADOW = 1 -- px the shadow sits down and right
local NUMBER_SHADOW_ALPHA = 0.75 -- shadow transparency
local NUMBER_RISE = 3.5 -- studs it floats up
local NUMBER_LIFE = 0.45 -- seconds on screen
local NUMBER_POP = 1.4 -- how big it overshoots as it pops in, before settling to full size
-- (drawn at SHARP times the size and scaled back down, so the text grows smoothly instead of
-- stepping a whole font size at a time)
local SHARP = 4

-- "-10" over its head: pops in past full size and settles, shoots up a little off to
-- one side easing to a stop, then fades and shrinks away (QM: quicker, with a pop)
local combos = {} -- [body] = { gui, x }: the number still showing over it
function DamageNumbers.pop(body, amount, height, colour)
	-- hit again before the last number's gone: it's replaced by the new hit's number, popping in
	-- afresh in the same spot (QM: not added up)
	local combo = combos[body]
	local x = (math.random() - 0.5) * 3
	if combo and combo.gui.Parent then
		combo.gui:Destroy()
		x = combo.x -- (in the same spot, so it pops rather than jumps)
	end
	local gui = Instance.new("BillboardGui")
	gui.Adornee = body
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(160 * SHARP, 40 * SHARP)
	gui.StudsOffset = Vector3.new(x, height, 0)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	-- (scaled about its middle, so the pop grows from the number's centre)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	local function text(colour, offset, z)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Position = UDim2.fromOffset(offset * SHARP, offset * SHARP)
		label.ZIndex = z
		label.FontFace = NUMBER_FONT
		label.TextSize = NUMBER_SIZE * SHARP
		label.TextColor3 = colour
		label.Text = "-" .. tostring(math.round(amount))
		label.Parent = holder
		return label
	end
	local shadow = text(Color3.new(0, 0, 0), NUMBER_SHADOW, 1)
	shadow.TextTransparency = NUMBER_SHADOW_ALPHA
	local label = text(colour or Color3.new(1, 1, 1), 0, 2)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder
	holder.Parent = gui
	gui.Parent = body
	-- pops in: bursts past full size, then settles back (overshoot and settle)
	local grow = TweenService:Create(scale, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = NUMBER_POP / SHARP,
	})
	grow.Completed:Connect(function()
		TweenService
			:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 / SHARP })
			:Play()
	end)
	grow:Play()
	-- shoots up fast and eases to a stop (slow out)
	TweenService:Create(gui, TweenInfo.new(NUMBER_LIFE, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		StudsOffset = gui.StudsOffset + Vector3.new(x * 0.3, NUMBER_RISE, 0),
	}):Play()
	-- then fades and shrinks away over its last half
	local fade =
		TweenInfo.new(NUMBER_LIFE * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, NUMBER_LIFE * 0.5)
	TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	TweenService:Create(shadow, fade, { TextTransparency = 1 }):Play()
	task.delay(NUMBER_LIFE * 0.5, function()
		TweenService:Create(scale, TweenInfo.new(NUMBER_LIFE * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Scale = 0.6 / SHARP,
		}):Play()
	end)
	combos[body] = { gui = gui, x = x }
	task.delay(NUMBER_LIFE, function()
		gui:Destroy()
		if combos[body] and combos[body].gui == gui then
			combos[body] = nil
		end
	end)
end

return DamageNumbers
