module("shadows.Room.PolygonRoom", package.seeall)

Shadows = require("shadows")
Room = require("shadows.Room")
Transform = require("shadows.Transform")

PolygonRoom = setmetatable( {}, Room )
PolygonRoom.__index = PolygonRoom
PolygonRoom.__type = "PolygonRoom"

function PolygonRoom:new(World, x, y, Vertices)
	
	local self = setmetatable( {}, PolygonRoom )
	
	if World and x and y and Vertices and #Vertices > 0 then
		
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(x, y)
		self.Transform.Object = self
		
		self.Vertices = Vertices
		
		World:AddRoom(self)
		
	end
	
	return self
	
end

function PolygonRoom:Draw()
	
	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.polygon("fill", self.Transform:ToWorldPoints( self.Vertices ) )
	
end

function PolygonRoom:GetWorldVertices()
	
	return self.Transform:ToWorldPoints( self.Vertices )
	
end

function PolygonRoom:GetVertices()
	
	return self.Vertices
	
end

function PolygonRoom:SetVertices(...)
	
	self.Vertices = {...}
	
end

return PolygonRoom