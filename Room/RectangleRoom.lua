module("shadows.Room.RectangleRoom", package.seeall)

Shadows = require("shadows")
Room = require("shadows.Room")
Transform = require("shadows.Transform")

RectangleRoom = Room:new()
RectangleRoom.__index = RectangleRoom
RectangleRoom.__type = "RectangleRoom"

RectangleRoom.Width, RectangleRoom.Height = 0, 0

function RectangleRoom:new(World, x, y, Width, Height)
	
	local self = setmetatable( {}, RectangleRoom )
	
	if World and x and y and Width and Height then
		
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(x, y)
		self.Transform.Object = self
		
		self.Width, self.Height = Width, Height
		
		World:AddRoom(self)
		
	end
	
	return self
end

function RectangleRoom:Draw()
	
	local Width, Height = self.Width, self.Height
	
	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.polygon("fill", self.Transform:ToWorldPoints( {0, 0, Width, 0, Width, Height, 0, Height} ) )
	
end

function RectangleRoom:SetDimensions(Width, Height)
	
	if Width ~= self.Width then
		
		self.Width = Width
		self.World.UpdateCanvas = true
		
	end
	
	if Height ~= self.Height then
		
		self.Height = Height
		self.World.UpdateCanvas = true
		
	end
	
end

function RectangleRoom:GetDimensions()
	
	return self.Width, self.Height
	
end

function RectangleRoom:GetWidth()
	
	return self.Width
	
end

function RectangleRoom:GetHeight()
	
	return self.Height
	
end

return RectangleRoom