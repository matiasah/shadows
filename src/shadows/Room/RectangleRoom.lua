--- Implements a rectangular dark region within a light world.
module("shadows.Room.RectangleRoom", package.seeall)

Shadows = require("shadows")
Room = require("shadows.Room")
Transform = require("shadows.Transform")

--- @class RectangleRoom: Room
--- @field Width number Rectangle width.
--- @field Height number Rectangle height.
--- @field Transform Transform Transform used for room placement.
RectangleRoom = Room:new()
RectangleRoom.__index = RectangleRoom
RectangleRoom.__type = "RectangleRoom"

RectangleRoom.Width, RectangleRoom.Height = 0, 0

--- @description Creates and registers a rectangular room when all required arguments are given.
--- @param World LightWorld? Owning world.
--- @param x number? Local x-coordinate.
--- @param y number? Local y-coordinate.
--- @param Width number? Rectangle width.
--- @param Height number? Rectangle height.
--- @return RectangleRoom? room New room, or an uninitialized room when an argument is omitted.
function RectangleRoom:new(World, x, y, Width, Height)
	local self = setmetatable({}, RectangleRoom)

	if World and x and y and Width and Height then
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(x, y)
		self.Transform.Object = self

		self.Width, self.Height = Width, Height

		World:AddRoom(self)
	end

	return self
end

--- @description Draws the rectangle into the current room canvas.
--- @return nil
function RectangleRoom:Draw()
	local Width, Height = self.Width, self.Height

	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.polygon("fill", self.Transform:ToWorldPoints({ 0, 0, Width, 0, Width, Height, 0, Height }))
end

--- @description Changes the rectangle dimensions and invalidates the world room canvas.
--- @param Width number New width.
--- @param Height number New height.
--- @return nil
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

--- @description Returns the rectangle width and height.
--- @return number Width Rectangle width.
--- @return number Height Rectangle height.
function RectangleRoom:GetDimensions()
	return self.Width, self.Height
end

--- @description Returns the rectangle width.
--- @return number width Rectangle width.
function RectangleRoom:GetWidth()
	return self.Width
end

--- @description Returns the rectangle height.
--- @return number height Rectangle height.
function RectangleRoom:GetHeight()
	return self.Height
end

return RectangleRoom
