local Shadows = ...
local Polygon = debug.getregistry()["PolygonShape"]

function Polygon:Draw(Body)
	love.graphics.polygon("fill", Body.Body:getWorldPoints(self:getPoints()))
end

function Polygon:GetPosition(Body)
	return Body.Body:getPosition()
end

function Polygon:GetRadius()
	return self:getRadius()
end

function Polygon:GetVertices(Body)
	return {Body.Body:getWorldPoints(self:getPoints())}
end

function Polygon:GenerateShadows(Body, Light)
	local Shapes = {}
	
	local Vertices = self:GetVertices(Body)
	local VerticesLength = #Vertices
	local VisibleEdge = {}
	
	for Index = 1, VerticesLength, 2 do
		local NextIndex = Index + 2
		if NextIndex > VerticesLength then
			NextIndex = NextIndex - VerticesLength
		end

		local Normal = Shadows.Normalize {
			Vertices[Index + 1] - Vertices[NextIndex + 1];
			Vertices[NextIndex] - Vertices[Index];
		}
		
		local Direction = Shadows.Normalize {
			Vertices[Index] - Light.x;
			Vertices[Index + 1] - Light.y;
		}
		
		table.insert(VisibleEdge, (Normal[1] * Direction[1] + Normal[2] * Direction[2]) > 0)
	end

	local VisibleEdges = #VisibleEdge
	local Geometry = {}
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
			
			local Length = Shadows.MaxLength
			if Light.z and Light.z > Body.z then
				Length = Body.z / math.atan2(Light.z, math.sqrt((Light.x - Vertex[1])^2 + (Light.y - Vertex[2])^2))
			end
			
			local Direction = Shadows.Normalize {
				Vertex[1] - Light.x;
				Vertex[2] - Light.y;
			}
			table.insert(Geometry, Vertex[1] + Direction[1] * Length)
			table.insert(Geometry, Vertex[2] + Direction[2] * Length)
			
			table.insert(Geometry, Vertex[1])
			table.insert(Geometry, Vertex[2])
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
				table.insert(Geometry, Vertices[Index * 2 - 1])
				table.insert(Geometry, Vertices[Index * 2])
			end
		end
		
		for Index = VisibleEdges, FirstVertex, -1 do
			local PrevIndex = Index - 1
			if PrevIndex <= 0 then
				PrevIndex = VisibleEdges + PrevIndex
			end
			
			if not VisibleEdge[Index] and not VisibleEdge[PrevIndex] then
				table.insert(Geometry, Vertices[Index * 2 - 1])
				table.insert(Geometry, Vertices[Index * 2])
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
				Vertices[Index * 2 - 1];
				Vertices[Index * 2];
			}
			
			table.insert(Geometry, Vertex[1])
			table.insert(Geometry, Vertex[2])
			
			local Length = Shadows.MaxLength
			if Light.z and Light.z > Body.z then
				Length = Body.z / math.atan2(Light.z, math.sqrt((Light.x - Vertex[1])^2 + (Light.y - Vertex[2])^2))
			end
			
			local Direction = Shadows.Normalize {
				Vertex[1] - Light.x;
				Vertex[2] - Light.y;
			}
			table.insert(Geometry, Vertex[1] + Direction[1] * Length)
			table.insert(Geometry, Vertex[2] + Direction[2] * Length)
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
					Vertices[Index * 2 - 1];
					Vertices[Index * 2];
				}
				
				local Length = Shadows.MaxLength
				if Light.z and Light.z > Body.z then
					Length = Body.z / math.atan2(Light.z, math.sqrt((Light.x - Vertex[1])^2 + (Light.y - Vertex[2])^2))
				end
				
				local Direction = Shadows.Normalize {
					Vertex[1] - Light.x;
					Vertex[2] - Light.y;
				}
				table.insert(Geometry, Vertex[1] + Direction[1] * Length)
				table.insert(Geometry, Vertex[2] + Direction[2] * Length)
			end
		end
		
		for Index = 1, LastVertex do
			local PrevIndex = Index - 1
			if PrevIndex <= 0 then
				PrevIndex = VisibleEdges + PrevIndex
			end
			
			if not VisibleEdge[Index] and not VisibleEdge[PrevIndex] then
				local Vertex = {
					Vertices[Index * 2 - 1];
					Vertices[Index * 2];
				}
				
				local Length = Shadows.MaxLength
				if Light.z and Light.z > Body.z then
					Length = Body.z / math.atan2(Light.z, math.sqrt((Light.x - Vertex[1])^2 + (Light.y - Vertex[2])^2))
				end
				
				local Direction = Shadows.Normalize {
					Vertex[1] - Light.x;
					Vertex[2] - Light.y;
				}
				table.insert(Geometry, Vertex[1] + Direction[1] * Length)
				table.insert(Geometry, Vertex[2] + Direction[2] * Length)
			end
		end
	end
	
	if #Geometry > 0 then
		-- Triangulation is necessary, otherwise rays will be intersecting
		local Triangles = love.math.triangulate(Geometry)
		for _, Shadow in pairs(Triangles) do
			Shadow.type = "polygon"
			table.insert(Shapes, Shadow)
		end
	end
	
	return Shapes
end