module("shadows.PhysicsShapes.PolygonShape", package.seeall)

Shadows = require("shadows")
OutputShadow = require("shadows.OutputShadow")

PolygonShape = debug.getregistry()["PolygonShape"]

local Normalize = Shadows.Normalize
local insert = Shadows.Insert

local atan2 = math.atan2
local sqrt = math.sqrt

function PolygonShape:Draw(Body)
	
	love.graphics.polygon("fill", Body.Body:getWorldPoints( self:getPoints() ) )
	
end

function PolygonShape:GetPosition(Body)
	
	local Points = { self:getPoints() }
	local x, y = 0, 0
	-- Get average center
	for i = 1, #Points, 2 do
		
		x = x + Points[i]
		y = y + Points[i + 1]
		
	end
	
	local InvCount = 1 / #Points
	local WorldX, WorldY = Body.Body:getWorldPoint( x * InvCount, y * InvCount )
	local n1, n2, WorldZ = Body:GetPosition()
	
	return WorldX, WorldY, WorldZ, Points
	
end

function PolygonShape:GetRadius(Body)
	
	local x, y, z, Points = self:GetPosition(Body)
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
	
	--return self:getRadius() -- seems to be acting weird with this function
	
end

function PolygonShape:GetSqrRadius(Body)
	
	local x, y, z, Points = self:GetPosition(Body)
	local Radius = 0
	
	for i = 1, #Points, 2 do
		
		local dx = Points[i] - x
		local dy = Points[i + 1] - y
		local PointRadius = dx * dx + dy * dy
		
		if PointRadius > Radius then
			
			Radius = PointRadius
			
		end
		
	end
	
	return Radius
	
end

function PolygonShape:GetVertices(Body)
	
	return { Body.Body:getWorldPoints( self:getPoints() ) }
	
end

function PolygonShape:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	
	local Vertices = self:GetVertices(Body)
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
				
				-- Get the current vertex
				local x = Vertices[i]
				local y = Vertices[i + 1]
				
				-- Calculate distance
				local dx = Lx - x
				local dy = Ly - y
				local Length = 1 / atan2( Lz / Bz, sqrt( dx * dx + dy * dy ) )
				
				-- Normalize direction
				local Direction = Normalize {
					
					x - Lx,
					y - Ly,
					
				}
				
				-- Multiply direction by distance
				insert(Geometry, x + Direction[1] * Length)
				insert(Geometry, y + Direction[2] * Length)
				
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
				
				local x = Vertices[Index * 2 - 1]
				local y = Vertices[Index * 2]
				
				local Length = Light:GetRadius()
				
				if Lz > Bz then
					
					local dx = Lx - x
					local dy = Ly - y
					
					Length = 1 / atan2( Lz / Bz, sqrt( dx * dx + dy * dy ) )
					
				end
				
				local Direction = Normalize {
					
					x - Lx,
					y - Ly,
					
				}
				
				insert(Geometry, x + Direction[1] * Length)
				insert(Geometry, y + Direction[2] * Length)
				
				insert(Geometry, x)
				insert(Geometry, y)
				
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
				
				local Length = Light:GetRadius()
				
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
					
					local Length = Light:GetRadius()
					
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
					
					local Length = Light:GetRadius()
					
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

return PolygonShape