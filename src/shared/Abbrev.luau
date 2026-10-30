-- The one way every number the player sees is written (QM, Oct 30): 950, 1K, 1.5K, 15K,
-- 2.3M, 4B, 1T, then Qa, Qi, Sx, Sp, Oc, No, Dc and on past that. Under 10 of a suffix it
-- keeps one decimal (1.5K), above it whole (15K, 150K); it rounds down, so a price never
-- shows less than it costs. Cash, Power, prices, HP, damage, DPS, bounties, counts all use it.
--
--   Abbrev(n) -> string   (also Abbrev.format(n))

local SUFFIXES = {
	"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No",
	"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}

local function format(n)
	n = tonumber(n) or 0
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n == math.huge then
		return sign .. "inf"
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	-- (floored, not rounded: 1,999 reads 1.9K and 999,999 reads 999K, never 1000K)
	local s
	if i > 1 and n < 10 then
		s = string.format("%.1f", math.floor(n * 10 + 1e-9) / 10)
	else
		s = tostring(math.floor(n + 1e-9))
	end
	return sign .. (string.gsub(s, "%.0$", "")) .. SUFFIXES[i]
end

return setmetatable({ format = format }, {
	__call = function(_, n)
		return format(n)
	end,
})
