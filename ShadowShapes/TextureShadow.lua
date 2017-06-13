module("shadows.ShadowShapes.TextureShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")

TextureShadow = {}
TextureShadow.__index = TextureShadow

TextureShadow.NormalMap = false

function TextureShadow:new(Body, Image, Width, Height)
	
	local self = setmetatable( {}, TextureShadow )
	
	if Body and Image then
		
		self.Image = Image
		self.Width = Width
		self.Height = Height
		
		self.Transform = Transform:new()
		
		return self
		
	end
	
end

function TextureShadow:Update()
	
	if self.Transform.HasChanged then
		
		self.Body:GetTransform().HasChanged = true
		
	end
	
end

function TextureShadow:Remove()
	
	self.Body.Shapes[self.ID] = nil
	self.World.Changed = true
	
	self.Transform:SetParent(nil)
	
end

function TextureShadow:SetNormalMap(NormalMap)
	-- This method shall only receive booleans, if you want to set the normal map texture modify self.Image
	self.NormalMap = NormalMap
	
end

function TextureShadow:GetWidth()
	
	return self.Width or self.Image:getWidth()
	
end

function TextureShadow:GetHeight()
	
	return self.Height or self.Image:getHeight()
	
end

function TextureShadow:Draw()
	
	local HorizontalScale = self:GetWidth() / self.Image:getWidth()
	local VerticalScale = self:GetHeight() / self.Image:getHeight()
	
	local x, y = self.Transform:GetPosition()
	local Rotation = self.Transform:GetRadians()
	
	love.graphics.draw( self.Image, x, y, Rotation, HorizontalScale, VerticalScale )
	
end

function TextureShadow:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function TextureShadow:GetRadius()
	
	local Width = self:GetWidth()
	local Height = self:GetHeight()
	
	return math.sqrt( Width * Width + Height * Height )
	
end

function TextureShadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, Light)
	
	local Lx, Ly, Lz = Light:GetPosition()
	local Bx, By, Bz = Body:GetPosition()
	
	Lx = Lx + DeltaX
	Ly = Ly + DeltaY
	
	if Lz > Bz then
		
		local x1, y1 = self.Transform:GetPosition()
		local x2, y2 = self.Transform:ToWorld(self:GetWidth(), self:GetHeight())
		
		local Vertices = {
			x1, y1,
			x1, y2,
			x2, y2,
			x2, y1
		}
		
		for i = 1, #Vertices, 2 do
			
			local Vertex = {
				
				Vertices[i],
				Vertices[i + 1],
				
			}
			
			local dx = Lx - Vertex[1]
			local dy = Ly - Vertex[2]
			local Length = Bz / atan2( Lz, sqrt( dx * dx + dy * dy ) )
			
			local Direction = Normalize {
				
				Vertex[1] - Lx,
				Vertex[2] - Ly,
				
			}
			
			insert(Geometry, Vertex[1] + Direction[1] * Length)
			insert(Geometry, Vertex[2] + Direction[2] * Length)
			
		end
		
		insert(Shapes, Geometry)
		
	end
	
end

return TextureShadow