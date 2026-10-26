-- Studio preview (QM, Oct 26): opens StarterGui's Backpack popup on its Items tab and fills it
-- with every weapon, a few owned (copied from each row's OwnedTemplate, one with "x5" and one
-- held) and the rest undiscovered (UnknownTemplate), so you can see how it looks while
-- editing. Harmless in Play: the game clears these and fills it with what you own. Untick
-- BackpackPopup > Visible to hide it again.
local RS = game:GetService("ReplicatedStorage")
local WeaponIcons = require(RS.Shared.Weapons.WeaponIcons)
local hud = game:GetService("StarterGui"):FindFirstChild("Hud")
local popup = hud and hud.Root:FindFirstChild("BackpackPopup")
local items = popup and popup:FindFirstChild("Items", true)
if not items then
	return "no BackpackPopup > Body > Items: run uibake.luau first"
end
local unknown = items:FindFirstChild("UnknownTemplate")
local n = 0
for _, row in items:GetChildren() do
	local owned = row:FindFirstChild("OwnedTemplate")
	if owned then
		for _, c in row:GetChildren() do
			if c:IsA("GuiObject") and string.sub(c.Name, -8) ~= "Template" then
				c:Destroy()
			end
		end
		-- (a few made-up squares per row: owned, owned x5, held, then unknown)
		local ids = {}
		for id in WeaponIcons do
			table.insert(ids, id)
		end
		table.sort(ids)
		for i = 1, 4 do
			local b = (if i <= 2 or (row.Name == "Common" and i == 3) then owned else unknown):Clone()
			b.Name = "Preview" .. i
			b.Visible = true
			b.LayoutOrder = i
			local img = b:FindFirstChild("Icon")
			if img then
				img.Image = WeaponIcons[ids[(n % #ids) + 1]]
			end
			local ring = b:FindFirstChild("Ring")
			if ring then
				ring.Visible = row.Name == "Common" and i == 1
			end
			local count = b:FindFirstChild("Count")
			if count then
				count.Visible = i == 2
			end
			b.Parent = row
			n += 1
		end
	end
end
items.Visible = true
popup.Visible = true
return "backpack preview: " .. n .. " squares"
