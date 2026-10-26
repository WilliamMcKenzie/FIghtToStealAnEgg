-- Studio preview (QM, Oct 26): opens StarterGui's Backpack popup on its Items tab and fills
-- each rarity row with that rarity's real weapons, in the game's order, as a mid-game player
-- might have them: every common, a few uncommons (some doubled up), a rare or two (one held),
-- one epic, the rest undiscovered. Copied from each row's OwnedTemplate / UnknownTemplate, so
-- you see your edits. Harmless in Play: the game clears these and fills it with what you own.
-- Untick BackpackPopup > Visible to hide it again.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Weapons = require(RS.Shared.Weapons.Weapons)
local WeaponIcons = require(RS.Shared.Weapons.WeaponIcons)
local hud = game:GetService("StarterGui"):FindFirstChild("Hud")
local popup = hud and hud.Root:FindFirstChild("BackpackPopup")
local items = popup and popup:FindFirstChild("Items", true)
if not items then
	return "no BackpackPopup > Body > Items: run uibake.luau first"
end
local unknown = items:FindFirstChild("UnknownTemplate")

-- (as client/Backpack lists them)
local TYPE_ORDER = { Melee = 1, Ranged = 2, Magic = 3 }
local byRarity = {}
for id, w in Config.Weapons do
	if type(w) == "table" and w.Rarity and Weapons.exists(id) then
		byRarity[w.Rarity] = byRarity[w.Rarity] or {}
		table.insert(byRarity[w.Rarity], id)
	end
end
for _, list in byRarity do
	table.sort(list, function(a, b)
		local wa, wb = Config.Weapons[a], Config.Weapons[b]
		local ta, tb = TYPE_ORDER[wa.Type] or 9, TYPE_ORDER[wb.Type] or 9
		if ta ~= tb then
			return ta < tb
		end
		return (wa.Name or a) < (wb.Name or b)
	end)
end

-- how many of each a mid-game player has, by its place in its row (0: not found yet)
local HAVE = {
	Common = { 3, 1, 2, 1, 4, 1 },
	Uncommon = { 2, 0, 1, 0, 3, 0 },
	Rare = { 0, 1, 0, 2, 0, 0 },
	Epic = { 1, 0, 0, 0 },
}
local held = nil -- (the first rare owned)
for i, id in byRarity.Rare or {} do
	if (HAVE.Rare[i] or 0) > 0 then
		held = id
		break
	end
end

local n, owned = 0, 0
for _, row in items:GetChildren() do
	local template = row:FindFirstChild("OwnedTemplate")
	if template then
		for _, c in row:GetChildren() do
			if c:IsA("GuiObject") and string.sub(c.Name, -8) ~= "Template" then
				c:Destroy()
			end
		end
		for i, id in byRarity[row.Name] or {} do
			local have = (HAVE[row.Name] or {})[i] or 0
			local b = (if have > 0 then template else unknown):Clone()
			b.Name = id
			b.Visible = true
			b.LayoutOrder = i
			local img = b:FindFirstChild("Icon")
			if img then
				img.Image = WeaponIcons[id] or ""
			end
			local ring = b:FindFirstChild("Ring")
			if ring then
				ring.Visible = id == held
			end
			local count = b:FindFirstChild("Count")
			if count then
				count.Visible = have > 1
				for _, label in count:GetDescendants() do
					if label:IsA("TextLabel") then
						label.Text = "x" .. have
					end
				end
			end
			b.Parent = row
			n += 1
			if have > 0 then
				owned += 1
			end
		end
	end
end
items.Visible = true
popup.Visible = true
return string.format("backpack preview: %d weapons, %d owned", n, owned)
