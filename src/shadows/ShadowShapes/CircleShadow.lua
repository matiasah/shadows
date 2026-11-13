---@module Implements a circular occluder and projects its shadow for a light.
module("shadows.ShadowShapes.CircleShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")
OutputShadow = require("shadows.OutputShadow")

Shadow = require("shadows.ShadowShapes.Shadow")

--- @class CircleShadow: Shadow
--- @field Radius number Circle radius.
--- @field Body Body Owning body.
--- @field Transform Transform Shape transform relative to its body.
--- @field private __index CircleShadow Instance method lookup.
--- @field private __type string Runtime type name.
CircleShadow = setmetatable({}, Shadow)
CircleShadow.__index = CircleShadow
CircleShadow.__type = "CircleShadow"
CircleShadow.__lt = Shadow.__lt
CircleShadow.__le = Shadow.__le

local insert = Shadows.Insert

local halfPi = math.pi * 0.5
local atan2 = math.atan2
local asin = math.asin
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos

--- @description Creates a circle shadow and attaches it to a body.
--- @param Body Body? Owning body.
--- @param x number? Local x-coordinate.
--- @param y number? Local y-coordinate.
--- @param Radius number? Circle radius.
--- @return CircleShadow? shape New shape, or nil when an argument is omitted.
function CircleShadow:new(Body, x, y, Radius)
	if Body and x and y and Radius then
		local self = setmetatable({}, CircleShadow)

		self.Transform = Transform:new()
		self.Transform:SetParent(Body:GetTransform())
		self.Transform:SetLocalPosition(x, y)
		self.Transform.Object = self

		self.Body = Body
		self.Radius = Radius

		Body:AddShape(self)

		return self
	end
end

--- @description Changes the circle radius and invalidates cached shadows.
--- @param Radius number New circle radius.
--- @return nil
function CircleShadow:SetRadius(Radius)
	if self.Radius ~= Radius then
		self.Radius = Radius
		self.Changed = true
	end
end

--- @description Returns the circle radius.
--- @return number radius Circle radius.
function CircleShadow:GetRadius()
	return self.Radius
end

--- @description Returns the squared circle radius.
--- @return number radiusSquared Squared circle radius.
function CircleShadow:GetSqrRadius()
	return self.Radius * self.Radius
end

--- @description Draws the circle when it lies above the supplied shadow layer.
--- @param Lz number Height of the light/shadow layer.
--- @return nil
function CircleShadow:Draw(Lz)
	local x, y, z = self.Transform:GetPosition()

	if Lz > z then
		love.graphics.circle("fill", x, y, self.Radius)
	end
end

--- @description Appends projected circle-shadow geometry to the supplied draw-call list.
--- @param Shapes table Destination list of OutputShadow objects.
--- @param Body Body Owning body.
--- @param DeltaX number X offset from the light canvas origin.
--- @param DeltaY number Y offset from the light canvas origin.
--- @param DeltaZ number Height offset from the light canvas origin.
--- @param Light Light Light or star producing the shadow.
--- @return nil
function CircleShadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	local x, y, Bz = self:GetPosition()
	local Radius = self:GetRadius()

	local Lx, Ly, Lz = Light:GetPosition()
	local Bx, By = Body:GetPosition()

	Lx = Lx + DeltaX
	Ly = Ly + DeltaY
	Lz = Lz + DeltaZ

	local dx = x - Lx
	local dy = y - Ly

	local Distance = sqrt(dx * dx + dy * dy)

	if Distance > Radius then
		local Heading = atan2(Lx - x, y - Ly) + halfPi
		local BorderDistance = sqrt((Distance - Radius) * (Distance + Radius))
		local Offset = halfPi - asin(BorderDistance / Distance)

		local Length = Light:GetRadius() * self.Radius

		if Bz < Lz then
			Length = 1 / atan2(Lz / Bz, BorderDistance)
		end

		local Polygon = {}
		insert(Polygon, Lx + cos(Heading + Offset) * BorderDistance)
		insert(Polygon, Ly + sin(Heading + Offset) * BorderDistance)
		insert(Polygon, Lx + cos(Heading - Offset) * BorderDistance)
		insert(Polygon, Ly + sin(Heading - Offset) * BorderDistance)

		insert(Polygon, Polygon[3] + cos(Heading - Offset) * Length)
		insert(Polygon, Polygon[4] + sin(Heading - Offset) * Length)
		insert(Polygon, Polygon[1] + cos(Heading + Offset) * Length)
		insert(Polygon, Polygon[2] + sin(Heading + Offset) * Length)

		insert(Shapes, OutputShadow:new("polygon", "fill", unpack(Polygon)))

		if Lz > Bz then
			local Circle = {}

			Circle[1] = Lx + cos(Heading) * (Length + Distance)
			Circle[2] = Ly + sin(Heading) * (Length + Distance)

			local dx = Polygon[5] - Circle[1]
			local dy = Polygon[6] - Circle[2]

			Circle[3] = sqrt(dx * dx + dy * dy)

			insert(Shapes, OutputShadow:new("circle", "fill", unpack(Circle)))
		end
	end

	do
		insert(Shapes, OutputShadow:new("circle", "fill", x, y, Radius))
	end
end

return CircleShadow
