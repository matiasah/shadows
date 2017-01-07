local Shadows = ...
local Polygon = debug.getregistry()["PolygonShape"]

local Normalize = Shadows.Normalize
local insert = table.insert

local atan2 = math.atan2
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin
local rad = math.rad

function Polygon:Draw(Body)
	
	love.graphics.polygon("fill", Body.Body:getWorldPoints( self:getPoints() ) )
end

function Polygon:GetPosition(Body)
	
	local Points = { self:getPoints() }
	local x, y = 0, 0
	
	for i = 1, #Points, 2 do
		
		x = x + Points[i]
		y = y + Points[i + 1]
		
	end
	
	local InvCount = 1 / #Points * 0.5
	local WorldX, WorldY = Body.Body:getWorldPoint( x * InvCount, y * InvCount )
	
	return WorldX, WorldY, Points
	
end

function Polygon:GetRadius(Body)
	
	local x, y, Points = self:GetPosition(Body)
	local Radius = 0
	
	for i = 1, #Points, 2 do
		
		local dx = Points[i] - x
		local dy = Points[i + 1] - y
		local PointRadius = sqrt( dx * dx + dy * dy )
		
		if PointRadius > Radius then
			
			Radius = PointRadius
			
		end
		
	end
	
	return Radius
	
end

function Polygon:GetVertices(Body)
	
	return {
		
		Body.Body:getWorldPoints( self:getPoints() )
		
	}
	
end

function Polygon:GenerateShadows(Shapes, Body, DeltaX, DeltaY, Light)
	
	local Vertices = self:GetVertices(Body)
	local VerticesLength = #Vertices
	local VisibleEdge = {}
	
	local Lx, Ly, Lz = Light:GetPosition()
	local Bx, By, Bz = Body:GetPosition()
	
	Lx = Lx + DeltaX
	Ly = Ly + DeltaY
	
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
			
			if Lz > Bz then
				
				local dx = Lx - Vertex[1]
				local dy = Ly - Vertex[2]
				
				Length = Bz / atan2( Lz, sqrt( dx * dx + dy * dy ) )
				
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
				
				Length = Bz / atan2( Lz, sqrt( dx * dx + dy * dy ) )
				
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
					
					Length = Bz / atan2( Lz, sqrt( dx * dx + dy * dy ) )
					
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
					
					Length = Bz / atan2( Lz, sqrt( dx * dx + dy * dy ) )
					
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