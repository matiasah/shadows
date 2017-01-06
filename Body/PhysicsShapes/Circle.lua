local Shadows = ...
local Circle = debug.getregistry()["CircleShape"]

local insert = table.insert

local halfPi = math.pi * 0.5
local atan = math.atan
local atan2 = math.atan2
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos

function Circle:Draw(Body)
	
	local x, y = Body.Body:getWorldPoint( self:getPoint() )
	
	love.graphics.circle("fill", x, y, self:getRadius())
	
end

function Circle:GetPosition(Body)
	
	return Body.Body:getWorldPoint(self:getPoint())
	
end

function Circle:GetRadius()
	
	return self:getRadius()
	
end

function Circle:GenerateShadows(Shapes, Body, DeltaX, DeltaY, Light)
	
	local x, y = self:GetPosition(Body)
	local Radius = self:getRadius()
	
	local Lx, Ly, Lz = Light:GetPosition()
	
	Lx = Lx + DeltaX
	Ly = Ly + DeltaY
	
	local dx = x - Lx
	local dy = y - Ly

	local Distance = math.sqrt( dx * dx + dy * dy )
	
	if Distance > Radius then
		
		local Heading = atan2(Lx - x, y - Ly) + halfPi
		local Offset = atan(Radius / Distance)
		local BorderDistance = Distance * math.cos(Offset)
		
		local Length = Light.Radius
		
		if Body.z < Lz then
			
			Length = Body.z / atan2(Lz, BorderDistance)
			
		end
		
		local Polygon = {type = "polygon"}
		insert(Polygon, Lx + cos(Heading + Offset) * BorderDistance)
		insert(Polygon, Ly + sin(Heading + Offset) * BorderDistance)
		insert(Polygon, Lx + cos(Heading - Offset) * BorderDistance)
		insert(Polygon, Ly + sin(Heading - Offset) * BorderDistance)

		insert(Polygon, Polygon[3] + cos(Heading - Offset) * Length)
		insert(Polygon, Polygon[4] + sin(Heading - Offset) * Length)
		insert(Polygon, Polygon[1] + cos(Heading + Offset) * Length)
		insert(Polygon, Polygon[2] + sin(Heading + Offset) * Length)
		insert(Shapes, Polygon)
		
		if Lz > Body.z then
			
			local Circle = {type = "circle"}
			
			Circle[1] = Lx + cos(Heading) * (Length + Distance)
			Circle[2] = Ly + sin(Heading) * (Length + Distance)
			
			local dx = Polygon[5] - Circle[1]
			local dy = Polygon[6] - Circle[2]
			
			Circle[3] = math.sqrt( dx * dx + dy * dy )
			
			insert(Shapes, Circle)
			
		end
		
	end
	
end