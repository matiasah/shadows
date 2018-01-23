module("shadows.ShadowShapes.CircleShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")
OutputShadow = require("shadows.OutputShadow")

Shadow = require("shadows.ShadowShapes.Shadow")

CircleShadow = setmetatable( {}, Shadow )
CircleShadow.__index = CircleShadow
CircleShadow.__type = "CircleShadow"
CircleShadow.__lt = Shadow.__lt
CircleShadow.__le = Shadow.__le

local insert = Shadows.Insert

local halfPi = math.pi * 0.5
local atan2 = math.atan2
local asin = math.asin
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos

function CircleShadow:new(Body, x, y, Radius)
	
	if Body and x and y and Radius then
		
		local self = setmetatable({}, CircleShadow)
		
		self.Transform = Transform:new()
		self.Transform:SetParent(Body:GetTransform())
		self.Transform:SetLocalPosition(x, y)
		self.Transform.Object = self
		
		self.Body = Body
		self.Radius = Radius
		
		Body:AddShape(self)
		
		return self
		
	end
	
end

function CircleShadow:SetRadius(Radius)
	
	if self.Radius ~= Radius then
		
		self.Radius = Radius
		self.Changed = true
		self.Body.World.Changed = true
		
	end
	
end

function CircleShadow:GetRadius()
	
	return self.Radius
	
end

function CircleShadow:GetSqrRadius()
	
	return self.Radius * self.Radius
	
end

function CircleShadow:Draw(Lz)
	
	local x, y, z = self.Transform:GetPosition()
	
	if Lz > z then
		
		love.graphics.circle("fill", x, y, self.Radius)
		
	end
	
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
		local BorderDistance = sqrt( ( Distance - Radius ) * ( Distance + Radius ) )
		local Offset = halfPi - asin(BorderDistance / Distance)
		
		local Length = Light:GetRadius() * self.Radius
		
		if Bz < Lz then
			
			Length = 1 / atan2(Lz / Bz, BorderDistance)
			
		end
		
		local Polygon = {}
		insert(Polygon, Lx + cos(Heading + Offset) * BorderDistance)
		insert(Polygon, Ly + sin(Heading + Offset) * BorderDistance)
		insert(Polygon, Lx + cos(Heading - Offset) * BorderDistance)
		insert(Polygon, Ly + sin(Heading - Offset) * BorderDistance)

		insert(Polygon, Polygon[3] + cos(Heading - Offset) * Length)
		insert(Polygon, Polygon[4] + sin(Heading - Offset) * Length)
		insert(Polygon, Polygon[1] + cos(Heading + Offset) * Length)
		insert(Polygon, Polygon[2] + sin(Heading + Offset) * Length)
		
		insert(Shapes, OutputShadow:new("polygon", "fill", unpack(Polygon)))
		
		if Lz > Bz then
			
			local Circle = {}
			
			Circle[1] = Lx + cos(Heading) * (Length + Distance)
			Circle[2] = Ly + sin(Heading) * (Length + Distance)
			
			local dx = Polygon[5] - Circle[1]
			local dy = Polygon[6] - Circle[2]
			
			Circle[3] = sqrt( dx * dx + dy * dy )
			
			insert(Shapes, OutputShadow:new("circle", "fill", unpack(Circle)))
			
		end
		
	end
	
	do
		
		insert(Shapes, OutputShadow:new("circle", "fill", x, y, Radius))
		
	end
	
end

return CircleShadow