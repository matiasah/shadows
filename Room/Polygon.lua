local Shadows = ...
local Room = setmetatable({}, Shadows.Room.Base)

Room.__index = Room

function Shadows.CreatePolygonRoom(World, x, y, ...)
	local Room = setmetatable({}, Room)
	
	Room.x, Room.y = x, y
	Room.Vertices = {...}
	World:AddRoom(Room)
	
	return Room
end

function Room:Draw()
	love.graphics.translate(self.x, self.y)
	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.polygon("fill", unpack(self.Vertices))
	love.graphics.origin()
end

function Room:GetWorldVertices()
	local Vertices = {}
	for i = 1, #self.Vertices, 2 do
		Vertices[i] = self.Vertices[i] + self.x
		Vertices[i + 1] = self.Vertices[i + 1] + self.y
	end
	return Vertices
end

function Room:GetVertices()
	return self.Vertices
end

function Room:SetVertices(...)
	self.Vertices = {...}
end