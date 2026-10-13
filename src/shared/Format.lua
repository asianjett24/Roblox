local Format = {}

function Format.Number(n: number): string
	local suffixes = { "", "K", "M", "B", "T" }
	local i = 1
	while math.abs(n) >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n))
	end
	return (string.format("%.1f%s", n, suffixes[i]):gsub("%.0(%a)", "%1"))
end

function Format.Kg(kg: number): string
	return string.format("%.2f kg", kg)
end

return Format
