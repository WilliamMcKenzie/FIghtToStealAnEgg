-- Stacks of things a player owns, kept in one string attribute (QM, Oct 25: the
-- backpack shows duplicates as one tile with "x5"): "Kind:3,Other,Third:2", each id
-- once, in the order they were first got; a count of 1 is left off, so an old plain list
-- ("A,B,C") reads as one of each.
--
--   Stacks.parse(text, valid?) -> { { id = "A", n = 3 }, ... }  (ids `valid(id)` rejects go)
--   Stacks.format(list)        -> "A:3,B"
--   Stacks.count(list, id)     -> how many of it
--   Stacks.add(list, id, n)    -> the list, n more of it (at the end if it's new)

local Stacks = {}

function Stacks.parse(text, valid)
	local list, at = {}, {}
	for entry in string.gmatch(text or "", "[^,]+") do
		local id, n = entry:match("^%s*([^:%s]+)%s*:?%s*(%d*)%s*$")
		n = tonumber(n) or 1
		if id and n > 0 and (not valid or valid(id)) then
			if at[id] then
				at[id].n += n
			else
				at[id] = { id = id, n = n }
				table.insert(list, at[id])
			end
		end
	end
	return list
end

function Stacks.format(list)
	local out = {}
	for _, s in list do
		if s.n > 0 then
			table.insert(out, if s.n == 1 then s.id else s.id .. ":" .. s.n)
		end
	end
	return table.concat(out, ",")
end

function Stacks.count(list, id)
	for _, s in list do
		if s.id == id then
			return s.n
		end
	end
	return 0
end

function Stacks.add(list, id, n)
	for _, s in list do
		if s.id == id then
			s.n += n
			return list
		end
	end
	table.insert(list, { id = id, n = n })
	return list
end

return Stacks
