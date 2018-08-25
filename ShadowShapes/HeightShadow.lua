-- If you're thinking on using height maps, normal map is more efficient in some cases
module("shadows.ShadowShapes.HeightShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")
OutputShadow = require("shadows.OutputShadow")

Shadow = require("shadows.ShadowShapes.Shadow")

HeightShadow = setmetatable( {}, Shadow )
HeightShadow.__index = HeightShadow
HeightShadow.__type = "HeightShadow"
HeightShadow.__lt = Shadow.__lt
HeightShadow.__le = Shadow.__le

local Normalize = Shadows.Normalize
local insert = Shadows.Insert

local atan2 = math.atan2
local sqrt = math.sqrt

function HeightShadow:new(Body, Texture)
	
	if Body and Texture then
		
		local self = setmetatable( {}, HeightShadow )
		
		self.Texture = Texture
		
		self.Transform = Transform:new()
		self.Transform:SetParent(Body:GetTransform())
		self.Transform.Object = self
		self.Body = Body
		
		Body:AddShape(self)
		
		return self
		
	end
	
end

function HeightShadow:SetTexture(Texture)
	
	self.Texture = Texture
	self.Changed = true
	
end

function HeightShadow:GetTexture()
	
	return self.Texture
	
end

function HeightShadow:GetWidth()
	
	return self.Texture:getWidth()
	
end

function HeightShadow:GetHeight()
	
	return self.Texture:getHeight()
	
end

function HeightShadow:GetSqrRadius()
	
	local Width = self:GetWidth()
	local Height = self:GetHeight()
	
	return Width * Width + Height * Height
	
end

function HeightShadow:GetVertices()
	
	local x, y = self.Transform:GetPosition()
	local wx, wy = self.Transform:ToWorld(self:GetWidth(), self:GetHeight())
	
	return {x, y, wx, y, wx, wy, x, wy}
	
end

function HeightShadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	
	local Vertices = self:GetVertices()
	local VerticesLength = #Vertices
	local VisibleEdge = {}
	
	local Lx, Ly, Lz = Light:GetPosition()
	
	Lx = Lx + DeltaX
	Ly = Ly + DeltaY
	Lz = Lz + DeltaZ
	
	local x, y, z = self.Transform:GetPosition()
	local Bx, By, Bz = x, y, z
	
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
			
			local Output = OutputShadow:new("polygon", "fill")
			Output:Pack(Geometry)
			Output:SetLayer(z)
			Output:SetShader(Shadows.HeightShader)
			Output:SendShader("LightPos", { Lx, Ly, Lz } )
			Output:SendShader("LightCenter", { Light:GetCanvasCenter() } )
			Output:SendShader("MapPos", { x, y, z } )
			Output:SendShader("Size", { self.Texture:getWidth(), self.Texture:getHeight() } )
			Output:SendShader("Texture", self.Texture)
			
			insert(Shapes, Output)
			
		else
			
			local Output = OutputShadow:new("polygon", "fill")
			
			Output:Pack(Vertices)
			
			insert(Shapes, Output)
			
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
				
				if VisibleEdge[Index] and VisibleEdge[PrevIndex] then
					
					insert(Geometry, Vertices[Index * 2 - 1])
					insert(Geometry, Vertices[Index * 2])
					
				end
				
			end
			
			for Index = VisibleEdges, FirstVertex, -1 do
				
				local PrevIndex = Index - 1
				
				if PrevIndex <= 0 then
					
					PrevIndex = VisibleEdges + PrevIndex
					
				end
				
				if VisibleEdge[Index] and VisibleEdge[PrevIndex] then
					
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
			
			local Output = OutputShadow:new("polygon", "fill")
			Output:Pack(Geometry)
			Output:SetLayer(z)			-- Make a alternative output shadow if layer doesn't match
			Output:SetShader(Shadows.HeightShader)
			Output:SendShader("LightPos", { Lx, Ly, Lz } )
			Output:SendShader("LightCenter", { Light:GetCanvasCenter() } )
			Output:SendShader("MapPos", { x, y, z } )
			Output:SendShader("Size", { self.Texture:getWidth(), self.Texture:getHeight() } )
			Output:SendShader("Texture", self.Texture)
			
			insert(Shapes, Output)
			
		end
		
	end
	
end

return HeightShadow