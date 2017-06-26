module("shadows.ShadowShapes.NormalShadow", package.seeall)

Shadows = require("shadows")
Transform = require("shadows.Transform")

NormalShadow = {}
NormalShadow.__index = NormalShadow

NormalShadow.NormalMap = false

function NormalShadow:new(Body, Texture, Width, Height)
	
	local self = setmetatable( {}, NormalShadow )
	
	if Body and Texture then
		
		self.Texture = Texture
		self.Width = Width
		self.Height = Height
		
		self.Transform = Transform:new()
		self.Transform:SetParent(Body:GetTransform())
		self.Transform.Object = Body
		self.Body = Body
		
		Body:AddShape(self)
		
		return self
		
	end
	
end

function NormalShadow:Update()
	
	if self.Transform.HasChanged then
		
		self.Body:GetTransform().HasChanged = true
		
	end
	
end

function NormalShadow:Remove()
	
	if self.Body then
		
		self.Body.Shapes[self.ID] = nil
		self.Body.World.Changed = true
		self.Body = nil
		self.ID = nil
		
		self.Transform:SetParent(nil)
		
	end
	
end

function NormalShadow:SetTexture(Texture)
	
	self.Texture = Texture
	
end

function NormalShadow:GetWidth()
	
	return self.Width or self.Texture:getWidth()
	
end

function NormalShadow:GetHeight()
	
	return self.Height or self.Texture:getHeight()
	
end

function NormalShadow:Draw()
	
end

function NormalShadow:SetPosition(x, y)
	
	self.Transform:SetLocalPosition(x, y)
	
end

function NormalShadow:GetPosition()
	
	return self.Transform:GetPosition()
	
end

function NormalShadow:GetRadius()
	
	local Width = self:GetWidth()
	local Height = self:GetHeight()
	
	return math.sqrt( Width * Width + Height * Height )
	
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
	
	if Lz > z then
		
		Shadows.NormalShader:send("LightPos", { Lx, Ly, Lz })
		
		local Rotation = self.Transform:GetRadians()
		
		local ScaleX = self:GetWidth() / self.Texture:getWidth()
		local ScaleY = self:GetHeight() / self.Texture:getHeight()
		
		local Shape = {
			
			self.Texture,
			x,
			y,
			Rotation,
			ScaleX,
			SCaleY,
			IfNextLayerHigher = true,
			z = z,
			
		}
		
		Shape.type = "draw"
		Shape.shader = Shadows.NormalShader
		
		table.insert(Shapes, Shape)
		
	end
	
end

return NormalShadow