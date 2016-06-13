local Shadows = ...
local World = {}

World.__index = World

function Shadows.CreateWorld(Width, Height)
	local World = setmetatable({}, World)
	
	World.Canvas = love.graphics.newCanvas(Width, Height)
	World.BodyCanvas = love.graphics.newCanvas(Width, Height)
	World.Rooms = {}
	World.Bodies = {}
	World.Lights = {}
	World.Stars = {}
	World.Changed = true
	
	return World
end

function World:AddBody(Body)
	Body.World = self
	self.Changed = true
	self.UpdateCanvas = true
	table.insert(self.Bodies, Body)
end

function World:AddLight(Light)
	Light.World = self
	Light.Changed = true
	self.UpdateCanvas = true
	table.insert(self.Lights, Light)
end

function World:AddStar(Star)
	Star.World = self
	Star.Changed = true
	self.UpdateCanvas = true
	table.insert(self.Stars, Star)
end

function World:draw(x, y)
	love.graphics.setBlendMode("darken", "premultiplied")
	love.graphics.draw(self.Canvas, -x, -y)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

function World:update()
	for Index, Body in pairs(self.Bodies) do
		Body:Update()
	end
	
	if self.Changed then
		-- self.Changed can be set to true while the bodies are updating
		-- it may be necessary to render the shape of the bodies (not their shadows) in the body canvas
		love.graphics.setCanvas(self.BodyCanvas)
		love.graphics.clear()
		
		for Index, Body in pairs(self.Bodies) do
			-- Draw the shape of every body to self.BodyCanvas
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
		love.graphics.clear()
		
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setBlendMode("add", "alphamultiply")
		for _, Light in pairs(self.Lights) do
			love.graphics.draw(Light.Canvas, Light.x - Light.Radius, Light.y - Light.Radius)
		end
		
		love.graphics.setBlendMode("alpha", "alphamultiply")
		self.UpdateCanvas = nil
	end
	love.graphics.setCanvas()
end