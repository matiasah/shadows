module("shadows.Functions", package.seeall)

Shadows = require("shadows")

local sqrt = math.sqrt
local min = math.min
local max = math.max

function Shadows.Normalize(v)
	
	local LengthFactor = 1 / sqrt( v[1] * v[1] + v[2] * v[2] )
	
	return {
		
		v[1] * LengthFactor,
		v[2] * LengthFactor
		
	}
	
end

function Shadows.PointInPolygon(x, y, Vertices)
	
	local Intersects = false
	local j = #Vertices - 1
	
	for i = 1, #Vertices, 2 do
		
		if Vertices[i + 1] < y and Vertices[j + 1] >= y or Vertices[j + 1] < y and Vertices[i + 1] >= y then
			
			if Vertices[i] + ( y - Vertices[i + 1] ) / (Vertices[j + 1] - Vertices[i + 1]) * (Vertices[j] - Vertices[i]) < x then
				
				Intersects = not Intersects
				
			end
			
		end
		
		j = i
		
	end
	
	return Intersects
end

function Shadows.insertionSort(Table)
	
	local Length = #Table
	
	for j = 2, Length do
		
		local Aux = Table[j]
		local i = j - 1
		
		while i > 0 and Table[j] > Aux do
			
			Table[i + 1] = Table[i]
			i = i - 1
			
		end
		
		Table[i + 1] = Aux
		
	end
	
end

function Shadows.Insert(Table, Index, Value)
	
	if Value then
		
		for i = #Table, Index, -1 do
			
			Table[i + 1] = Table[i]
			
		end
		
		Table[Index] = Value
		
	else
		
		Table[#Table + 1] = Index
		
	end
	
end