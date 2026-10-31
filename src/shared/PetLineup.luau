-- The pet lineup (QM, Oct 31): every pet in the game standing in the base's dirt patch,
-- a row per biome (commonest first, as the Index has them), each at its scale in
-- workspace.PetScale with its name and scale over its head, so sizes can be compared and
-- set. It's for Studio's Edit mode: the Map Baker plugin (or tools/studio/pet_lineup.luau
-- in the command bar) builds it and calls watch(), so changing a pet's PetScale resizes
-- it there and spaces the rows out again. Move the workspace.PetLineup model and it's
-- rebuilt where you put it. The game deletes it when it starts (Server init).
--
--   PetLineup.build()  -- (re)builds workspace.PetLineup from scratch
--   PetLineup.watch()  -> a connection: follows workspace.PetScale (and its CopyValues tick)

local Config = require(script.Parent.Config)
local IndexList = require(script.Parent.IndexList)
local PetScale = require(script.Parent.PetScale)
local Pets = require(script.Parent.Pets)

local PetLineup = {}

PetLineup.NAME = "PetLineup"

local START = Vector3.new(-4, -0.5, -124) -- the dirt patch's far end, on its floor (top -0.5)
local GAP = 4 -- studs between two pets side by side
local ROW_GAP = 8 -- studs between rows
local ROW_WIDTH = 300 -- a row this wide carries on in a new one (the base is ~340 across)

-- each row's kinds: a biome's pets each (the Index's order), then any in no biome
local function rows()
	local out, seen = {}, {}
	for _, biome in Config.Index.Order do
		local row = {}
		for _, kind in IndexList.biome(biome) do
			if not seen[kind] then
				seen[kind] = true
				table.insert(row, kind)
			end
		end
		if #row > 0 then
			table.insert(out, row)
		end
	end
	local rest = {}
	for _, kind in Pets.kinds() do
		if not seen[kind] then
			table.insert(rest, kind)
		end
	end
	if #rest > 0 then
		table.insert(out, rest)
	end
	return out
end

local function lineup()
	return workspace:FindFirstChild(PetLineup.NAME)
end

local function label(model, kind)
	local gui = model:FindFirstChild("Label")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Label"
		gui.Size = UDim2.fromOffset(180, 44)
		gui.LightInfluence = 0
		gui.MaxDistance = 600
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.TextStrokeTransparency = 0
		text.Parent = gui
		gui.Parent = model
	end
	gui.Adornee = model.PrimaryPart
	gui.Text.Text = string.format("%s\nx%s", Pets.name(kind), tostring(math.round(PetScale.of(kind) * 1000) / 1000))
	return gui
end

-- puts each pet in its place: rows back from the lineup's pivot, each row centred on it,
-- every pet's feet on the floor
local function arrange(root)
	local origin = root.WorldPivot.Position
	local z = origin.Z
	for _, row in rows() do
		-- split the row where it gets too wide
		local lines, line, width = {}, {}, 0
		for _, kind in row do
			local model = root:FindFirstChild(kind)
			if model then
				local _, size = model:GetBoundingBox()
				if #line > 0 and width + GAP + size.X > ROW_WIDTH then
					table.insert(lines, { line, width })
					line, width = {}, 0
				end
				width += (if #line > 0 then GAP else 0) + size.X
				table.insert(line, model)
			end
		end
		if #line > 0 then
			table.insert(lines, { line, width })
		end
		for _, l in lines do
			local x = origin.X - l[2] / 2
			local depth = 0
			for _, model in l[1] do
				local _, size = model:GetBoundingBox()
				depth = math.max(depth, size.Z)
			end
			for _, model in l[1] do
				local cf, size = model:GetBoundingBox()
				local goal = Vector3.new(x + size.X / 2, origin.Y + size.Y / 2, z + depth / 2)
				model:PivotTo(model:GetPivot() + (goal - cf.Position))
				local gui = model:FindFirstChild("Label")
				if gui then
					gui.StudsOffsetWorldSpace = Vector3.new(0, origin.Y + size.Y + 3 - model.PrimaryPart.Position.Y, 0)
				end
				x += size.X + GAP
			end
			z += depth + ROW_GAP
		end
	end
end

local function add(root, kind)
	local pet = Pets.class(kind).new()
	local model = pet.model
	model.Name = kind
	model:SetAttribute("Scale", PetScale.of(kind))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.Locked = true -- (so a stray click doesn't drag one block off a pet)
		end
	end
	label(model, kind)
	model.Parent = root
	return model
end

function PetLineup.build()
	PetScale.ensure()
	local pivot = CFrame.new(START)
	local old = lineup()
	if old then
		pivot = CFrame.new(old.WorldPivot.Position)
		old:Destroy()
	end
	local root = Instance.new("Model")
	root.Name = PetLineup.NAME
	root.WorldPivot = pivot
	for _, row in rows() do
		for _, kind in row do
			local ok, err = pcall(add, root, kind)
			if not ok then
				warn("[Pet lineup] " .. kind .. ": " .. tostring(err))
			end
		end
	end
	root.Parent = workspace
	arrange(root)
	return root
end

-- one pet to its PetScale value: grown or shrunk about where it stands, then the rows respaced
local function resize(kind)
	local root = lineup()
	local model = root and root:FindFirstChild(kind)
	if not model then
		return
	end
	local now, was = PetScale.of(kind), model:GetAttribute("Scale") or 1
	if now ~= was then
		model:ScaleTo(model:GetScale() * now / was)
		model:SetAttribute("Scale", now)
	end
	label(model, kind)
	arrange(root)
end

function PetLineup.watch()
	local s = PetScale.ensure()
	local root = lineup()
	if not root then
		PetLineup.build()
	else
		for _, model in root:GetChildren() do
			if model:IsA("Model") and Config.Pets[model.Name] then
				resize(model.Name) -- (values changed while nothing was watching)
			end
		end
	end
	return s.AttributeChanged:Connect(function(name)
		if name == PetScale.COPY then
			if s:GetAttribute(name) == true then
				print("[PetScale] paste this over Config.AnimalScale (src/shared/Config.luau, near the top):\n" .. PetScale.text())
				s:SetAttribute(name, false)
			end
		elseif Config.Pets[name] then
			resize(name)
		end
	end)
end

return PetLineup
