module("shadows.ShadowShapes.HeightShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")

HeightShadow = {}
HeightShadow.__index = HeightShadow

local Normalize = Shadows.Normalize
local insert = table.insert

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

function HeightShadow:Update()
	
	if self.Transform.HasChanged then
		
		self.Body:GetTransform().HasChanged = true
		
	end
	
end

function HeightShadow:Remove()
	
	if self.Body then
		
		self.Body.Shapes[self.ID] = nil
		self.Body.World.Changed = true
		self.Body = nil
		self.ID = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function HeightShadow:SetTexture(Texture)
	
	self.Texture = Texture
	
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

function HeightShadow:Draw()
	
end

function HeightShadow:SetPosition(x, y)
	
	self.Transform:SetLocalPosition(x, y)
	
end

function HeightShadow:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function HeightShadow:GetRadius()
	
	local Width = self:GetWidth()
	local Height = self:GetHeight()
	
	return math.sqrt( Width * Width + Height * Height )
	
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
	
	Shadows.HeightShader:send("LightPos", { Lx, Ly, Lz } )
	Shadows.HeightShader:send("LightCenter", { Light:GetCanvasCenter() } )
	Shadows.HeightShader:send("LightSize", { Light.Canvas:getDimensions() } )
	Shadows.HeightShader:send("MapPos", { x, y, z })
	Shadows.HeightShader:send("Size", { self.Texture:getDimensions() } )
	Shadows.HeightShader:send("Texture", self.Texture)
	
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
			
			Geometry.shader = Shadows.HeightShader
			Geometry.IfNextLayerHigher = true
			Geometry.z = z
			
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
			
			Geometry.shader = Shadows.HeightShader
			Geometry.IfNextLayerHigher = true
			Geometry.z = z
			
			Geometry.type = "polygon"
			insert(Geometry, 1, "fill")
			
			insert(Shapes, Geometry)
			
		end
		
	end
	
end

return HeightShadow