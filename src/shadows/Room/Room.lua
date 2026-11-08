---@module Provides shared color, transform, and lifecycle behavior for dark rooms.
module("shadows.Room", package.seeall)

Object = require("shadows.Object")
Shadows = require("shadows")

--- @class Room: Object
--- @field World LightWorld? World containing this room.
--- @field Transform Transform Transform used for room placement.
--- @field ID any? Identifier assigned by the owning world.
--- @field R number Red color channel in the 0-1 range; defaults to 0.
--- @field G number Green color channel in the 0-1 range; defaults to 0.
--- @field B number Blue color channel in the 0-1 range; defaults to 0.
--- @field A number Alpha color channel in the 0-1 range; defaults to 1.
--- @field private __index Room Instance method lookup.
--- @field private __type string Runtime type name.
Room = setmetatable({}, Object)
Room.__index = Room
Room.__type = "Room"

Room.R, Room.G, Room.B, Room.A = 0, 0, 0, 1

--- @description Creates an unregistered base room.
--- @return Room room New base room.
function Room:new()
	return setmetatable({}, Room)
end

--- @description Sets the room fill color and marks the world canvas dirty when it changes.
--- @param R number Red channel in the 0-1 range.
--- @param G number Green channel in the 0-1 range.
--- @param B number Blue channel in the 0-1 range.
--- @param A number Alpha channel in the 0-1 range.
--- @return nil
function Room:SetColor(R, G, B, A)
	if R ~= self.R then
		self.R = R
		self.World.UpdateCanvas = true
	end

	if G ~= self.G then
		self.G = G
		self.World.UpdateCanvas = true
	end

	if B ~= self.B then
		self.B = B
		self.World.UpdateCanvas = true
	end

	if A ~= self.A then
		self.A = A
		self.World.UpdateCanvas = true
	end
end

--- @description Marks the world canvas dirty when the room transform changes.
--- @return nil
function Room:Update()
	if self.Transform.HasChanged then
		self.Transform.HasChanged = nil
		self.World.UpdateCanvas = true
	end
end

--- @description Returns the room's world position.
--- @return number x World x-coordinate.
--- @return number y World y-coordinate.
--- @return number z World height.
function Room:GetPosition()
	return self.Transform:GetPosition()
end

--- @description Sets the room's world position.
--- @param x number World x-coordinate.
--- @param y number World y-coordinate.
--- @param z number? World height.
--- @return boolean? changed Whether the transform changed.
function Room:SetPosition(x, y, z)
	return self.Transform:SetPosition(x, y, z)
end

--- @description Returns the room's local position.
--- @return number x Local x-coordinate.
--- @return number y Local y-coordinate.
--- @return number z Local height.
function Room:GetLocalPosition()
	return self.Transform:GetLocalPosition()
end

--- @description Sets the room's local position.
--- @param x number Local x-coordinate.
--- @param y number Local y-coordinate.
--- @param z number? Local height.
--- @return boolean? changed Whether the transform changed.
function Room:SetLocalPosition(x, y, z)
	return self.Transform:SetLocalPosition(x, y, z)
end

--- @description Returns the room's world rotation in degrees.
--- @return number rotation World rotation.
function Room:GetRotation()
	return self.Transform:GetRotation()
end

--- @description Sets the room's world rotation in degrees.
--- @param Rotation number World rotation.
--- @return boolean? changed Whether the transform changed.
function Room:SetRotation(Rotation)
	return self.Transform:SetRotation(Rotation)
end

--- @description Returns the room's local rotation in degrees.
--- @return number rotation Local rotation.
function Room:GetLocalRotation()
	return self.Transform:GetLocalRotation()
end

--- @description Sets the room's local rotation in degrees.
--- @param Rotation number Local rotation.
--- @return boolean? changed Whether the transform changed.
function Room:SetLocalRotation(Rotation)
	return self.Transform:SetLocalRotation(Rotation)
end

--- @description Returns the room's RGBA color.
--- @return number R Red channel in the 0-1 range.
--- @return number G Green channel in the 0-1 range.
--- @return number B Blue channel in the 0-1 range.
--- @return number A Alpha channel in the 0-1 range.
function Room:GetColor()
	return self.R, self.G, self.B, self.A
end

--- @description Removes the room from its world and detaches its transform.
--- @return nil
function Room:Remove()
	if self.World then
		self.World.Rooms[self.ID] = nil
		self.World.UpdateCanvas = true
		self.World = nil
		self.ID = nil

		self.Transform:SetParent(nil)
	end
end

--- @description Returns the room's transform.
--- @return Transform transform Room transform.
function Room:GetTransform()
	return self.Transform
end

return Room
