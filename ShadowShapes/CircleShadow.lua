module("shadows.ShadowShapes.CircleShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")

CircleShadow = {}
CircleShadow.__index = CircleShadow

local insert = table.insert

local halfPi = math.pi * 0.5
local atan = math.atan
local atan2 = math.atan2
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos

function CircleShadow:new(Body, x, y, Radius)
	
	local self = setmetatable({}, CircleShadow)
	
	if Body and x and y and Radius then
	
		self.Transform = Transform:new()
		self.Transform:SetParent(Body:GetTransform())
		self.Transform:SetLocalPosition(x, y)
		self.Transform.Object = self
		
		self.Body = Body
		self.Radius = Radius
		
		Body:AddShape(self)
		
	end
	
	return self
	
end

function CircleShadow:Update()
	
	if self.Transform.HasChanged then
		
		self.Body:GetTransform().HasChanged = true
		
	end
	
end

function CircleShadow:Remove()
	
	if self.Body then
		
		self.Body.Shapes[self.ID] = nil
		self.Body.World.Changed = true
		self.Body = nil
		self.ID = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function CircleShadow:SetRadius(Radius)
	
	if self.Radius ~= Radius then
		
		self.Radius = Radius
		self.Body.World.Changed = true
		
	end
	
end

function CircleShadow:GetRadius()
	
	return self.Radius
	
end

function CircleShadow:GetSqrRadius()
	
	return self.Radius * self.Radius
	
end

function CircleShadow:Draw()
	
	local x, y = self.Transform:GetPosition()
	
	return love.graphics.circle("fill", x, y, self.Radius)
	
end

function CircleShadow:SetPosition(x, y)
	
	if self.Transform:SetLocalPosition(x, y) then
		
		self.Body.World.Changed = true
		
	end
	
end

function CircleShadow:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function CircleShadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	
	local x, y, Bz = self:GetPosition()
	local Radius = self:GetRadius()
	
	local Lx, Ly, Lz = Light:GetPosition()
	local Bx, By = Body:GetPosition()
	
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

return CircleShadow