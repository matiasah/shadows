module("shadows.ShadowShapes.ImageShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")
OutputShadow = require("shadows.OutputShadow")

Shadow = require("shadows.ShadowShapes.Shadow")

ImageShadow = setmetatable( {}, Shadow )
ImageShadow.__index = ImageShadow
ImageShadow.__type = "ImageShadow"
ImageShadow.__lt = Shadow.__lt
ImageShadow.__le = Shadow.__le

local insert = Shadows.Insert

function ImageShadow:new(Body, Texture, Width, Height)
	
	if Body and Texture then
		
		local self = setmetatable( {}, ImageShadow )
		
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

function ImageShadow:SetTexture(Texture)
	
	self.Texture = Texture
	self.Changed = true
	
end

function ImageShadow:GetTexture()
	
	return self.Texture
	
end

function ImageShadow:GetWidth()
	
	return self.Width or self.Texture:getWidth()
	
end

function ImageShadow:GetHeight()
	
	return self.Height or self.Texture:getHeight()
	
end

function ImageShadow:GetSqrRadius()
	
	local Width = self:GetWidth()
	local Height = self:GetHeight()
	
	return Width * Width + Height * Height
	
end

function ImageShadow:GenerateShadows(Shapes, Body, DeltaX, DeltaY, DeltaZ, Light)
	
	local Lx, Ly, Lz = Light:GetPosition()
	
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
		
		insert(Shapes, OutputShadow:new(nil, nil, unpack(Shape)))
		
	end
	
end

return ImageShadow