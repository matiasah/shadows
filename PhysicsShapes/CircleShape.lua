module("shadows.PhysicsShapes.CircleShape", package.seeall)

Shadows = require("shadows")
CircleShape = debug.getregistry()["CircleShape"]

local insert = table.insert

local halfPi = math.pi * 0.5
local atan = math.atan
local atan2 = math.atan2
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos

function CircleShape:Draw(Body)
	
	local x, y = Body.Body:getWorldPoint( self:getPoint() )
	
	love.graphics.circle("fill", x, y, self:getRadius())
	
end

function CircleShape:GetPosition(Body)
	
	local x, y = Body.Body:getWorldPoint( self:getPoint() )
	local n1, n2, z = Body:GetPosition()
	
	return n1, n2, z
	
end

function CircleShape:GetRadius()
	
	return self:getRadius()
	
end

function CircleShape:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	
	local x, y = self:GetPosition(Body)
	local Radius = self:getRadius()
	
	local Lx, Ly, Lz = Light:GetPosition()
	local Bx, By, Bz = Body:GetPosition()
	
	Lx = Lx + DeltaX
	Ly = Ly + DeltaY
	Lz = Lz + DeltaZ
	
	local dx = x - Lx
	local dy = y - Ly

	local Distance = sqrt( dx * dx + dy * dy )
	
	if Distance > Radius then
		
		local Heading = atan2(Lx - x, y - Ly) + halfPi
		local Offset = atan(Radius / Distance)
		local BorderDistance = Distance * cos(Offset)
		
		local Length = Light.Radius
		
		if Bz < Lz then
			
			Length = 1 / atan2(Lz / Bz, BorderDistance)
			
		end
		
		local Polygon = {type = "polygon"}
		insert(Polygon, "fill")
		insert(Polygon, Lx + cos(Heading + Offset) * BorderDistance)
		insert(Polygon, Ly + sin(Heading + Offset) * BorderDistance)
		insert(Polygon, Lx + cos(Heading - Offset) * BorderDistance)
		insert(Polygon, Ly + sin(Heading - Offset) * BorderDistance)

		insert(Polygon, Polygon[4] + cos(Heading - Offset) * Length)
		insert(Polygon, Polygon[5] + sin(Heading - Offset) * Length)
		insert(Polygon, Polygon[2] + cos(Heading + Offset) * Length)
		insert(Polygon, Polygon[3] + sin(Heading + Offset) * Length)
		insert(Shapes, Polygon)
		
		if Lz > Bz then
			
			local Circle = {type = "circle"}
			
			insert(Circle, "fill")
			
			Circle[2] = Lx + cos(Heading) * (Length + Distance)
			Circle[3] = Ly + sin(Heading) * (Length + Distance)
			
			local dx = Polygon[6] - Circle[2]
			local dy = Polygon[7] - Circle[3]
			
			Circle[4] = sqrt( dx * dx + dy * dy )
			
			insert(Shapes, Circle)
			
		end
		
	end
	
end

return CircleShape