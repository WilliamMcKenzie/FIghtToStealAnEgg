-- A trail streaming off a character (their HumanoidRootPart), as LassoAPet draws its
-- VIP's gold one and the sprint's white one (client/SprintTrail): two attachments,
-- over and under the middle of them, a Trail between that faces the camera, fading
-- out behind. Rebuilt under the same name replaces the old one.
--
--   RiderTrail.make(hrp, name, colors, lifetime, head?) -> the Trail (head: its
--                                                   transparency at you, 0.1 if not given)
--   RiderTrail.remove(hrp, name)

local RiderTrail = {}

local TOP, BOTTOM = Vector3.new(0, 0.8, 0), Vector3.new(0, -1.2, 0) -- (VIP's: chest to hips)

function RiderTrail.remove(hrp, name)
	for _, suffix in { "", "Top", "Bottom" } do
		local old = hrp:FindFirstChild(name .. suffix)
		if old then
			old:Destroy()
		end
	end
end

function RiderTrail.make(hrp, name, colors, lifetime, head)
	RiderTrail.remove(hrp, name)
	local top, bottom = Instance.new("Attachment"), Instance.new("Attachment")
	top.Name, bottom.Name = name .. "Top", name .. "Bottom"
	top.Position, bottom.Position = TOP, BOTTOM
	top.Parent, bottom.Parent = hrp, hrp
	local t = Instance.new("Trail")
	t.Name = name
	t.Attachment0, t.Attachment1 = top, bottom
	if #colors > 2 then -- (bands, front to back: the trail bars' trails, Config.TrailBars)
		local keys = {}
		for i, c in colors do
			table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
		end
		t.Color = ColorSequence.new(keys)
	else
		t.Color = ColorSequence.new(colors[1], colors[2] or colors[1])
	end
	t.Transparency = NumberSequence.new(head or 0.1, 1)
	t.Lifetime = lifetime
	t.MinLength = 0.2
	t.LightEmission = 0.6
	t.FaceCamera = true
	t.Parent = hrp
	return t
end

return RiderTrail
