local Shadows = ...
local Circle = debug.getregistry()["CircleShape"]

function Circle:Draw(Body)
	local x, y = Body.Body:getWorldPoint(self:getPoint())
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
	
	local Lx = Light.x + DeltaX
	local Ly = Light.y + DeltaY

	local Distance = math.sqrt((x - Lx)^2 + (y - Ly)^2)
	if Distance > Radius then
		local Heading = math.atan2(Lx - x, y - Ly) + math.pi/2
		local Offset = math.atan(Radius / Distance)
		local BorderDistance = Distance * math.cos(Offset)
		
		local Length = Light.Radius
		if Body.z < Light.z then
			Length = Body.z / math.atan2(Light.z, BorderDistance)
		end
		
		local Polygon = {type = "polygon"}
		table.insert(Polygon, Lx + math.cos(Heading + Offset) * BorderDistance)
		table.insert(Polygon, Ly + math.sin(Heading + Offset) * BorderDistance)
		table.insert(Polygon, Lx + math.cos(Heading - Offset) * BorderDistance)
		table.insert(Polygon, Ly + math.sin(Heading - Offset) * BorderDistance)

		table.insert(Polygon, Polygon[3] + math.cos(Heading - Offset) * Length)
		table.insert(Polygon, Polygon[4] + math.sin(Heading - Offset) * Length)
		table.insert(Polygon, Polygon[1] + math.cos(Heading + Offset) * Length)
		table.insert(Polygon, Polygon[2] + math.sin(Heading + Offset) * Length)
		table.insert(Shapes, Polygon)
		
		if Light.z > Body.z then
			local Circle = {type = "circle"}
			Circle[1] = Lx + math.cos(Heading) * (Length + Distance)
			Circle[2] = Ly + math.sin(Heading) * (Length + Distance)
			Circle[3] = math.sqrt((Polygon[5] - Circle[1])^2 + (Polygon[6] - Circle[2])^2)
			
			table.insert(Shapes, Circle)
		end
		
	end
end