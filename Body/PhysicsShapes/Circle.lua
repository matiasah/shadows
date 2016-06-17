local Shadows = ...
local Circle = debug.getregistry()["CircleShape"]

function Circle:Draw(Body)
	local x, y = Body.Body:getWorldPoint(self:getPoint())
	love.graphics.circle("fill", x, y, self:getRadius())
end

function Circle:GetPosition(Body)
	return Body.Body:getWorldPoint(self:getPoint())
end

function Circle:GenerateShadows(Body, Light)
	local x, y = self:GetPosition(Body)
	local Radius = self:getRadius()
	
	local Shapes = {}
	local Distance = math.sqrt((x - Light.x)^2 + (y - Light.y)^2)
	if Distance > Radius then
		local Heading = math.atan2(Light.x - x, y - Light.y) + math.pi/2
		local Offset = math.atan(Radius / Distance)
		local BorderDistance = Distance * math.cos(Offset)
		
		local Length = Shadows.MaxLength
		if Body.z < Light.z then
			Length = Distance + Body.z / math.atan2(Light.z, BorderDistance)
		end
		
		local Polygon = {type = "polygon"}
		table.insert(Polygon, Light.x + math.cos(Heading + Offset) * BorderDistance)
		table.insert(Polygon, Light.y + math.sin(Heading + Offset) * BorderDistance)
		table.insert(Polygon, Light.x + math.cos(Heading - Offset) * BorderDistance)
		table.insert(Polygon, Light.y + math.sin(Heading - Offset) * BorderDistance)
		table.insert(Polygon, Light.x + math.cos(Heading - Offset) * Length)
		table.insert(Polygon, Light.y + math.sin(Heading - Offset) * Length)
		table.insert(Polygon, Light.x + math.cos(Heading + Offset) * Length)
		table.insert(Polygon, Light.y + math.sin(Heading + Offset) * Length)
		table.insert(Shapes, Polygon)
		
		if Body.z < Light.z then
			local Circle = {type = "circle"}
			local Length = Body.z / math.atan2(Light.z, Length)
			
			Circle[1] = (Polygon[5] + Polygon[7])/2
			Circle[2] = (Polygon[6] + Polygon[8])/2
			Circle[3] = math.sqrt((Polygon[5] - Circle[1])^2 + (Polygon[6] - Circle[2])^2)
			table.insert(Shapes, Circle)
		end
	end
	return Shapes
end