local Shadows = ...
local Room = setmetatable({}, Shadows.Room.Base)

Room.__index = Room

function Shadows.CreatePolygonRoom(World, x, y, Vertices)
	
	local Room = setmetatable({}, Room)
	
	Room.Transform = Shadows.Transform:new()
	Room.Transform:SetLocalPosition(x, y)
	
	Room.Vertices = Vertices
	
	World:AddRoom(Room)
	
	return Room
	
end

function Room:Draw()
	
	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.polygon("fill", self.Transform:ToWorldPoints( self.Vertices ) )
	
end

function Room:GetWorldVertices()
	
	return self.Transform:ToWorldPoints( self.Vertices )
	
end

function Room:GetVertices()
	
	return self.Vertices
	
end

function Room:SetVertices(...)
	
	self.Vertices = {...}
	
end