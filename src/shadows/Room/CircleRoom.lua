--- Implements a circular dark region within a light world.
module("shadows.Room.CircleRoom", package.seeall)

Room = require("shadows.Room")
Shadows = require("shadows")
Transform = require("shadows.Transform")

--- @class CircleRoom: Room
--- @field Radius number Circle radius.
--- @field Transform Transform Transform used for room placement.
CircleRoom = setmetatable({}, Room)
CircleRoom.__index = CircleRoom
CircleRoom.__type = "CircleRoom"

CircleRoom.Radius = 0

--- @description Creates and registers a circular room when all required arguments are given.
--- @param World LightWorld? Owning world.
--- @param x number? Local x-coordinate.
--- @param y number? Local y-coordinate.
--- @param Radius number? Circle radius.
--- @return CircleRoom? room New room, or an uninitialized room when an argument is omitted.
function CircleRoom:new(World, x, y, Radius)
	local self = setmetatable({}, CircleRoom)

	if World and x and y and Radius then
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(x, y)
		self.Transform.Object = self

		self.Radius = Radius

		World:AddRoom(self)
	end

	return self
end

--- @description Draws the circle into the current room canvas.
--- @return nil
function CircleRoom:Draw()
	local x, y = self.Transform:GetPosition()

	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.circle("fill", x, y, self.Radius)
end

--- @description Changes the circle radius and invalidates the world room canvas.
--- @param Radius number New radius.
--- @return nil
function CircleRoom:SetRadius(Radius)
	if Radius ~= self.Radius then
		self.Radius = Radius
		self.World.UpdateCanvas = true
	end
end

--- @description Returns the circle radius.
--- @return number radius Circle radius.
function CircleRoom:GetRadius()
	return self.Radius
end

return CircleRoom
