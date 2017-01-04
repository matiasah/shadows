local Shadows = ...

function Shadows.Normalize(v)
	
	local LengthFactor = 1 / math.sqrt(v[1]^2 + v[2]^2)
	
	return {
		
		v[1] * LengthFactor,
		v[2] * LengthFactor
		
	}
	
end