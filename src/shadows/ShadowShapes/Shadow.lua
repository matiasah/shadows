---@module Defines shared update, transform, sorting, and removal behavior for shadow shapes.
module("shadows.ShadowShapes.Shadow", package.seeall)

Object = require("shadows.Object")
local Mask = require("shadows.Mask")

--- @class Shadow: Object
--- @field Body Body? Body that owns this shape.
--- @field Transform Transform? Shape transform relative to its body.
--- @field Changed boolean? Whether the shape needs shadow regeneration.
--- @field ShadowMask integer? Occluder membership override; nil inherits the body, or mask 1 when detached. Use SetShadowMask.
---@field TransmissionR number Red light transmission from 0 (opaque) to 1 (clear); defaults to 0.
---@field TransmissionG number Green light transmission from 0 (opaque) to 1 (clear); defaults to 0.
---@field TransmissionB number Blue light transmission from 0 (opaque) to 1 (clear); defaults to 0.
--- @field private __index Shadow Instance method lookup.
--- @field private __type string Runtime type name.
Shadow = setmetatable({}, Object)
Shadow.__index = Shadow
Shadow.__type = "Shadow"
Shadow.TransmissionR, Shadow.TransmissionG, Shadow.TransmissionB = 0, 0, 0

---@description Validates a light-transmission channel in the normalized range.
---@param value number Transmission from 0 (opaque) to 1 (clear).
---@return number channel Validated transmission.
local function validateTransmission(value)
	assert(type(value) == "number" and value >= 0 and value <= 1,
		"Transmission channels must be numbers from 0 to 1")
	return value
end

--- @description Invalidates only this shape when its transform or an ancestor changes.
--- @return nil
function Shadow:Update()
	if self.Transform then
		if self.Transform.HasChanged then
			self.Transform.HasChanged = false
			self.Changed = true
		end
	end
end

--- @description Orders shapes by world-space height.
--- @param secondShadow Shadow Shape compared with this one.
--- @return boolean less Whether this shape is lower.
function Shadow:__lt(secondShadow)
	local x1, y1, z1 = self:GetTransform():GetPosition()
	local x2, y2, z2 = secondShadow:GetTransform():GetPosition()

	return z1 < z2
end

--- @description Orders shapes by world-space height, including equal heights.
--- @param secondShadow Shadow Shape compared with this one.
--- @return boolean lessOrEqual Whether this shape is no higher.
function Shadow:__le(secondShadow)
	local x1, y1, z1 = self:GetTransform():GetPosition()
	local x2, y2, z2 = secondShadow:GetTransform():GetPosition()

	return z1 <= z2
end

--- @description Draws this shape; subclasses provide the rendering implementation.
--- @return nil
function Shadow:Draw()

end

--- @description Sets the shape's local x and y position.
--- @param x number Local x-coordinate.
--- @param y number Local y-coordinate.
--- @return nil
function Shadow:SetPosition(x, y)
	if self.Transform:SetLocalPosition(x, y) then
		self.Changed = true
	end
end

--- @description Returns the shape's world position and height.
--- @return number x World x-coordinate.
--- @return number y World y-coordinate.
--- @return number z World height.
function Shadow:GetPosition()
	return self.Transform:GetPosition()
end

--- @description Returns the shape's world-space centroid.
--- @return number x Centroid x-coordinate.
--- @return number y Centroid y-coordinate.
--- @return number z Centroid height.
function Shadow:GetCentroid()
	return self.Transform:GetPosition()
end

--- @description Returns the shape's bounding radius.
--- @return number radius Bounding radius.
function Shadow:GetRadius()
	return math.sqrt(self:GetSqrRadius())
end

---@description Sets occluder membership or restores inheritance from the body.
---@param mask integer? Unsigned 32-bit membership mask; nil inherits the body's mask, and 0 disables casting.
---@return Shadow shape This shape, for chaining.
function Shadow:SetShadowMask(mask)
	self.ShadowMask = mask ~= nil and Mask.validate(mask) or nil
	return self
end

---@description Returns the effective occluder membership, including body inheritance.
---@return integer mask Unsigned membership mask; detached shapes default to group 0's bit.
function Shadow:GetShadowMask()
	if self.ShadowMask ~= nil then return self.ShadowMask end
	return self.Body and self.Body:GetShadowMask() or 1
end

---@description Sets per-channel light transmission for this shape's projected shadow.
---@param red number Red transmission from 0 (opaque) to 1 (clear).
---@param green number Green transmission from 0 (opaque) to 1 (clear).
---@param blue number Blue transmission from 0 (opaque) to 1 (clear).
---@return Shadow shape This shape, for chaining.
function Shadow:SetTransmission(red, green, blue)
	red = validateTransmission(red)
	green = validateTransmission(green)
	blue = validateTransmission(blue)
	if self.TransmissionR ~= red or self.TransmissionG ~= green or self.TransmissionB ~= blue then
		self.TransmissionR, self.TransmissionG, self.TransmissionB = red, green, blue
		self.Changed = true
	end
	return self
end

---@description Returns the RGB transmission applied to this shape's projected shadow.
---@return number red Red transmission from 0 (opaque) to 1 (clear).
---@return number green Green transmission from 0 (opaque) to 1 (clear).
---@return number blue Blue transmission from 0 (opaque) to 1 (clear).
function Shadow:GetTransmission()
	return self.TransmissionR, self.TransmissionG, self.TransmissionB
end

--- @description Returns the squared bounding radius; subclasses provide the geometry.
--- @return number radiusSquared Squared bounding radius.
function Shadow:GetSqrRadius()
	return 0
end

--- @description Removes this shape from its body and detaches its transform.
--- @return nil
function Shadow:Remove()
	if self.Body then
		self.Body:GetShapes():Remove(self)
		self.Body = nil

		self.Transform:SetParent(nil)
	end
end

--- @description Adds this shape's projected shadow draw calls to a list.
--- @param Shapes table Destination list of OutputShadow objects.
--- @param Body Body Owning body.
--- @param DeltaX number X offset from the light canvas origin.
--- @param DeltaY number Y offset from the light canvas origin.
--- @param DeltaZ number Height offset from the light canvas origin.
--- @param Light Light Light or star producing the shadow.
--- @return nil
function Shadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)

end

--- @description Returns the shape transform.
--- @return Transform? transform Shape transform.
function Shadow:GetTransform()
	return self.Transform
end

--- @description Sets the shape's geometry-dirty flag.
--- @param Changed boolean Whether this shape has changed.
--- @return nil
function Shadow:SetChanged(Changed)
	self.Changed = Changed
end

--- @description Returns whether this shape is marked changed.
--- @return boolean? changed Dirty flag.
function Shadow:GetChanged()
	return self.Changed
end

return Shadow
