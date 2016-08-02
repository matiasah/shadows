local Shadows = ...
local Polygon = {}

Polygon.__index = Polygon
Polygon.Angle = 0

function Shadows.CreatePolygon(Body, ...)
	local Polygon = setmetatable({}, Polygon)
	
	Polygon.Body = Body
	Polygon.Vertices = {...}
	Polygon.Radius = 0
	
	for i = 1, #Polygon.Vertices, 2 do
		local Radius = math.sqrt(Polygon.Vertices[i]^2 + Polygon.Vertices[i + 1]^2)
		if Radius > Polygon.Radius then
			Polygon.Radius = Radius
		end
	end
	
	Body:AddShape(Polygon)
	
	return Polygon
end

function Polygon:Remove()
	self.Body.Shapes[self.ID] = nil
end

function Polygon:Draw()
	love.graphics.polygon("fill", unpack(self:GetVertices()))
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
		local Radius = math.sqrt(self.Vertices[i]^2 + self.Vertices[i + 1]^2)
		if Radius > self.Radius then
			self.Radius = Radius
		end
	end
end

function Polygon:GetVertices()
	local Vertices = {}
	for i = 1, #self.Vertices, 2 do
		local vx, vy = self.Vertices[i], self.Vertices[i + 1]
		local Length = math.sqrt(vx^2 + vy^2)
		local Heading = math.atan2(vy, vx)
		
		Heading = Heading + math.rad(self.Body.Angle)
		table.insert(Vertices, self.Body.x + math.cos(Heading) * Length)
		table.insert(Vertices, self.Body.y + math.sin(Heading) * Length)
	end
	return Vertices
end

function Polygon:GenerateShadows(Shapes, Body, Light)
	local Vertices = self:GetVertices()
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
			
			local Direction = Shadows.Normalize {
				Vertex[1] - Light.x;
				Vertex[2] - Light.y;
			}
			
			local Length = Light.Radius
			if Light.z <= Body.z then
				local Penumbra = {type = "arc"}
				Penumbra[1] = Vertex[1]
				Penumbra[2] = Vertex[2]
				Penumbra[3] = Length
				Penumbra[4] = math.atan2(Direction[2], Direction[1]) + PenumbraAngle
				Penumbra[5] = Penumbra[4] - PenumbraAngle
				
				Penumbra.Soft = true
				table.insert(Shapes, Penumbra)
			else
				Length = Body.z / math.atan2(Light.z, math.sqrt((Light.x - Vertex[1])^2 + (Light.y - Vertex[2])^2))
			end
			
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
			
			local Direction = Shadows.Normalize {
				Vertex[1] - Light.x;
				Vertex[2] - Light.y;
			}
			
			local Length = Light.Radius
			if Light.z <= Body.z then
				local Penumbra = {type = "arc"}
				Penumbra[1] = Vertex[1]
				Penumbra[2] = Vertex[2]
				Penumbra[3] = Length
				Penumbra[4] = math.atan2(Direction[2], Direction[1]) - PenumbraAngle
				Penumbra[5] = Penumbra[4] + PenumbraAngle
				
				Penumbra.Soft = true
				table.insert(Shapes, Penumbra)
			else
				Length = Body.z / math.atan2(Light.z, math.sqrt((Light.x - Vertex[1])^2 + (Light.y - Vertex[2])^2))
			end
			
			table.insert(Geometry, Vertex[1])
			table.insert(Geometry, Vertex[2])
			
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
				
				local Length = Light.Radius
				if Light.z > Body.z then
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
				
				local Length = Light.Radius
				if Light.z > Body.z then
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
end