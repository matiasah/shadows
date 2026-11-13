---@module Implements a polygonal occluder and projects its visible edges as a shadow.
module("shadows.ShadowShapes.PolygonShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")
OutputShadow = require("shadows.OutputShadow")

Shadow = require("shadows.ShadowShapes.Shadow")

--- @class PolygonShadow: Shadow
--- @field Vertices number[] Centered local vertices as alternating x/y values.
--- @field private Triangles number[][] Triangulated centered vertices for drawing concave polygons.
--- @field private Convex boolean Whether the polygon can be projected as a single silhouette.
--- @field CentroidTransform Transform Transform positioned at the polygon centroid.
--- @field Radius number Bounding radius.
--- @field SqrRadius number Squared bounding radius.
--- @field World LightWorld Owning light world.
--- @field Body Body Owning body.
--- @field Transform Transform Shape transform relative to its body.
--- @field private __index PolygonShadow Instance method lookup.
--- @field private __type string Runtime type name.
PolygonShadow = setmetatable({}, Shadow)
PolygonShadow.__index = PolygonShadow
PolygonShadow.__type = "PolygonShadow"
PolygonShadow.__lt = Shadow.__lt
PolygonShadow.__le = Shadow.__le

local Normalize = Shadows.Normalize
local insert = Shadows.Insert

local atan2 = math.atan2
local sqrt = math.sqrt

--- @description Creates a polygon shadow from alternating local x/y coordinates.
--- @param Body Body? Owning body.
--- @param ... number Polygon vertex coordinates.
--- @return PolygonShadow? shape New shape, or nil when the body or vertices are omitted.
function PolygonShadow:new(Body, ...)
	local Vertices = { ... }

	if Body and Vertices and #Vertices > 0 then
		local self = setmetatable({}, PolygonShadow)

		self.Transform = Transform:new()
		self.Transform:SetParent(Body:GetTransform())
		self.Transform.Object = self

		self.Body = Body
		self.World = Body.World
		self:SetVertices(...)

		Body:AddShape(self)

		return self
	end
end

--- @description Draws the polygon when it lies above the supplied shadow layer.
--- @param Lz number Height of the light/shadow layer.
--- @return nil
function PolygonShadow:Draw(Lz)
	local x, y, z = self.Transform:GetPosition()

	if Lz > z then
		if self.Convex then
			love.graphics.polygon("fill", self:GetVertices())
		else
			for _, Triangle in ipairs(self.Triangles) do
				love.graphics.polygon("fill", self.CentroidTransform:ToWorldPoints(Triangle))
			end
		end
	end
end

--- @description Returns the polygon bounding radius.
--- @return number radius Bounding radius.
function PolygonShadow:GetRadius()
	return self.Radius
end

--- @description Returns the squared polygon bounding radius.
--- @return number radiusSquared Squared bounding radius.
function PolygonShadow:GetSqrRadius()
	return self.SqrRadius
end

--- @description Returns the polygon centroid in world coordinates.
--- @return number x Centroid x-coordinate.
--- @return number y Centroid y-coordinate.
--- @return number z Centroid height.
function PolygonShadow:GetCentroid()
	return self.CentroidTransform:GetPosition()
end

--- @description Replaces the vertices and recalculates the centroid and bounding radius.
--- @param ... number Alternating local x/y coordinates.
--- @return nil
function PolygonShadow:SetVertices(...)
	local Vertices = { ... }
	local CentroidX = 0
	local CentroidY = 0

	for i = 1, #Vertices, 2 do
		CentroidX = CentroidX + Vertices[i]
		CentroidY = CentroidY + Vertices[i + 1]
	end

	CentroidX = CentroidX * 2 / #Vertices
	CentroidY = CentroidY * 2 / #Vertices

	self.Vertices = {}
	self.CentroidTransform = Transform:new()
	self.CentroidTransform:SetLocalPosition(CentroidX, CentroidY)
	self.CentroidTransform:SetParent(self.Transform)

	self.Radius = 0
	self.SqrRadius = 0
	self.Changed = true

	for i = 1, #Vertices, 2 do
		local x = Vertices[i] - CentroidX
		local y = Vertices[i + 1] - CentroidY
		local SqrRadius = x * x + y * y

		self.Vertices[i] = x
		self.Vertices[i + 1] = y

		if SqrRadius > self.SqrRadius then
			self.SqrRadius = SqrRadius
		end
	end

	self.Radius = sqrt(self.SqrRadius)
	self.Convex = love.math.isConvex(self.Vertices)
	self.Triangles = self.Convex and {} or love.math.triangulate(self.Vertices)
end

--- @description Returns polygon vertices transformed to world coordinates.
--- @return number[] vertices Flat array of alternating world x/y coordinates.
function PolygonShadow:GetVertices()
	return self.CentroidTransform:ToWorldPoints(self.Vertices)
end

--- @description Projects one convex silhouette, including a triangle of a concave polygon.
--- @param self PolygonShadow Shape supplying projection bounds.
--- @param Shapes table Destination list of OutputShadow objects.
--- @param Body Body Owning body.
--- @param DeltaX number X offset from the light canvas origin.
--- @param DeltaY number Y offset from the light canvas origin.
--- @param DeltaZ number Height offset from the light canvas origin.
--- @param Light Light Light or star producing the shadow.
--- @param Vertices number[] World-space convex polygon vertices.
--- @return nil
local function GenerateConvexShadows(self, Shapes, Body, DeltaX, DeltaY, DeltaZ, Light, Vertices)
	local VerticesLength = #Vertices
	local VisibleEdge = {}

	local Lx, Ly, Lz = Light:GetPosition()
	local Bx, By, Bz = Body:GetPosition()

	Lx = Lx + DeltaX
	Ly = Ly + DeltaY
	Lz = Lz + DeltaZ

	for Index = 1, VerticesLength, 2 do
		local NextIndex = Index + 2

		if NextIndex > VerticesLength then
			NextIndex = NextIndex - VerticesLength
		end

		local Normal = Normalize {

			Vertices[Index + 1] - Vertices[NextIndex + 1],
			Vertices[NextIndex] - Vertices[Index],

		}

		local Direction = Normalize {

			Vertices[Index] - Lx,
			Vertices[Index + 1] - Ly,

		}

		insert(VisibleEdge, (Normal[1] * Direction[1] + Normal[2] * Direction[2]) > 0)
	end

	local VisibleEdges = #VisibleEdge
	local Geometry = {}

	if Shadows.PointInPolygon(Lx, Ly, Vertices) then
		if Lz > Bz then
			for i = 1, VerticesLength, 2 do
				local Vertex = {

					Vertices[i],
					Vertices[i + 1],

				}

				local dx = Lx - Vertex[1]
				local dy = Ly - Vertex[2]
				local Length = 1 / atan2(Lz / Bz, sqrt(dx * dx + dy * dy))

				local Direction = Normalize {

					Vertex[1] - Lx,
					Vertex[2] - Ly,

				}

				insert(Geometry, Vertex[1] + Direction[1] * Length)
				insert(Geometry, Vertex[2] + Direction[2] * Length)
			end

			insert(Shapes, OutputShadow:new("polygon", "fill", unpack(Geometry)))
		end
	else
		local FirstVertex

		for Index = 1, VisibleEdges do
			local PrevIndex = Index - 1

			if PrevIndex <= 0 then
				PrevIndex = VisibleEdges + PrevIndex
			end

			if not VisibleEdge[PrevIndex] and VisibleEdge[Index] then
				FirstVertex = Index

				local Vertex = {
					Vertices[Index * 2 - 1],
					Vertices[Index * 2],
				}

				local Length = Light:GetRadius() * self.Radius

				if Lz > Bz then
					local dx = Lx - Vertex[1]
					local dy = Ly - Vertex[2]

					Length = 1 / atan2(Lz / Bz, sqrt(dx * dx + dy * dy))
				end

				local Direction = Normalize {

					Vertex[1] - Lx,
					Vertex[2] - Ly,

				}

				insert(Geometry, Vertex[1] + Direction[1] * Length)
				insert(Geometry, Vertex[2] + Direction[2] * Length)

				insert(Geometry, Vertex[1])
				insert(Geometry, Vertex[2])

				break
			end
		end

		if FirstVertex then
			-- Follow the near silhouette in boundary order; reversing it below the caster crosses edges.
			local StepDirection = Lz > Bz and -1 or 1
			for Step = 1, VisibleEdges - 1 do
				local Index = (FirstVertex - 1 + Step * StepDirection) % VisibleEdges + 1
				local PrevIndex = (Index - 2) % VisibleEdges + 1

				if (Lz > Bz and not VisibleEdge[Index] and not VisibleEdge[PrevIndex]) or (Lz <= Bz and VisibleEdge[Index] and VisibleEdge[PrevIndex]) then
					insert(Geometry, Vertices[Index * 2 - 1])
					insert(Geometry, Vertices[Index * 2])
				end
			end
		end

		local LastVertex

		for Index = 1, VisibleEdges do
			local PrevIndex = Index - 1

			if PrevIndex <= 0 then
				PrevIndex = VisibleEdges + PrevIndex
			end

			if not VisibleEdge[Index] and VisibleEdge[PrevIndex] then
				LastVertex = Index

				local Vertex = {

					Vertices[Index * 2 - 1],
					Vertices[Index * 2],

				}

				local Length = Light:GetRadius() * self.Radius

				if Lz > Bz then
					local dx = Lx - Vertex[1]
					local dy = Ly - Vertex[2]

					Length = 1 / atan2(Lz / Bz, sqrt(dx * dx + dy * dy))
				end

				local Direction = Normalize {

					Vertex[1] - Lx,
					Vertex[2] - Ly,

				}

				insert(Geometry, Vertex[1])
				insert(Geometry, Vertex[2])

				insert(Geometry, Vertex[1] + Direction[1] * Length)
				insert(Geometry, Vertex[2] + Direction[2] * Length)

				break
			end
		end

		if LastVertex then
			for Index = LastVertex, VisibleEdges do
				local PrevIndex = Index - 1

				if PrevIndex <= 0 then
					PrevIndex = VisibleEdges + PrevIndex
				end

				if not VisibleEdge[Index] and not VisibleEdge[PrevIndex] then
					local Vertex = {

						Vertices[Index * 2 - 1],
						Vertices[Index * 2],

					}

					local Length = Light:GetRadius() * self.Radius

					if Lz > Bz then
						local dx = Lx - Vertex[1]
						local dy = Ly - Vertex[2]

						Length = 1 / atan2(Lz / Bz, sqrt(dx * dx + dy * dy))
					end

					local Direction = Normalize {

						Vertex[1] - Lx,
						Vertex[2] - Ly,

					}

					insert(Geometry, Vertex[1] + Direction[1] * Length)
					insert(Geometry, Vertex[2] + Direction[2] * Length)
				end
			end

			for Index = 1, LastVertex do
				local PrevIndex = Index - 1

				if PrevIndex <= 0 then
					PrevIndex = VisibleEdges + PrevIndex
				end

				if not VisibleEdge[Index] and not VisibleEdge[PrevIndex] then
					local Vertex = {

						Vertices[Index * 2 - 1],
						Vertices[Index * 2],

					}

					local Length = Light:GetRadius() * self.Radius

					if Lz > Bz then
						local dx = Lx - Vertex[1]
						local dy = Ly - Vertex[2]

						Length = 1 / atan2(Lz / Bz, sqrt(dx * dx + dy * dy))
					end

					local Direction = Normalize {

						Vertex[1] - Lx,
						Vertex[2] - Ly,

					}

					insert(Geometry, Vertex[1] + Direction[1] * Length)
					insert(Geometry, Vertex[2] + Direction[2] * Length)
				end
			end
		end

		if #Geometry > 0 then
			-- Triangulation is necessary, otherwise rays will be intersecting
			local Triangles = love.math.triangulate(Geometry)
			for i = 1, #Triangles do
				insert(Shapes, OutputShadow:new("polygon", "fill", unpack(Triangles[i])))
			end
		end
	end
end

---@description Appends a convex silhouette or the union of a concave polygon's projected triangles.
---@param Shapes table Destination list of OutputShadow objects.
---@param Body Body Owning body.
---@param DeltaX number X offset from the light canvas origin.
---@param DeltaY number Y offset from the light canvas origin.
---@param DeltaZ number Height offset from the light canvas origin.
---@param Light Light Light or star producing the shadow.
---@return nil
function PolygonShadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	if self.Convex then
		GenerateConvexShadows(self, Shapes, Body, DeltaX, DeltaY, DeltaZ, Light, self:GetVertices())
	else
		for _, Triangle in ipairs(self.Triangles) do
			GenerateConvexShadows(self, Shapes, Body, DeltaX, DeltaY, DeltaZ, Light,
				self.CentroidTransform:ToWorldPoints(Triangle))
		end
	end
end

return PolygonShadow
