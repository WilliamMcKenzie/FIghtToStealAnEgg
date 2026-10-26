-- StarterGui's UI <-> JSON, so QM's Studio edits can be kept in the repo (ui/*.json) as well
-- as in the place: uisave.py runs encode() in Studio and writes the files, uiload.py rebuilds
-- StarterGui from them with decode(). Only properties that differ from a new object's are
-- stored. (Prepended to the code uisave.py / uiload.py send, which ends with its own call.)
local HttpService = game:GetService("HttpService")

local PROPS = {
	-- GuiObjects
	"AnchorPoint",
	"Position",
	"Size",
	"Rotation",
	"SizeConstraint",
	"AutomaticSize",
	"BackgroundColor3",
	"BackgroundTransparency",
	"BorderColor3",
	"BorderSizePixel",
	"BorderMode",
	"Visible",
	"ZIndex",
	"LayoutOrder",
	"ClipsDescendants",
	"Active",
	"Selectable",
	"Interactable",
	-- text
	"Text",
	"TextColor3",
	"TextSize",
	"FontFace",
	"TextXAlignment",
	"TextYAlignment",
	"TextScaled",
	"TextWrapped",
	"TextTransparency",
	"TextStrokeColor3",
	"TextStrokeTransparency",
	"RichText",
	"LineHeight",
	"MaxVisibleGraphemes",
	"TextTruncate",
	"PlaceholderText",
	"ClearTextOnFocus",
	-- images
	"Image",
	"ImageColor3",
	"ImageTransparency",
	"ScaleType",
	"SliceCenter",
	"SliceScale",
	"ImageRectOffset",
	"ImageRectSize",
	"TileSize",
	"ResampleMode",
	"HoverImage",
	"PressedImage",
	"AutoButtonColor",
	"Modal",
	-- scrolling
	"CanvasSize",
	"CanvasPosition",
	"AutomaticCanvasSize",
	"ScrollingDirection",
	"ScrollBarThickness",
	"ScrollBarImageColor3",
	"ScrollBarImageTransparency",
	"ScrollingEnabled",
	"ElasticBehavior",
	"VerticalScrollBarInset",
	"HorizontalScrollBarInset",
	"TopImage",
	"MidImage",
	"BottomImage",
	-- viewports
	"Ambient",
	"LightColor",
	"LightDirection",
	-- ScreenGuis
	"Enabled",
	"IgnoreGuiInset",
	"ResetOnSpawn",
	"ZIndexBehavior",
	"DisplayOrder",
	"ScreenInsets",
	-- UI modifiers
	"Color",
	"Thickness",
	"Transparency",
	"ApplyStrokeMode",
	"LineJoinMode",
	"CornerRadius",
	"Offset",
	"Scale",
	"FillDirection",
	"HorizontalAlignment",
	"VerticalAlignment",
	"Padding",
	"SortOrder",
	"Wraps",
	"HorizontalFlex",
	"VerticalFlex",
	"ItemLineAlignment",
	"CellSize",
	"CellPadding",
	"FillDirectionMaxCells",
	"StartCorner",
	"PaddingTop",
	"PaddingBottom",
	"PaddingLeft",
	"PaddingRight",
	"AspectRatio",
	"AspectType",
	"DominantAxis",
	"MinSize",
	"MaxSize",
	"MinTextSize",
	"MaxTextSize",
	"FlexMode",
	"GrowRatio",
	"ShrinkRatio",
	-- cameras (in viewports)
	"CFrame",
	"FieldOfView",
}

local function enc(v)
	local t = typeof(v)
	if t == "number" or t == "string" or t == "boolean" then
		return v
	elseif t == "Color3" then
		return { t = t, v = { v.R, v.G, v.B } }
	elseif t == "UDim" then
		return { t = t, v = { v.Scale, v.Offset } }
	elseif t == "UDim2" then
		return { t = t, v = { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset } }
	elseif t == "Vector2" then
		return { t = t, v = { v.X, v.Y } }
	elseif t == "Vector3" then
		return { t = t, v = { v.X, v.Y, v.Z } }
	elseif t == "Rect" then
		return { t = t, v = { v.Min.X, v.Min.Y, v.Max.X, v.Max.Y } }
	elseif t == "CFrame" then
		return { t = t, v = { v:GetComponents() } }
	elseif t == "EnumItem" then
		return { t = t, e = tostring(v.EnumType), v = v.Name }
	elseif t == "Font" then
		return { t = t, v = { v.Family, v.Weight.Name, v.Style.Name } }
	elseif t == "ColorSequence" then
		local k = {}
		for _, p in v.Keypoints do
			table.insert(k, { p.Time, p.Value.R, p.Value.G, p.Value.B })
		end
		return { t = t, v = k }
	elseif t == "NumberSequence" then
		local k = {}
		for _, p in v.Keypoints do
			table.insert(k, { p.Time, p.Value, p.Envelope })
		end
		return { t = t, v = k }
	end
	return nil
end

local function dec(x)
	if type(x) ~= "table" then
		return x
	end
	local t, v = x.t, x.v
	if t == "Color3" then
		return Color3.new(v[1], v[2], v[3])
	elseif t == "UDim" then
		return UDim.new(v[1], v[2])
	elseif t == "UDim2" then
		return UDim2.new(v[1], v[2], v[3], v[4])
	elseif t == "Vector2" then
		return Vector2.new(v[1], v[2])
	elseif t == "Vector3" then
		return Vector3.new(v[1], v[2], v[3])
	elseif t == "Rect" then
		return Rect.new(v[1], v[2], v[3], v[4])
	elseif t == "CFrame" then
		return CFrame.new(table.unpack(v))
	elseif t == "EnumItem" then
		return (Enum :: any)[x.e][v]
	elseif t == "Font" then
		return Font.new(v[1], Enum.FontWeight[v[2]], Enum.FontStyle[v[3]])
	elseif t == "ColorSequence" then
		local k = {}
		for _, p in v do
			table.insert(k, ColorSequenceKeypoint.new(p[1], Color3.new(p[2], p[3], p[4])))
		end
		return ColorSequence.new(k)
	elseif t == "NumberSequence" then
		local k = {}
		for _, p in v do
			table.insert(k, NumberSequenceKeypoint.new(p[1], p[2], p[3]))
		end
		return NumberSequence.new(k)
	end
	return nil
end

local defaults = {}
local function default(class)
	if defaults[class] == nil then
		local ok, inst = pcall(Instance.new, class)
		defaults[class] = ok and inst or false
	end
	return defaults[class]
end

local function encode(inst)
	local node = { class = inst.ClassName, name = inst.Name, props = {}, children = {} }
	local base = default(inst.ClassName)
	for _, p in PROPS do
		local ok, v = pcall(function()
			return (inst :: any)[p]
		end)
		if ok and v ~= nil then
			local same = base and select(
				2,
				pcall(function()
					return (base :: any)[p] == v
				end)
			)
			if same ~= true then
				node.props[p] = enc(v)
			end
		end
	end
	local attributes = inst:GetAttributes()
	if next(attributes) then
		node.attributes = {}
		for k, v in attributes do
			node.attributes[k] = enc(v)
		end
	end
	for _, child in inst:GetChildren() do
		-- (only UI: models in viewports are put there by the game)
		if child:IsA("GuiBase") or child:IsA("UIBase") or child:IsA("Folder") or child:IsA("Camera") then
			table.insert(node.children, encode(child))
		end
	end
	return node
end

local function decode(node, parent)
	local inst = Instance.new(node.class)
	inst.Name = node.name
	for p, v in node.props do
		pcall(function()
			(inst :: any)[p] = dec(v)
		end)
	end
	for k, v in node.attributes or {} do
		inst:SetAttribute(k, dec(v))
	end
	for _, child in node.children do
		decode(child, inst)
	end
	if inst:IsA("ViewportFrame") then
		inst.CurrentCamera = inst:FindFirstChildOfClass("Camera")
	end
	inst.Parent = parent
	return inst
end

local UiCodec = {}
-- every ScreenGui in StarterGui as { name = JSON }
function UiCodec.save()
	local out = {}
	for _, gui in game:GetService("StarterGui"):GetChildren() do
		if gui:IsA("ScreenGui") then
			out[gui.Name] = encode(gui)
		end
	end
	return HttpService:JSONEncode(out)
end
-- replaces StarterGui's ScreenGuis named in `json` (from save) with the saved ones
function UiCodec.load(json)
	local StarterGui = game:GetService("StarterGui")
	local names = {}
	for name, node in HttpService:JSONDecode(json) do
		local old = StarterGui:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		decode(node, StarterGui)
		table.insert(names, name)
	end
	game:GetService("ChangeHistoryService"):SetWaypoint("Load UI")
	return "loaded " .. table.concat(names, ", ")
end
