local Shadows = ...
local World = {}

World.__index = World
World.R, World.G, World.B, World.A = 0, 0, 0, 255

function Shadows.CreateWorld(Width, Height)
	local World = setmetatable({}, World)
	
	World.Canvas = love.graphics.newCanvas(Width, Height)
	World.BodyCanvas = love.graphics.newCanvas(Width, Height)
	
	World.Filter = {
		Bloom = {Shader = Shadows.BloomShader, Active = true},
		Blur = {Shader = Shadows.BlurShader, Active = true},
		Aberration = {Shader = Shadows.AberrationShader, Active = true},
	}
	
	for FilterName, Filter in pairs(World.Filter) do
		if Filter.Active then
			Filter.Canvas = love.graphics.newCanvas(World.Canvas:getDimensions())
		end
	end
	
	World.Rooms = {}
	World.Bodies = {}
	World.Lights = {}
	World.Stars = {}
	World.Changed = true
	World.FinalFilter = World.Canvas
	
	return World
end

function World:ApplyFilters()
	local PreviousCanvas = self.Canvas
	for FilterName, Filter in pairs(self.Filter) do
		if Filter.Active then
			love.graphics.setShader(Filter.Shader)
			love.graphics.setCanvas(Filter.Canvas)
			love.graphics.draw(PreviousCanvas, 0, 0)
			PreviousCanvas = Filter.Canvas
		end
	end
	
	love.graphics.setShader()
	love.graphics.setCanvas()
	self.FinalFilter = PreviousCanvas
end

function World:SetFilter(Name, Active)
	local Filter = self.Filter[Name]
	if Filter then
		if Active and not Filter.Active then
			Filter.Active = true
			Filter.Canvas = love.graphics.newCanvas(self.Canvas:getDimensions())
			self.UpdateCanvas = true
		elseif not Active and Filter.Active then
			Filter.Active = nil
			Filter.Canvas = nil
			self.UpdateCanvas = true
		end
	end
end

function World:SetPhysics(PhysicsWorld)
	self.Physics = PhysicsWorld
end

function World:GetPhysics()
	return self.Physics
end

function World:AddBody(Body, ID)
	local ID = ID or #self.Bodies + 1
	Body.World = self
	Body.ID = ID
	
	self.Changed = true
	self.UpdateCanvas = true
	self.Bodies[ID] = Body
end

function World:AddLight(Light)
	local ID = #self.Lights + 1
	Light.World = self
	Light.Changed = true
	Light.ID = ID
	
	self.UpdateCanvas = true
	self.Lights[ID] = Light
	return Light
end

function World:AddStar(Star)
	local ID = #self.Stars + 1
	Star.World = self
	Star.Changed = true
	Star.ID = ID
	
	self.UpdateCanvas = true
	self.Stars[ID] = Star
	return Star
end

function World:AddRoom(Room)
	Room.World = self
	self.UpdateCanvas = true
	table.insert(self.Rooms, Room)
end

function World:draw(x, y)
	love.graphics.setBlendMode("darken", "premultiplied")
	love.graphics.draw(self.FinalFilter, -x, -y)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

function World:SetColor(R, G, B, A)
	if R ~= self.R then
		self.R = R
		self.UpdateCanvas = true
	end
	if G ~= self.G then
		self.G = G
		self.UpdateCanvas = true
	end
	if B ~= self.B then
		self.B = B
		self.UpdateCanvas = true
	end
	if A ~= self.A then
		self.A = A
		self.UpdateCanvas = true
	end
end

function World:GetColor()
	return self.R, self.G, self.A, self.B
end

function World:update()
	if self.Physics then
		for _, Body in pairs(self.Physics:getBodyList()) do
			if not self.Bodies[Body] then
				Shadows.CreateBody(self, Body).Body = Body
			end
		end
	end
	
	for Index, Body in pairs(self.Bodies) do
		if Body.Body and Body.Body:isDestroyed() then
			self.Bodies[Index] = nil
		else
			Body:Update()
		end
	end

	if self.Changed then
		love.graphics.setCanvas(self.BodyCanvas)
		love.graphics.clear(0, 0, 0, 255)
		love.graphics.origin()
		
		love.graphics.setColor(255, 255, 255, 255)
		for Index, Body in pairs(self.Bodies) do
			Body:Draw()
		end
	end
	
	for Index, Light in pairs(self.Lights) do
		Light:Update()
	end
	
	for Index, Star in pairs(self.Stars) do
		Star:Update()
	end
	
	self.Changed = nil
	
	if self.UpdateCanvas then
		love.graphics.setCanvas(self.Canvas)
		love.graphics.clear(self.R, self.G, self.B, self.A)
		
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setBlendMode("add", "alphamultiply")
		for _, Light in pairs(self.Stars) do
			love.graphics.draw(Light.Canvas, Light.x - Light.Radius, Light.y - Light.Radius)
		end
		
		love.graphics.setBlendMode("darken", "premultiplied")
		for _, Room in pairs(self.Rooms) do
			Room:Draw()
		end
		
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setBlendMode("add", "alphamultiply")
		for _, Light in pairs(self.Lights) do
			love.graphics.draw(Light.Canvas, Light.x - Light.Radius, Light.y - Light.Radius)
		end
		
		love.graphics.setBlendMode("alpha", "alphamultiply")
		self:ApplyFilters()
		self.UpdateCanvas = nil
	end
	love.graphics.setCanvas()
end