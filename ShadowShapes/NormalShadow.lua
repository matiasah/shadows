module("shadows.ShadowShapes.NormalShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")
OutputShadow = require("shadows.OutputShadow")

Shadow = require("shadows.ShadowShapes.Shadow")

NormalShadow = setmetatable( {}, Shadow )
NormalShadow.__index = NormalShadow
NormalShadow.__type = "NormalShadow"
NormalShadow.__lt = Shadow.__lt
NormalShadow.__le = Shadow.__le

local insert = Shadows.Insert

function NormalShadow:new(Body, Texture, Width, Height)
	
	if Body and Texture then
		
		local self = setmetatable( {}, NormalShadow )
		
		self.Texture = Texture
		self.Width = Width
		self.Height = Height
		
		self.Transform = Transform:new()
		self.Transform:SetParent(Body:GetTransform())
		self.Transform.Object = self
		self.Body = Body
		
		Body:AddShape(self)
		
		return self
		
	end
	
end

function NormalShadow:SetTexture(Texture)
	
	self.Texture = Texture
	
end

function NormalShadow:GetTexture()
	
	return self.Texture
	
end

function NormalShadow:GetWidth()
	
	return self.Width or self.Texture:getWidth()
	
end

function NormalShadow:GetHeight()
	
	return self.Height or self.Texture:getHeight()
	
end

function NormalShadow:GetSqrRadius()
	
	local Width = self:GetWidth()
	local Height = self:GetHeight()
	
	return Width * Width + Height * Height
	
end

function NormalShadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	
	local Lx, Ly, Lz = Light:GetCanvasCenter()
	
	Lx = Lx + DeltaX
	Ly = Ly + DeltaY
	Lz = Lz + DeltaZ
	
	local x, y, z = self.Transform:GetPosition()
	local Rotation = self.Transform:GetRadians()
	
	if Lz > z then
		
		local Shape = {
			
			self.Texture,
			x,
			y,
			Rotation,
			self:GetWidth() / self.Texture:getWidth(),
			self:GetHeight() / self.Texture:getHeight(),
			
		}
		
		local Output = OutputShadow:new()
		Output:Pack(unpack(Shape))
		Output:SetShader(Shadows.NormalShader)
		Output:SendShader("LightPos", { Lx, Ly, Lz })
		Output:SetLayer(z)
		
		insert(Shapes, Output)
		
	else
		-- Make sure the light doesn't cover the normal map
		local wx, wy = self.Transform:ToWorld( self:GetWidth(), self:GetHeight() )
		
		local Shape = {
			
			x, y,
			wx, y,
			wx, wy,
			x, wy
			
		}
		
		local Output = OutputShadow:new("polygon", "fill")
		Output:Pack(Shape)
		
		insert(Shapes, Output)
		
	end
	
end

return NormalShadow