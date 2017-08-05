module("shadows.Body", package.seeall)

PriorityQueue		=	require("shadows.PriorityQueue")
Shadows				=	require("shadows")
Transform			=	require("shadows.Transform")

Body = {}
Body.__index = Body

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
	
	if self.Body then
		
		local FixtureList = self.Body:getFixtureList()
		
		for i = 1, #FixtureList do
			
			local Shape = FixtureList[i]:getShape()
			
			if Shape.Draw then
				
				Shape:Draw(self)
				
			end
			
		end
		
		return nil
		
	end
	
	for i = 1, self.Shapes:GetLength() do
		
		self.Shapes:Get(i):Draw()
		
	end
	
end

function Body:DrawRadius(x, y, DrawRadius)
	
	if self.Body then
		
		local FixtureList = self.Body:getFixtureList()
		
		for i = 1, #FixtureList do
			
			local Shape = FixtureList[i]:getShape()
			
			if Shape.Draw then
				
				local Radius = DrawRadius + Shape:GetRadius(self)
				local ShapeX, ShapeY = Shape:GetPosition(self)
				local dx, dy = ShapeX - x, ShapeY - y
				
				if dx * dx + dy * dy < Radius * Radius then
				
					Shape:Draw(self)
					
				end
				
			end
			
		end
		
		return nil
		
	end
	
	for i = 1, self.Shapes:GetLength() do
		
		local Shape = self.Shapes:Get(i)
		local Radius = DrawRadius + Shape:GetRadius()
		local ShapeX, ShapeY = Shape:GetPosition()
		local dx, dy = ShapeX - x, ShapeY - y
		
		if dx * dx + dy * dy < Radius * Radius then
			
			Shape:Draw()
			
		end
		
	end
	
end

function Body:Update()
	
	if self.Body then
		
		if self.Body:isDestroyed() then
			
			self:Remove()
			
			return nil
			
		end
		
		if self.Transform:SetPosition( self.Body:getPosition() ) or self.Transform:SetRotation( math.deg( self.Body:getAngle() ) ) then
			
			self.World.Changed = true
			
		end
		
	end
	
	for i = 1, self.Shapes:GetLength() do
		
		self.Shapes:Get(i):Update()
		
	end
	
	if self.Transform.HasChanged then
		
		self.Transform.HasChanged = false
		self.Moved = true
		
	end
	
	Shadows.insertionSort(self.Shapes.Array)
	
end

function Body:AddShape(Shape)
	
	self.Shapes:Insert(Shape)
	
	return self
	
end

function Body:SetPhysics(Body)
	
	self.Body = Body
	self.World.Changed = true
	
	return self
	
end

function Body:GetPhysics()
	
	return self.Body
	
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

return Body