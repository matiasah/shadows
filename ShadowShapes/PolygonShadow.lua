module("shadows.ShadowShapes.PolygonShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")
OutputShadow = require("shadows.OutputShadow")

Shadow = require("shadows.ShadowShapes.Shadow")

PolygonShadow = setmetatable( {}, Shadow )
PolygonShadow.__index = PolygonShadow
PolygonShadow.__type = "PolygonShadow"
PolygonShadow.__lt = Shadow.__lt
PolygonShadow.__le = Shadow.__le

local Normalize = Shadows.Normalize
local insert = Shadows.Insert

local atan2 = math.atan2
local sqrt = math.sqrt

function PolygonShadow:new(Body, ...)
	
	local Vertices = {...}
	
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

function PolygonShadow:Draw(Lz)
	
	local x, y, z = self.Transform:GetPosition()
	
	if Lz > z then
		
		love.graphics.polygon("fill", self:GetVertices() )
		
	end
	
end

function PolygonShadow:GetRadius()
	
	return self.Radius
	
end

function PolygonShadow:GetSqrRadius()
	
	return self.SqrRadius
	
end

function PolygonShadow:GetCentroid()
	
	return self.CentroidTransform:GetPosition()
	
end

function PolygonShadow:SetVertices(...)
	
	local Vertices = {...}
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
	self.World.Changed = true
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
	
	self.Radius = sqrt( self.SqrRadius )
	
end

function PolygonShadow:GetVertices()
	
	return self.CentroidTransform:ToWorldPoints( self.Vertices )
	
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
				local Length = 1 / atan2( Lz / Bz, sqrt( dx * dx + dy * dy ) )
				
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
					Vertices[Index * 2 - 1];
					Vertices[Index * 2];
				}
				
				local Length = Light:GetRadius() * self.Radius
				
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
				
				if ( Lz > Bz and not VisibleEdge[Index] and not VisibleEdge[PrevIndex] ) or ( Lz <= Bz and VisibleEdge[Index] and VisibleEdge[PrevIndex] ) then
					
					insert(Geometry, Vertices[Index * 2 - 1])
					insert(Geometry, Vertices[Index * 2])
					
				end
				
			end
			
			for Index = VisibleEdges, FirstVertex, -1 do
				
				local PrevIndex = Index - 1
				
				if PrevIndex <= 0 then
					
					PrevIndex = VisibleEdges + PrevIndex
					
				end
				
				if ( Lz > Bz and not VisibleEdge[Index] and not VisibleEdge[PrevIndex] ) or ( Lz <= Bz and VisibleEdge[Index] and VisibleEdge[PrevIndex] ) then
					
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
					
					local Length = Light:GetRadius() * self.Radius
					
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
					
					local Length = Light:GetRadius() * self.Radius
					
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
			local Ok, Triangles = pcall(love.math.triangulate, Geometry)
			
			if Ok then
				
				for i = 1, #Triangles do
					
					insert(Shapes, OutputShadow:new("polygon", "fill", unpack(Triangles[i])))
					
				end
				
			end
			
		end
		
	end
	
end

return PolygonShadow