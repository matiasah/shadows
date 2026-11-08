--- Implements a textured shadow occluder that casts its image silhouette.
module("shadows.ShadowShapes.ImageShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")
OutputShadow = require("shadows.OutputShadow")

Shadow = require("shadows.ShadowShapes.Shadow")

--- @class ImageShadow: Shadow
--- @field Texture love.Texture Texture used to draw and cast the shadow.
--- @field Width number? Optional rendered width; defaults to the texture width.
--- @field Height number? Optional rendered height; defaults to the texture height.
--- @field Body Body Owning body.
--- @field Transform Transform Shape transform relative to its body.
ImageShadow = setmetatable({}, Shadow)
ImageShadow.__index = ImageShadow
ImageShadow.__type = "ImageShadow"
ImageShadow.__lt = Shadow.__lt
ImageShadow.__le = Shadow.__le

local insert = Shadows.Insert

--- @description Creates an image shadow and attaches it to a body.
--- @param Body Body? Owning body.
--- @param Texture love.Texture? Image or texture to draw.
--- @param Width number? Rendered width; defaults to the texture width.
--- @param Height number? Rendered height; defaults to the texture height.
--- @return ImageShadow? shape New shape, or nil when required arguments are omitted.
function ImageShadow:new(Body, Texture, Width, Height)
	if Body and Texture then
		local self = setmetatable({}, ImageShadow)

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

--- @description Replaces the texture and marks the shape changed.
--- @param Texture love.Texture New image or texture.
--- @return nil
function ImageShadow:SetTexture(Texture)
	self.Texture = Texture
	self.Changed = true
end

--- @description Returns the texture used by this shape.
--- @return love.Texture texture Image texture.
function ImageShadow:GetTexture()
	return self.Texture
end

--- @description Returns the explicit width or the texture's intrinsic width.
--- @return number width Rendered width.
function ImageShadow:GetWidth()
	return self.Width or self.Texture:getWidth()
end

--- @description Returns the explicit height or the texture's intrinsic height.
--- @return number height Rendered height.
function ImageShadow:GetHeight()
	return self.Height or self.Texture:getHeight()
end

--- @description Returns the squared diagonal of the image bounds.
--- @return number radiusSquared Squared bounding radius.
function ImageShadow:GetSqrRadius()
	local Width = self:GetWidth()
	local Height = self:GetHeight()

	return Width * Width + Height * Height
end

--- @description Appends the image draw call when the light lies above this shape.
--- @param Shapes table Destination list of OutputShadow objects.
--- @param Body Body Owning body.
--- @param DeltaX number X offset from the light canvas origin.
--- @param DeltaY number Y offset from the light canvas origin.
--- @param DeltaZ number Height offset from the light canvas origin.
--- @param Light Light Light or star producing the shadow.
--- @return nil
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
