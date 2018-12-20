module("shadows.Body", package.seeall)

Object = require("shadows.Object")

PriorityQueue		=	require("shadows.PriorityQueue")
Shadows			=	require("shadows")
Transform		=	require("shadows.Transform")

CircleShadow		=	require("shadows.ShadowShapes.CircleShadow")
PolygonShadow		=	require("shadows.ShadowShapes.PolygonShadow")

Body = setmetatable( {}, Object )
Body.__index = Body
Body.__type = "Body"

function Body:new(World)
	
	if World then
		
		local self = setmetatable({}, Body)
		
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		self.Transform.Object = self
		
		self.Shapes = PriorityQueue:new()
		
		World:AddBody(self)
		
		return self
		
	end
	
end

function Body:__lt(secondBody)
	
	local x1, y1, z1 = self:GetTransform():GetPosition()
	local x2, y2, z2 = secondBody:GetTransform():GetPosition()
	
	return z1 < z2
	
end

function Body:__le(secondBody)
	
	local x1, y1, z1 = self:GetTransform():GetPosition()
	local x2, y2, z2 = secondBody:GetTransform():GetPosition()
	
	return z1 <= z2
	
end

function Body:Draw()
	
	for i = 1, self.Shapes:GetLength() do
		
		self.Shapes:Get(i):Draw()
		
	end
	
end

function Body:DrawRadius(x, y, z, DrawRadius)
	
	for i = 1, self.Shapes:GetLength() do
		
		local Shape = self.Shapes:Get(i)
		local Radius = DrawRadius + Shape:GetRadius()
		local ShapeX, ShapeY = Shape:GetCentroid()
		local dx, dy = ShapeX - x, ShapeY - y
		
		if dx * dx + dy * dy < Radius * Radius then
			
			Shape:Draw(z)
			
		end
		
	end
	
end

function Body:Update()
	
	if self.TrackBody then
		
		if self.TrackBody:isDestroyed() then
			
			self:Remove()
			
			return nil
			
		end
		
		if self.Transform:SetPosition( self.TrackBody:getPosition() ) or self.Transform:SetRotation( math.deg( self.TrackBody:getAngle() ) ) then
			
			self.World.Changed = true
			
		end
		
	end
	
	for i = 1, self.Shapes:GetLength() do
		
		local Shape = self.Shapes:Get(i)
		
		Shape:Update()
		
	end
	
	if self.Transform.HasChanged then
		
		self.Transform.HasChanged = false
		self.Changed = true
		
	end
	
	Shadows.insertionSort(self.Shapes.Array)
	
end

function Body:AddShape(Shape)
	
	self.Shapes:Insert(Shape)
	
	return self
	
end

function Body:InitFromPhysics(Body)
	
	for Index, Fixture in pairs(Body:getFixtures()) do
		
		local Shape = Fixture:getShape()
		local Type = Shape:getType()
		
		if Type == "circle" then
			
			local x, y = Shape:getPoint()
			local Radius = Shape:getRadius()
			
			CircleShadow:new(self, x, y, Radius)
			
		elseif Type == "polygon" then
			
			PolygonShadow:new(self, Shape:getPoints())
			
		end
		
	end
	
	self:TrackPhysics(Body)
	
	return self
	
end

function Body:TrackPhysics(Body)
	
	self.TrackBody = Body
	
	return self
	
end

function Body:GetTrackedPhysics()
	
	return self.TrackBody
	
end

function Body:SetAngle(Angle)
	
	self.Transform:SetRotation( Angle )
	
	return self
	
end

function Body:GetAngle()
	
	return self.Transform:GetRotation()
	
end

function Body:GetRadianAngle()
	
	return self.Transform.Radians
	
end

function Body:SetPosition(x, y, z)
	
	if self.Transform:SetPosition(x, y, z) then
		
		self.World.Changed = true
		
	end
	
	return self
	
end

function Body:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function Body:GetPositionVector()
	
	return self.Transform:GetPositionVector()
	
end

function Body:Remove()
	
	if self.World then
		
		self.World.Bodies:Remove(self)
		self.World.Changed = true
		self.World = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function Body:GetTransform()
	
	return self.Transform
	
end

function Body:GetShapes()
	
	return self.Shapes
	
end

function Body:SetChanged(Changed)
	
	self.Changed = Changed
	
end

function Body:GetChanged()
	
	return self.Changed
	
end

return Body