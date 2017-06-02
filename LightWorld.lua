module("shadows.LightWorld", package.seeall)

Shadows				=		require("shadows")
Body					=		require("shadows.Body")
BodyTransform		=		require("shadows.BodyTransform")

LightWorld = {}
LightWorld.__index = LightWorld

LightWorld.R, LightWorld.G, LightWorld.B, LightWorld.A = 0, 0, 0, 255
LightWorld.x, LightWorld.y, LightWorld.z = 0, 0, 1

function LightWorld:new()
	
	local self = setmetatable( {}, LightWorld )
	local Width, Height = love.graphics.getDimensions()
	
	self.Canvas = love.graphics.newCanvas(Width, Height)
	
	self.BodyTracks = {}
	self.Rooms = {}
	self.Bodies = {}
	self.Lights = {}
	self.Stars = {}
	self.NormalMaps = {}
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

function LightWorld:SetPhysics(PhysicsWorld)
	
	self.Physics = PhysicsWorld
	
end

function LightWorld:GetPhysics()
	
	return self.Physics
	
end

function LightWorld:AddBody(Body, ID)
	
	local ID = ID or #self.Bodies + 1
	Body.World = self
	Body.ID = ID
	
	self.Changed = true
	self.UpdateCanvas = true
	self.Bodies[ID] = Body
	
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

function LightWorld:AddNormalMap(NormalMap)
	
	local ID = #self.NormalMaps + 1
	NormalMap.World = self
	NormalMap.ID = ID
	
	self.Changed = true
	self.NormalMaps[ID] = NormalMap
	
	return NormalMap
	
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
	
	if self.Physics then
		
		for _, BodyObject in pairs( self.Physics:getBodyList() ) do
			
			-- The 'Body' userdata is interpreted as a 'ID' (a.k.a table index)
			
			if not self.Bodies[BodyObject] then
				
				Body:new(self, BodyObject).Body = BodyObject
				
			end
			
		end
		
	end
	
	for Index, Body in pairs(self.Bodies) do
		
		if Body.Body and Body.Body:isDestroyed() then
			
			Body:Remove()
			
		else
			
			Body:Update()
			
		end
		
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
	
	for Index, NormalMap in pairs(self.NormalMaps) do
		
		NormalMap:Update()
		
	end
	
	self.Changed = false
	
	if self.UpdateCanvas then
		
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
		
		for Index, Body in pairs(self.Bodies) do
			
			Body.Moved = false
			
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