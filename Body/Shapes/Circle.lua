local Shadows = ...
local Circle = {}

local insert = table.insert

local halfPi = math.pi * 0.5
local atan = math.atan
local atan2 = math.atan2
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos

Circle.__index = Circle

function Shadows.CreateCircle(Body, x, y, Radius)
	
	local Circle = setmetatable({}, Circle)
	
	Circle.Body = Body
	Circle.Radius = Radius
	Circle.Heading = atan2(y, x)
	Circle.Distance = sqrt(x^2 + y^2)
	
	Body:AddShape(Circle)
	
	return Circle
	
end

function Circle:Remove()
	
	self.Body.Shapes[self.ID] = nil
	self.Body.Moved = true
	self.Body.World.Changed = true
	
end

function Circle:SetRadius(Radius)
	
	if self.Radius ~= Radius then
		
		self.Radius = Radius
		self.Body.World.Changed = true
		
	end
	
end

function Circle:GetRadius()
	
	return self.Radius
	
end

function Circle:Draw()
	
	local Heading = self.Heading + math.rad(self.Body.Angle)
	
	return love.graphics.circle("fill", self.Body.x + cos(Heading) * self.Distance, self.Body.y + sin(Heading) * self.Distance, self.Radius)
	
end

function Circle:SetPosition(x, y)
	
	if self.x ~= x then
		
		self.x = x
		self.Body.World.Changed = true
		
	end
	
	if self.y ~= y then
		
		self.y = y
		self.Body.World.Changed = true
		
	end
	
end

function Circle:GetPosition()
	
	if self.Distance ~= 0 then
		
		local Heading = self.Heading + math.rad(self.Body.Angle)
		return self.Body.x + cos(Heading) * self.Distance, self.Body.y + sin(Heading) * self.Distance
		
	end
	
	return self.Body.x, self.Body.y
	
end

function Circle:GenerateShadows(Shapes, Body, DeltaX, DeltaY, Light)
	
	local x, y = self:GetPosition()
	local Radius = self:GetRadius()
	
	local Lx = Light.x + DeltaX
	local Ly = Light.y + DeltaY
	
	local dx = x - Lx
	local dy = y - Ly

	local Distance = math.sqrt( dx * dx + dy * dy )
	
	if Distance > Radius then
		
		local Heading = atan2(Lx - x, y - Ly) + halfPi
		local Offset = atan(Radius / Distance)
		local BorderDistance = Distance * math.cos(Offset)
		
		local Length = Light.Radius
		
		if Body.z < Light.z then
			
			Length = Body.z / atan2(Light.z, BorderDistance)
			
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
		
		if Light.z > Body.z then
			
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