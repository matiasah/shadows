module("shadows.LightWorld", package.seeall)

Object = require("shadows.Object")

Shadows				=		require("shadows")
Body					=		require("shadows.Body")
BodyTransform		=		require("shadows.BodyTransform")
PriorityQueue		=		require("shadows.PriorityQueue")

LightWorld = setmetatable( {}, Object )
LightWorld.__index = LightWorld
LightWorld.__type = "LightWorld"

LightWorld.R, LightWorld.G, LightWorld.B, LightWorld.A = 0, 0, 0, 255
LightWorld.x, LightWorld.y, LightWorld.z = 0, 0, 1

function LightWorld:new()
	
	local self = setmetatable( {}, LightWorld )
	local Width, Height = love.graphics.getDimensions()
	
	self.Canvas = love.graphics.newCanvas(Width, Height)
	self.Bodies = PriorityQueue:new()	-- Bodies sorted by height
	
	self.BodyTracks = {}
	self.Rooms = {}
	self.Lights = {}
	self.Stars = {}
	self.Changed = true
	
	return self
	
end

function LightWorld:Resize(Width, Height)
	
	self.Canvas = love.graphics.newCanvas(Width, Height)
	self.UpdateCanvas = true
	
	for Index, Light in pairs(self.Stars) do
		
		Light:Resize(Width, Height)
		
	end
	
end

function LightWorld:InitFromPhysics(PhysicsWorld)
	
	for _, BodyObject in pairs( PhysicsWorld:getBodyList() ) do
		
		Body:new(self):InitFromPhysics(BodyObject)
		
	end
	
end

function LightWorld:AddBody(Body)
	
	Body.World = self
	
	self.Changed = true
	self.UpdateCanvas = true
	self.Bodies:Insert(Body)
	
end

function LightWorld:AddLight(Light)
	
	local ID = #self.Lights + 1
	Light.World = self
	Light.Changed = true
	Light.Moved = true
	Light.ID = ID
	
	self.UpdateCanvas = true
	self.Lights[ID] = Light
	
	return Light
	
end

function LightWorld:AddStar(Star)
	
	local ID = #self.Stars + 1
	Star.World = self
	Star.Changed = true
	Star.Moved = true
	Star.ID = ID
	
	self.UpdateCanvas = true
	self.Stars[ID] = Star
	
	return Star
	
end

function LightWorld:AddRoom(Room)
	
	local ID = #self.Rooms + 1
	Room.World = self
	Room.ID = Room
	
	self.UpdateCanvas = true
	self.Rooms[ID] = Room
	
	return Room
	
end

function LightWorld:TrackBody(Body)
	
	local Transform = BodyTransform:new(Body)
	local ID = #self.BodyTracks + 1
	Transform.World = self
	Transform.TransformID = ID
	
	self.BodyTracks[ID] = Transform
	
	return Transform
	
end

function LightWorld:Draw()
	
	love.graphics.setBlendMode("multiply", "alphamultiply")
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.draw(self.Canvas, 0, 0)
	love.graphics.setBlendMode("alpha", "alphamultiply")
	
end

function LightWorld:SetColor(R, G, B, A)
	
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

function LightWorld:GetColor()
	
	return self.R, self.G, self.A, self.B
	
end

function LightWorld:SetPosition(x, y, z)
	
	if x ~= self.x then
		
		self.x = x
		self.UpdateCanvas = true
		self.UpdateStars = true
		
	end
	
	if y ~= self.y then
		
		self.y = y
		self.UpdateCanvas = true
		self.UpdateStars = true
		
	end
	
	if z then
		
		if z ~= self.z then
			
			self.z = z
			self.UpdateCanvas = true
			self.UpdateStars = true
			
		end
		
	end
	
end

function LightWorld:GetPosition()
	
	return self.x, self.y, self.z
	
end

function LightWorld:Update(dt)
	
	for Index, Body in pairs(self.Bodies:GetArray()) do
		
		Body:Update()
		
	end
	
	for Index, Transform in pairs(self.BodyTracks) do
		
		Transform:Update()
		
	end
	
	for Index, Light in pairs(self.Lights) do
		
		Light:Update()
		
	end; love.graphics.setCanvas()
	
	for Index, Star in pairs(self.Stars) do
		
		Star:Update()
		
	end; love.graphics.setCanvas()
	
	for Index, Room in pairs(self.Rooms) do
		
		Room:Update()
		
	end; love.graphics.setCanvas()
	
	self.Changed = false
	
	if self.UpdateCanvas then
		
		Shadows.insertionSort(self.Bodies:GetArray())
		
		self.UpdateCanvas = nil
		self.UpdateStars = nil
		
		love.graphics.setCanvas(self.Canvas)
		love.graphics.clear(self.R, self.G, self.B, self.A)
		
		love.graphics.setShader()
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.origin()
		
		for _, Light in pairs(self.Stars) do
			
			love.graphics.draw(Light.Canvas, 0, 0)
			
		end
		
		love.graphics.translate(-self.x, -self.y)
		love.graphics.scale(self.z, self.z)
		love.graphics.setShader(Shadows.DarkenShader)
		love.graphics.setBlendMode("alpha", "alphamultiply")
		
		for _, Room in pairs(self.Rooms) do
			
			Room:Draw()
			
		end
		
		love.graphics.setShader()
		love.graphics.setColor(255, 255, 255, 255)
		love.graphics.setBlendMode("add", "alphamultiply")
		
		love.graphics.origin()
		love.graphics.translate(-self.x, -self.y)
		love.graphics.scale(self.z, self.z)
		
		for _, Light in pairs(self.Lights) do
			
			local x, y = Light:GetPosition()
			
			love.graphics.draw(Light.Canvas, x - Light.Radius, y - Light.Radius)
			
		end
		
		love.graphics.setBlendMode("alpha", "alphamultiply")
		love.graphics.origin()
		
		for i = 1, self.Bodies:GetLength() do
			
			local Body = self.Bodies:Get(i)
			local Shapes = Body:GetShapes()
			
			Body:SetChanged(false)
			
			for j = 1, Shapes:GetLength() do
				
				Shapes:Get(j):SetChanged(false)
				
			end
			
		end
		
	end
	
	love.graphics.setCanvas()
	
end

function LightWorld:DrawShadows(Light)
	-- Light object can be of type 'Light' or 'Star'
end

function LightWorld:DrawSprites(Light)
	-- Light object can be of type 'Light' or 'Star'
end

function LightWorld:ForceUpdate()
	
	self.Changed = true
	
end

return LightWorld