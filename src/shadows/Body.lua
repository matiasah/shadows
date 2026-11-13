---@module Represents a height-sorted collection of shadow shapes in a light world.
module("shadows.Body", package.seeall)

Object        = require("shadows.Object")

PriorityQueue = require("shadows.PriorityQueue")
Shadows       = require("shadows")
Transform     = require("shadows.Transform")

CircleShadow  = require("shadows.ShadowShapes.CircleShadow")
PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")

--- @class Body: Object
--- @field World LightWorld? World that owns this body.
--- @field Transform Transform Position, rotation, and height transform.
--- @field Shapes PriorityQueue Shadow shapes attached to the body.
--- @field TrackBody love.Body? Optional physics body followed during updates.
--- @field Changed boolean? Whether this body's geometry needs regeneration.
--- @field private __index Body Instance method lookup.
--- @field private __type string Runtime type name.
Body          = setmetatable({}, Object)
Body.__index  = Body
Body.__type   = "Body"

--- @description Creates a body and registers it with a light world.
--- @param World LightWorld? Owning world; when omitted, no body is created.
--- @return Body? body New body, or nil when World is omitted.
function Body:new(World)
	if World then
		local self = setmetatable({}, Body)

		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		self.Transform.Object = self

		self.Shapes = PriorityQueue:new()

		World:AddBody(self)

		return self
	end
end

--- @description Orders bodies by world-space height.
--- @param secondBody Body Body compared with this body.
--- @return boolean less Whether this body is lower.
function Body:__lt(secondBody)
	local x1, y1, z1 = self:GetTransform():GetPosition()
	local x2, y2, z2 = secondBody:GetTransform():GetPosition()

	return z1 < z2
end

--- @description Orders bodies by world-space height, including equal heights.
--- @param secondBody Body Body compared with this body.
--- @return boolean lessOrEqual Whether this body is no higher.
function Body:__le(secondBody)
	local x1, y1, z1 = self:GetTransform():GetPosition()
	local x2, y2, z2 = secondBody:GetTransform():GetPosition()

	return z1 <= z2
end

--- @description Draws every shadow shape attached to this body.
--- @return nil
function Body:Draw()
	for i = 1, self.Shapes:GetLength() do
		self.Shapes:Get(i):Draw()
	end
end

--- @description Draws shapes whose centroids fall within a radius of the supplied point.
--- @param x number Center x-coordinate.
--- @param y number Center y-coordinate.
--- @param z number Layer height passed to shapes.
--- @param DrawRadius number Search radius.
--- @return nil
function Body:DrawRadius(x, y, z, DrawRadius)
	for i = 1, self.Shapes:GetLength() do
		local Shape = self.Shapes:Get(i)
		local Radius = DrawRadius + Shape:GetRadius()
		local ShapeX, ShapeY = Shape:GetCentroid()
		local dx, dy = ShapeX - x, ShapeY - y

		if dx * dx + dy * dy < Radius * Radius then
			Shape:Draw(z)
		end
	end
end

--- @description Synchronizes tracked physics state and updates child shapes.
--- @return nil
function Body:Update()
	if self.TrackBody then
		if self.TrackBody:isDestroyed() then
			self:Remove()

			return nil
		end

		self.Transform:SetPosition(self.TrackBody:getPosition())
		self.Transform:SetRotation(math.deg(self.TrackBody:getAngle()))
	end

	for i = 1, self.Shapes:GetLength() do
		local Shape = self.Shapes:Get(i)

		Shape:Update()
	end

	if self.Transform.HasChanged then
		self.Transform.HasChanged = false
		self.Changed = true
	end

	Shadows.insertionSort(self.Shapes.Array)
end

--- @description Adds a shadow shape to this body.
--- @param Shape Shadow Shape to add.
--- @return Body body This body, for chaining.
function Body:AddShape(Shape)
	self.Shapes:Insert(Shape)

	return self
end

--- @description Creates shadow shapes from supported fixtures and tracks a physics body.
--- @param Body love.Body Physics body whose circle and polygon fixtures are copied.
--- @return Body body This body, for chaining.
function Body:InitFromPhysics(Body)
	for Index, Fixture in pairs(Body:getFixtures()) do
		local Shape = Fixture:getShape()
		local Type = Shape:getType()

		if Type == "circle" then
			local x, y = Shape:getPoint()
			local Radius = Shape:getRadius()

			CircleShadow:new(self, x, y, Radius)
		elseif Type == "polygon" then
			PolygonShadow:new(self, Shape:getPoints())
		end
	end

	self:TrackPhysics(Body)

	return self
end

--- @description Tracks a physics body so this body follows its transform.
--- @param Body love.Body Physics body to follow.
--- @return Body body This body, for chaining.
function Body:TrackPhysics(Body)
	self.TrackBody = Body

	return self
end

--- @description Returns the tracked physics body.
--- @return love.Body? body Tracked body, when configured.
function Body:GetTrackedPhysics()
	return self.TrackBody
end

--- @description Sets this body's world rotation in degrees.
--- @param Angle number Rotation angle.
--- @return Body body This body, for chaining.
function Body:SetAngle(Angle)
	self.Transform:SetRotation(Angle)

	return self
end

--- @description Returns this body's world rotation in degrees.
--- @return number angle World rotation.
function Body:GetAngle()
	return self.Transform:GetRotation()
end

--- @description Returns this body's world rotation in radians.
--- @return number angle World rotation.
function Body:GetRadianAngle()
	return self.Transform.Radians
end

--- @description Sets this body's world position and height.
--- @param x number World x-coordinate.
--- @param y number World y-coordinate.
--- @param z number? Height; preserves the current height when omitted.
--- @return Body body This body, for chaining.
function Body:SetPosition(x, y, z)
	self.Transform:SetPosition(x, y, z)

	return self
end

--- @description Returns this body's world position and height.
--- @return number x World x-coordinate.
--- @return number y World y-coordinate.
--- @return number z Height.
function Body:GetPosition()
	return self.Transform:GetPosition()
end

--- @description Returns this body's world position as a keyed vector.
--- @return table position Position with x, y, and z fields.
function Body:GetPositionVector()
	return self.Transform:GetPositionVector()
end

--- @description Removes this body from its world and detaches its transform.
--- @return nil
function Body:Remove()
	if self.World then
		self.World.Bodies:Remove(self)
		self.World = nil

		self.Transform:SetParent(nil)
	end
end

--- @description Returns this body's transform.
--- @return Transform transform Body transform.
function Body:GetTransform()
	return self.Transform
end

--- @description Returns the ordered collection of attached shapes.
--- @return PriorityQueue shapes Attached shapes.
function Body:GetShapes()
	return self.Shapes
end

--- @description Sets the geometry-dirty flag used during shadow regeneration.
--- @param Changed boolean Whether this body has changed.
--- @return nil
function Body:SetChanged(Changed)
	self.Changed = Changed
end

--- @description Returns whether this body's geometry is marked changed.
--- @return boolean? changed Dirty flag.
function Body:GetChanged()
	return self.Changed
end

return Body
