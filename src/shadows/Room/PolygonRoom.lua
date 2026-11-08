--- Implements a polygonal dark region within a light world.
module("shadows.Room.PolygonRoom", package.seeall)

Shadows = require("shadows")
Room = require("shadows.Room")
Transform = require("shadows.Transform")

--- @class PolygonRoom: Room
--- @field Vertices number[] Polygon vertices as alternating local x/y coordinates.
--- @field Transform Transform Transform used for room placement.
PolygonRoom = setmetatable({}, Room)
PolygonRoom.__index = PolygonRoom
PolygonRoom.__type = "PolygonRoom"

--- @description Creates and registers a polygon room when its arguments are valid.
--- @param World LightWorld? Owning world.
--- @param x number? Local x-coordinate.
--- @param y number? Local y-coordinate.
--- @param Vertices number[]? Flat array of alternating local x/y coordinates.
--- @return PolygonRoom? room New room, or an uninitialized room when arguments are missing.
function PolygonRoom:new(World, x, y, Vertices)
	local self = setmetatable({}, PolygonRoom)

	if World and x and y and Vertices and #Vertices > 0 then
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(x, y)
		self.Transform.Object = self

		self.Vertices = Vertices

		World:AddRoom(self)
	end

	return self
end

--- @description Draws the polygon into the current room canvas.
--- @return nil
function PolygonRoom:Draw()
	love.graphics.setColor(self.R, self.G, self.B, self.A)
	love.graphics.polygon("fill", self.Transform:ToWorldPoints(self.Vertices))
end

--- @description Returns the polygon vertices transformed to world coordinates.
--- @return number[] vertices Flat array of world x/y coordinates.
function PolygonRoom:GetWorldVertices()
	return self.Transform:ToWorldPoints(self.Vertices)
end

--- @description Returns the stored local polygon vertices.
--- @return number[] vertices Flat array of local x/y coordinates.
function PolygonRoom:GetVertices()
	return self.Vertices
end

--- @description Replaces the polygon's local vertices.
--- @param ... number Alternating local x/y coordinates.
--- @return nil
function PolygonRoom:SetVertices(...)
	self.Vertices = { ... }
end

return PolygonRoom
