module("shadows.ShadowShapes.PolygonShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")

PolygonShadow = {}
PolygonShadow.__index = PolygonShadow

local Normalize = Shadows.Normalize
local insert = table.insert

local atan2 = math.atan2
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local rad = math.rad

function PolygonShadow:new(Body, ...)
	
	local Vertices = {...}
	local self = setmetatable({}, PolygonShadow)
	
	if Body and Vertices and #Vertices > 0 then
	
		self.Transform = Transform:new()
		self.Transform:SetParent(Body:GetTransform())
		self.Transform.Object = self
		
		self.Body = Body
		self.World = Body.World
		self:SetVertices(...)
		
		Body:AddShape(self)
		
	end
	
	return self
	
end

function PolygonShadow:Update()
	
	if self.Transform.HasChanged then
		
		self.Body:GetTransform().HasChanged = true
		
	end
	
end

function PolygonShadow:Remove()
	
	if self.Body then
		
		self.Body.Shapes[self.ID] = nil
		self.Body.World.Changed = true
		self.Body = nil
		self.ID = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function PolygonShadow:Draw()
	
	love.graphics.polygon("fill", self:GetVertices() )
	
end

function PolygonShadow:GetPosition()
	
	return self.Body:GetPosition()
	
end

function PolygonShadow:GetRadius()
	
	return self.Radius
	
end

function PolygonShadow:GetSqrRadius()
	
	return self.SqrRadius
	
end

function PolygonShadow:SetVertices(...)
	
	self.Vertices = {...}
	self.Radius = 0
	self.SqrRadius = 0
	self.World.Changed = true
	
	for i = 1, #self.Vertices, 2 do
		
		local x, y = self.Vertices[i], self.Vertices[i + 1]
		local SqrRadius = x * x + y * y
		local Radius = sqrt( SqrRadius )
		
		if Radius > self.Radius then
			
			self.Radius = Radius
			self.SqrRadius = SqrRadius
			
		end
		
	end
	
end

function PolygonShadow:GetVertices()
	
	return self.Transform:ToWorldPoints( self.Vertices )
	
end

function PolygonShadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	
	local Vertices = self:GetVertices()
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

	local PenumbraAngle = math.atan(Light.SizeRadius / Light.Radius)
	local VisibleEdges = #VisibleEdge
	local Geometry = {}
	
	if Shadows.PointInPolygon(Lx, Ly, Vertices) then
		
		if Lz > Bz then
			
			Geometry.type = "polygon"
			
			insert(Geometry, "fill")
			
			for i = 1, #Vertices, 2 do
				
				local Vertex = {
					
					Vertices[i],
					Vertices[i + 1],
					
				}
				
				local dx = Lx - Vertex[1]
				local dy = Ly - Vertex[2]
				local Length = 1 / atan2( Lz / Bz, sqrt( dx * dx + dy * dy ) )
				
				local Direction = Normalize {
					
					Vertex[1] - Lx,
					Vertex[2] - Ly,
					
				}
				
				insert(Geometry, Vertex[1] + Direction[1] * Length)
				insert(Geometry, Vertex[2] + Direction[2] * Length)
				
			end
			
			insert(Shapes, Geometry)
			
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
					Vertices[Index * 2 - 1];
					Vertices[Index * 2];
				}
				
				local Length = Light.Radius
				
				if Lz > Bz then
					
					local dx = Lx - Vertex[1]
					local dy = Ly - Vertex[2]
					
					Length = 1 / atan2( Lz / Bz, sqrt( dx * dx + dy * dy ) )
					
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
			
			for Index = FirstVertex, 1, -1 do
				
				local PrevIndex = Index - 1
				
				if PrevIndex <= 0 then
					
					PrevIndex = VisibleEdges + PrevIndex
					
				end
				
				if not VisibleEdge[Index] and not VisibleEdge[PrevIndex] then
					
					insert(Geometry, Vertices[Index * 2 - 1])
					insert(Geometry, Vertices[Index * 2])
					
				end
				
			end
			
			for Index = VisibleEdges, FirstVertex, -1 do
				
				local PrevIndex = Index - 1
				
				if PrevIndex <= 0 then
					
					PrevIndex = VisibleEdges + PrevIndex
					
				end
				
				if not VisibleEdge[Index] and not VisibleEdge[PrevIndex] then
					
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
				
				local Length = Light.Radius
				
				if Lz > Bz then
					
					local dx = Lx - Vertex[1]
					local dy = Ly - Vertex[2]
					
					Length = 1 / atan2( Lz / Bz, sqrt( dx * dx + dy * dy ) )
					
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
					
					local Length = Light.Radius
					
					if Lz > Bz then
						
						local dx = Lx - Vertex[1]
						local dy = Ly - Vertex[2]
						
						Length = 1 / atan2( Lz / Bz, sqrt( dx * dx + dy * dy ) )
						
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
					
					local Length = Light.Radius
					
					if Lz > Bz then
						
						local dx = Lx - Vertex[1]
						local dy = Ly - Vertex[2]
						
						Length = 1 / atan2( Lz / Bz, sqrt( dx * dx + dy * dy ) )
						
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
			
			for _, Shadow in pairs(Triangles) do
				
				Shadow.type = "polygon"
				insert(Shadow, 1, "fill")
				insert(Shapes, Shadow)
				
			end
			
		end
		
	end
	
end

return PolygonShadow