-- One-off (QM, Oct 30: "make these outlines 4px"): every label's black outline in
-- StarterGui.Hud that has the old 3 px (HudKit.label's default then) goes to 4 px. Thinner
-- ones (the hotbar's slot numbers, the badge's "!") and thicker ones are left as they are.
-- Run with lu.py in Edit, save the place, then run uisave.py.
if game:GetService("RunService"):IsRunning() then
	return "playing: stop Play first"
end
local hud = game:GetService("StarterGui"):FindFirstChild("Hud")
if not hud then
	return "no StarterGui.Hud"
end
local changed = 0
for _, stroke in hud:GetDescendants() do
	local parent = stroke.Parent
	if
		stroke:IsA("UIStroke")
		and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual
		and (parent:IsA("TextLabel") or parent:IsA("TextButton") or parent:IsA("TextBox"))
		and math.abs(stroke.Thickness - 3) < 0.01
	then
		stroke.Thickness = 4
		changed += 1
	end
end
return string.format("%d text outlines set to 4 px", changed)
