--- Implements a normal-map occluder used to shade light projected onto a body.
module("shadows.ShadowShapes.NormalShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")
OutputShadow = require("shadows.OutputShadow")

Shadow = require("shadows.ShadowShapes.Shadow")

--- @class NormalShadow: Shadow
--- @field Texture love.Texture Normal map texture.
--- @field Width number? Optional rendered width; defaults to texture width.
--- @field Height number? Optional rendered height; defaults to texture height.
--- @field Body Body Owning body.
--- @field Transform Transform Shape transform relative to its body.
NormalShadow = setmetatable({}, Shadow)
NormalShadow.__index = NormalShadow
NormalShadow.__type = "NormalShadow"
NormalShadow.__lt = Shadow.__lt
NormalShadow.__le = Shadow.__le

local insert = Shadows.Insert

--- @description Creates a normal-map shadow and attaches it to a body.
--- @param Body Body? Owning body.
--- @param Texture love.Texture? Normal map texture.
--- @param Width number? Rendered width; defaults to texture width.
--- @param Height number? Rendered height; defaults to texture height.
--- @return NormalShadow? shape New shape, or nil when required arguments are omitted.
function NormalShadow:new(Body, Texture, Width, Height)
	if Body and Texture then
		local self = setmetatable({}, NormalShadow)

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

--- @description Replaces the normal map texture.
--- @param Texture love.Texture New normal map.
--- @return nil
function NormalShadow:SetTexture(Texture)
	self.Texture = Texture
end

--- @description Returns the normal map texture.
--- @return love.Texture texture Normal map.
function NormalShadow:GetTexture()
	return self.Texture
end

--- @description Returns the explicit width or texture's intrinsic width.
--- @return number width Rendered width.
function NormalShadow:GetWidth()
	return self.Width or self.Texture:getWidth()
end

--- @description Returns the explicit height or texture's intrinsic height.
--- @return number height Rendered height.
function NormalShadow:GetHeight()
	return self.Height or self.Texture:getHeight()
end

--- @description Returns the squared diagonal of the normal-map bounds.
--- @return number radiusSquared Squared bounding radius.
function NormalShadow:GetSqrRadius()
	local Width = self:GetWidth()
	local Height = self:GetHeight()

	return Width * Width + Height * Height
end

--- @description Appends the normal-map shading draw call for this shape.
--- @param Shapes table Destination list of OutputShadow objects.
--- @param Body Body Owning body.
--- @param DeltaX number X offset from the light canvas origin.
--- @param DeltaY number Y offset from the light canvas origin.
--- @param DeltaZ number Height offset from the light canvas origin.
--- @param Light Light Light or star producing the shadow.
--- @return nil
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
		Output:SendShader("DpiScale", require("shadows.DPI").getCanvasScale(Light.ShadowCanvas))
		Output:SendShader("LightPos", { Lx, Ly, Lz })
		Output:SetLayer(z)

		insert(Shapes, Output)
	else
		-- Make sure the light doesn't cover the normal map
		local wx, wy = self.Transform:ToWorld(self:GetWidth(), self:GetHeight())

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
