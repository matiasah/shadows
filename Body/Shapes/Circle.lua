local Shadows = ...
local Circle = {}

Circle.__index = Circle

function Shadows.CreateCircle(Body, x, y, Radius)
	local Circle = setmetatable({}, Circle)
	
	Circle.Body = Body
	Circle.Radius = Radius
	Circle.x, Circle.y = x, y
	
	Body:AddShape(Circle)
	
	return Circle
end

function Circle:Remove()
	self.Body.Shapes[self.ID] = nil
end

function Circle:Draw()
	local Heading = math.atan2(self.y, self.x) + math.rad(self.Body.Angle)
	local Length = math.sqrt(self.x^2 + self.y^2)
	return love.graphics.circle("fill", self.Body.x + math.cos(Heading) * Length, self.Body.y + math.sin(Heading) * Length, self.Radius)
end

function Circle:GetPosition()
	if self.x ~= 0 or self.y ~= 0 then
		local Heading = math.atan2(self.y, self.x) + math.rad(self.Body.Angle)
		local Length = math.sqrt(self.x^2 + self.y^2)
		return self.Body.x + math.cos(Heading) * Length, self.Body.y + math.sin(Heading) * Length
	end
	return self.Body.x, self.Body.y
end

function Circle:GetRadius()
	return self.Radius
end

function Circle:GenerateShadows(Body, Light)
	local x, y = self:GetPosition()
	local Radius = self:GetRadius()
	
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