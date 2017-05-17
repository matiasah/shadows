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

function Shadows.PointInPolygon(gx, gy, Vertices)
	
	local Minimum = Vertices[1]
	local Length = #Vertices
	
	for i = 3, Length, 2 do
		
		local x = Vertices[i]
		
		if x < Minimum then
			
			Minimum = x
			
		end
		
	end
	
	Minimum = Minimum - 1
	
	local px = Vertices[1]
	local py = Vertices[2]
	local Intersections = 0
	
	for i = 3, Length, 2 do
		
		local x = Vertices[i]
		local y = Vertices[i + 1]
		local Inclination = ( py - y ) / ( px - x )
		
		if Inclination ~= 0 then
			
			local Intersection = ( gy - y ) / Inclination + x
			
			if Intersection >= max( min(x, px), Minimum ) and Intersection <= min( max(x, px), gx) and gy >= min(y, py) and gy <= max(y, py) then
				
				Intersections = Intersections + 1
				
			end
			
		end
		
		px, py = x, y
		
	end
	
	local x = Vertices[1]
	local y = Vertices[2]
	local Inclination = ( py - y ) / ( px - x )
	
	if Inclination ~= 0 then
		
		local Intersection = ( gy - y ) / Inclination + x
		
		if Intersection >= max( min(x, px), Minimum ) and Intersection <= min( max(x, px), gx) and gy >= min(y, py) and gy <= max(y, py) then
			
			Intersections = Intersections + 1
			
		end
		
	end
	
	return  Intersections % 2 == 1
	
end