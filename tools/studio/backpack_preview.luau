-- Studio preview (QM, Oct 26): opens StarterGui's Backpack popup on its Items tab and fills
-- each rarity row with that rarity's real weapons, in the game's order, as a mid-game player
-- might have them: every common, a few uncommons (some doubled up), a rare or two (one held),
-- one epic, the rest undiscovered. Copied from each row's OwnedTemplate / UnknownTemplate, so
-- you see your edits. Harmless in Play: the game clears these and fills it with what you own.
-- Untick BackpackPopup > Visible to hide it again.
--
-- It fills the Pets tab the same way (a few pets in the pen, one of them your last one so its
-- square below is see-through); SHOW picks which tab it opens on.
local SHOW = "Pets" -- "Items" or "Pets"
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local Weapons = require(RS.Shared.Weapons.Weapons)
local WeaponIcons = require(RS.Shared.Weapons.WeaponIcons)
local PetIcons = require(RS.Shared.PetIcons)
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

-- the Pets tab: every pet by rarity (cheapest first, as client/Backpack), a mid-game player's
local pets = popup:FindFirstChild("Pets", true)
local petN = 0
if pets then
	local rows, pen = pets:FindFirstChild("Rows"), pets:FindFirstChild("Pen")
	local petUnknown = rows:FindFirstChild("UnknownTemplate")
	local byPet = {}
	for kind, p in Config.Pets do
		if type(p) == "table" and p.Rarity then
			byPet[p.Rarity] = byPet[p.Rarity] or {}
			table.insert(byPet[p.Rarity], kind)
		end
	end
	for _, list in byPet do
		table.sort(list, function(a, b)
			local ca, cb = Config.Pets[a].Cash or 0, Config.Pets[b].Cash or 0
			if ca ~= cb then
				return ca < cb
			end
			return a < b
		end)
	end
	local PET_HAVE = {
		Common = { 5 },
		Uncommon = { 3, 1, 2, 0, 4, 0, 1 },
		Rare = { 1, 0, 2, 0 },
		Epic = { 1, 0, 0, 0 },
		Legendary = { 0, 0, 0 },
	}
	-- in the pen: the epic (your only one, so it fades below), a rare and an uncommon
	local inPen = {}
	for _, pick in { { "Epic", 1 }, { "Rare", 3 }, { "Uncommon", 1 } } do
		local kind = (byPet[pick[1]] or {})[pick[2]]
		if kind then
			table.insert(inPen, kind)
		end
	end
	local function clear(f)
		for _, c in f:GetChildren() do
			if c:IsA("GuiObject") and string.sub(c.Name, -8) ~= "Template" then
				c:Destroy()
			end
		end
	end
	local function square(template, kind, parent, order, count, ring, faded)
		local b = template:Clone()
		b.Name = kind
		b.Visible = true
		b.LayoutOrder = order
		local img = b:FindFirstChild("Icon")
		if img then
			img.Image = PetIcons.Pets[kind] or ""
		end
		local r = b:FindFirstChild("Ring")
		if r then
			r.Visible = ring
		end
		local c = b:FindFirstChild("Count")
		if c then
			c.Visible = count > 1
			for _, label in c:GetDescendants() do
				if label:IsA("TextLabel") then
					label.Text = "x" .. count
				end
			end
		end
		if faded then
			for _, d in b:GetDescendants() do
				if d:IsA("ImageLabel") then
					d.ImageTransparency = 1 - (1 - d.ImageTransparency) * 0.5
				end
				if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
					d.BackgroundTransparency = 1 - (1 - d.BackgroundTransparency) * 0.5
				end
				if d:IsA("UIStroke") then
					d.Transparency = 1 - (1 - d.Transparency) * 0.5
				end
			end
		end
		b.Parent = parent
		return b
	end
	clear(pen)
	for i = 1, Config.Backpack.PenSlots do
		local kind = inPen[i]
		if kind then
			local row = rows:FindFirstChild(Config.Pets[kind].Rarity)
			square(row.OwnedTemplate, kind, pen, i, 1, false, false)
		else
			local e = petUnknown:Clone()
			e.Name = "Empty" .. i
			e.Visible = true
			e.LayoutOrder = i
			e.Parent = pen
		end
	end
	for _, row in rows:GetChildren() do
		local template = row:FindFirstChild("OwnedTemplate")
		if template then
			clear(row)
			for i, kind in byPet[row.Name] or {} do
				local have = (PET_HAVE[row.Name] or {})[i] or 0
				local used = 0
				for _, k in inPen do
					if k == kind then
						used += 1
					end
				end
				if have == 0 then
					local u = petUnknown:Clone()
					u.Name = kind
					u.Visible = true
					u.LayoutOrder = i
					u.Parent = row
				else
					square(template, kind, row, i, have - used, false, have - used <= 0)
				end
				petN += 1
			end
		end
	end
end

items.Visible = SHOW == "Items"
if pets then
	pets.Visible = SHOW == "Pets"
end
for name, on in { ItemsTab = SHOW == "Items", PetsTab = SHOW == "Pets" } do
	local b = popup:FindFirstChild(name)
	if b then
		b.BackgroundTransparency = if on then 0.8 else 1
		local art = b:FindFirstChild("Icon")
		if art then
			art.ImageTransparency = if on then 0 else 0.5
		end
	end
end
popup.Visible = true
return string.format("backpack preview: %d weapons (%d owned), %d pets", n, owned, petN)
