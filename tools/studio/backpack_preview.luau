-- Studio preview (QM, Oct 26): opens StarterGui's Backpack popup and fills it with dummy tiles
-- (weapons and pets, copied from its templates) so you can see how it looks while editing.
-- Harmless in Play: the game clears these and fills it with what you own. Untick
-- BackpackPopup > Visible to hide it again.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local WeaponIcons = require(RS.Shared.Weapons.WeaponIcons)
local PetIcons = require(RS.Shared.PetIcons)
local hud = game:GetService("StarterGui"):FindFirstChild("Hud")
local popup = hud and hud.Root:FindFirstChild("BackpackPopup")
if not popup then
	return "no BackpackPopup"
end
local body = popup:FindFirstChild("Body") or popup
local row, grid = body:FindFirstChild("Equipped", true), body:FindFirstChild("Grid", true)
for _, f in { row, grid } do
	for _, c in f:GetChildren() do
		if c:IsA("GuiObject") and string.sub(c.Name, -8) ~= "Template" then
			c:Destroy()
		end
	end
end
local function fill(template, parent, name, image, count, odds, rarity, order)
	local b = template:Clone()
	b.Name = name
	b.Visible = true
	b.LayoutOrder = order
	local img = b:FindFirstChild("Icon")
	if img then
		img.Image = image or ""
		img.Visible = true
	end
	local c = b:FindFirstChild("Count")
	if c then
		c.Text = "x" .. count
		c.Visible = count > 1
	end
	local o = b:FindFirstChild("Odds")
	if o then
		local col = Config.Rarities[rarity] or Config.Rarities.Common
		o.Text = odds
		o.TextColor3 = col.Fill
		local s = o:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = col.Stroke
		end
	end
	b.Parent = parent
end
local items = {
	{ "Waraxe", "Rare", "1/57", 1 },
	{ "WaterStaff", "Epic", "1/240", 1 },
	{ "Longsword", "Legendary", "1/1.2K", 1 },
	{ "Shortsword", "Common", "1/2", 3 },
	{ "Axe", "Common", "1/3", 2 },
	{ "Club", "Common", "1/4", 1 },
	{ "KendoStick", "Uncommon", "1/12", 2 },
	{ "Shortbow", "Uncommon", "1/15", 1 },
	{ "Staff", "Uncommon", "1/18", 1 },
	{ "Longbow", "Rare", "1/60", 1 },
	{ "FireStaff", "Epic", "1/250", 1 },
	{ "BloodBow", "Legendary", "1/1.5K", 1 },
	{ "UnholyLance", "Mythic", "1/10K", 1 },
}
local eqT, tileT = row:FindFirstChild("EquippedTemplate"), grid:FindFirstChild("TileTemplate")
for i = 1, 3 do
	local it = items[i]
	fill(eqT, row, "Preview" .. i, WeaponIcons[it[1]], 1, it[3], it[2], i)
end
for i = 4, #items do
	local it = items[i]
	fill(tileT, grid, "Preview" .. i, WeaponIcons[it[1]], it[4], it[3], it[2], i)
end
local n = #items
for kind, image in PetIcons.Pets do
	n += 1
	if n > 22 then
		break
	end
	fill(tileT, grid, "Preview" .. n, image, 1, "1/" .. n * 7, "Rare", n)
end
popup.Visible = true
return "backpack preview: " .. n .. " tiles"
