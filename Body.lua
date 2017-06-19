module("shadows.Body", package.seeall)

Shadows		=	require("shadows")
Transform	=	require("shadows.Transform")

Body = {}
Body.__index = Body

function Body:new(World, ID)
	
	local self = setmetatable({}, Body)
	
	if World then
		
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		self.Transform.Object = self
		
		self.Shapes = {}
		
		World:AddBody(self, ID)
		
	end
	
	return self
	
end

function Body:Draw()
	
	if self.Body then
		
		for _, Fixture in pairs( self.Body:getFixtureList() ) do
			
			local Shape = Fixture:getShape()
			
			if Shape.Draw then
				
				Shape:Draw(self)
				
			end
			
		end
		
		return nil
		
	end
	
	for _, Shape in pairs(self.Shapes) do
		
		Shape:Draw()
		
	end
	
end

function Body:DrawRadius(x, y, DrawRadius)
	
	if self.Body then
		
		for _, Fixture in pairs( self.Body:getFixtureList() ) do
			
			local Shape = Fixture:getShape()
			
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
	
	for _, Shape in pairs(self.Shapes) do
		
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
		
		if self.Transform:SetPosition( self.Body:getPosition() ) or self.Transform:SetRotation( math.deg( self.Body:getAngle() ) ) then
			
			self.World.Changed = true
			
		end
		
	end
	
	for Index, Shape in pairs(self.Shapes) do
		
		Shape:Update()
		
	end
	
	if self.Transform.HasChanged then
		
		self.Transform.HasChanged = false
		self.Moved = true
		
	end
	
end

function Body:AddShape(Shape)
	
	local ID = #self.Shapes + 1
	
	Shape.ID = ID
	
	self.Shapes[ID] = Shape
	
	return self
	
end

function Body:SetPhysics(Body)
	
	if Body:typeOf("Body") then
		
		self.Body = Body
		self.World.Changed = true
		
	end
	
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
		
		self.World.Bodies[ self.ID ] = nil
		self.World.Changed = true
		self.World = nil
		self.ID = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function Body:GetTransform()
	
	return self.Transform
	
end

return Body