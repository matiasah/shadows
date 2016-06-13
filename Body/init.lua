local Path, Shadows = ...
local Body = {}

Shadows.Shape = {}

assert(love.filesystem.load(Path.."/Chain.lua"))(Shadows)
assert(love.filesystem.load(Path.."/Circle.lua"))(Shadows)
assert(love.filesystem.load(Path.."/Polygon.lua"))(Shadows)

Body.__index = Body
Body.x, Body.y, Body.z = 0, 0, 0
Body.Angle = 0

function Shadows.CreateBody(World)
	local Body = setmetatable({}, Body)
	
	Body.Shapes = {}
	World:AddBody(Body)
	
	return Body
end

function Body:AddShape(Shape)
	table.insert(self.Shapes, Shape)
	return self
end

function Body:SetPhysics(Body)
	if Body:typeOf("Body") then
		self.Body = Body
		self.Changed = true
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
	end
end

function Body:SetAngle(Angle)
	if Angle ~= self.Angle then
		self.Angle = Angle
		self.World.Changed = true
	end
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
end

function Body:GetPosition()
	if self.Body then
		local x, y = self.Body:getPosition()
		return x, y, self.z
	end
	return self.x, self.y, self.z
end

function Body:GenerateShadows(Light)
	local Shadows = {}
	if self.Body then
		for _, Fixture in pairs(self.Body:getFixtureList()) do
			local Shape = Fixture:getShape()
			local Structure = Shadows.Shape[Shape:type()]
			if Structure then
				for _, Shadow in pairs(Structure.GenerateShadows(Shape, self.Body, Light)) do
					table.insert(Shadows, Shadow)
				end
			end
		end
		return Shadows
	end
	
	for _, Shape in pairs(self.Shapes) do
		for _, Shadow in pairs(Shape:GenerateShadows(self, Light)) do
			table.insert(Shadows, Shadow)
		end
	end
	return Shadows
end