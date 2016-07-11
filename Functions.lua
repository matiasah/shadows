local Shadows = ...

function Shadows.Normalize(v)
	local Length = math.sqrt(v[1]^2 + v[2]^2)
	return {v[1] / Length, v[2] / Length}
end