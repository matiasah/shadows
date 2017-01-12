local Path, Shadows = ...
local Body = {}

assert(love.filesystem.load(Path.."/Shapes/Circle.lua"))(Shadows)
assert(love.filesystem.load(Path.."/Shapes/Polygon.lua"))(Shadows)

assert(love.filesystem.load(Path.."/PhysicsShapes/Circle.lua"))(Shadows)
assert(love.filesystem.load(Path.."/PhysicsShapes/Polygon.lua"))(Shadows)

Body.__index = Body

function Shadows.CreateBody(World, ID)
	
	local Body = setmetatable({}, Body)
	
	Body.Transform = Shadows.Transform:new()
	Body.Transform:SetLocalPosition(0, 0, 1)
	
	Body.Shapes = {}
	World:AddBody(Body, ID)
	
	return Body
	
end

function Body:Remove()
	
	self.World.Shapes[self.ID] = nil
	
	for _, Light in pairs(self.World.Lights) do
		
		Light.Shadows[ self.ID ] = nil
		
	end
	
	for _, Light in pairs(self.World.Stars) do
		
		Light.Shadows[ self.ID ] = nil
		
	end
	
	self.World.Changed = true
	
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
		self.Changed = true
		
	end
	
	return self
	
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