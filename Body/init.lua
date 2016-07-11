local Path, Shadows = ...
local Body = {}

assert(love.filesystem.load(Path.."/Shapes/Circle.lua"))(Shadows)
assert(love.filesystem.load(Path.."/Shapes/Polygon.lua"))(Shadows)

assert(love.filesystem.load(Path.."/PhysicsShapes/Circle.lua"))(Shadows)
assert(love.filesystem.load(Path.."/PhysicsShapes/Polygon.lua"))(Shadows)

Body.__index = Body
Body.x, Body.y, Body.z = 0, 0, 1
Body.Angle = 0

function Shadows.CreateBody(World, ID)
	local Body = setmetatable({}, Body)
	
	Body.Shapes = {}
	World:AddBody(Body, ID)
	
	return Body
end

function Body:Remove()
	self.World.Shapes[self.ID] = nil
end

function Body:Draw()
	if self.Body then
		for _, Fixture in pairs(self.Body:getFixtureList()) do
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

function Body:Update()
	if self.Body then
		local x, y = self.Body:getPosition()
		if x ~= self.x or y ~= self.y then
			self.x = x
			self.y = y
			self.World.Changed = true
		end
		
		local Angle = math.deg(self.Body:getAngle())
		if Angle ~= self.Angle then
			self.Angle = Angle
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
	if Angle ~= self.Angle then
		self.Angle = Angle
		self.World.Changed = true
	end
	return self
end

function Body:GetAngle()
	return self.Angle
end

function Body:SetPosition(x, y, z)
	if not self.Body then
		if x ~= self.x then
			self.x = x
			self.World.Changed = true
		end
		if y ~= self.y then
			self.y = y
			self.World.Changed = true
		end
	end
	
	if z and z ~= self.z then
		self.z = z
		self.World.Changed = true
	end
	return self
end

function Body:GetPosition()
	if self.Body then
		local x, y = self.Body:getPosition()
		return x, y, self.z
	end
	return self.x, self.y, self.z
end

function Body:GenerateShadows(Light)
	local Shapes = {}
	if self.Body then
		for _, Fixture in pairs(self.Body:getFixtureList()) do
			local Shape = Fixture:getShape()
			if Shape.GenerateShadows then
				local Radius = Light.Radius + Shape:GetRadius(self)
				local x, y = Shape:GetPosition(self)
				if (x - Light.x)^2 + (y - Light.y)^2 < Radius * Radius then
					for _, Shadow in pairs(Shape:GenerateShadows(self, Light)) do
						table.insert(Shapes, Shadow)
					end
				end
			end
		end
		return Shapes
	end
	
	for _, Shape in pairs(self.Shapes) do
		local Radius = Light.Radius + Shape:GetRadius()
		local x, y = Shape:GetPosition()
		if (x - Light.x)^2 + (y - Light.y)^2 < Radius * Radius then
			for _, Shadow in pairs(Shape:GenerateShadows(self, Light)) do
				table.insert(Shapes, Shadow)
			end
		end
	end
	return Shapes
end