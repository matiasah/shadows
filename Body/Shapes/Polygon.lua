local Shadows = ...
local Polygon = {}

local Normalize = Shadows.Normalize
local insert = table.insert

local atan2 = math.atan2
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local rad = math.rad

Polygon.__index = Polygon
Polygon.Angle = 0

function Shadows.CreatePolygon(Body, ...)
	local Polygon = setmetatable({}, Polygon)
	
	Polygon.Body = Body
	Polygon:SetVertices(...)
	
	Body:AddShape(Polygon)
	
	return Polygon
end

function Polygon:Remove()
	
	self.Body.Shapes[self.ID] = nil
	
end

function Polygon:Draw()
	
	love.graphics.polygon("fill", unpack( self:GetVertices() ) )
	
end

function Polygon:GetPosition()
	
	return self.Body:GetPosition()
	
end

function Polygon:GetRadius()
	
	return self.Radius
	
end

function Polygon:SetVertices(...)
	
	self.Vertices = {...}
	self.Radius = 0
	
	for i = 1, #self.Vertices, 2 do
		
		local x, y = self.Vertices[i], self.Vertices[i + 1]
		local Radius = sqrt( x * x + y * y )
		
		if Radius > self.Radius then
			
			self.Radius = Radius
			
		end
		
	end
	
end

function Polygon:GetVertices()
	
	local Vertices = {}
	
	for i = 1, #self.Vertices, 2 do
		
		local x, y = self.Vertices[i], self.Vertices[i + 1]
		local Length = sqrt(x * x + y * y)
		local Heading = atan2(y, x) + rad(self.Body.Angle)
		
		insert(Vertices, self.Body.x + cos(Heading) * Length)
		insert(Vertices, self.Body.y + sin(Heading) * Length)
		
	end
	
	return Vertices
	
end

function Polygon:GenerateShadows(Shapes, Body, DeltaX, DeltaY, Light)
	
	local Vertices = self:GetVertices()
	local VerticesLength = #Vertices
	local VisibleEdge = {}
	
	local Lx = Light.x + DeltaX
	local Ly = Light.y + DeltaY
	
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
	local Geometry = {type = "polygon"}
	
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
			
			if Light.z > Body.z then
				
				local dx = Lx - Vertex[1]
				local dy = Ly - Vertex[2]
				
				Length = Body.z / atan2( Light.z, sqrt( dx * dx + dy * dy ) )
				
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
			
			if Light.z > Body.z then
				
				local dx = Lx - Vertex[1]
				local dy = Ly - Vertex[2]
				
				Length = Body.z / atan2( Light.z, sqrt( dx * dx + dy * dy ) )
				
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
				
				if Light.z > Body.z then
					
					local dx = Lx - Vertex[1]
					local dy = Ly - Vertex[2]
					
					Length = Body.z / atan2( Light.z, sqrt( dx * dx + dy * dy ) )
					
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
				
				if Light.z > Body.z then
					
					local dx = Lx - Vertex[1]
					local dy = Ly - Vertex[2]
					
					Length = Body.z / atan2( Light.z, sqrt( dx * dx + dy * dy ) )
					
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
			insert(Shapes, Shadow)
			
		end
		
	end
	
end