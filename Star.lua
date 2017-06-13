module("shadows.Star", package.seeall)

Shadows		=		require("shadows")
Light			=		require("shadows.Light")
Transform	=		require("shadows.Transform")

Star = Light:new()
Star.__index = Star

local setCanvas = love.graphics.setCanvas
local clear = love.graphics.clear
local origin = love.graphics.origin
local translate = love.graphics.translate
local setBlendMode = love.graphics.setBlendMode
local setColor = love.graphics.setColor
local setShader = love.graphics.setShader
local setScale = love.graphics.scale
local arc = love.graphics.arc
local draw = love.graphics.draw
local halfPi = math.pi * 0.5

function Star:new(World, Radius)
	
	local self = setmetatable({}, Star)
	
	if World and Radius then
		
		local Width, Height = World.Canvas:getDimensions()
		
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		self.Transform.Object = self
		
		self.Star = true
		self.Blur = true
		self.Radius = Radius
		self.Canvas = love.graphics.newCanvas( Width, Height )
		self.ShadowCanvas = love.graphics.newCanvas( Width, Height )
		self.Shadows = {}
		
		World:AddStar(self)
		
	end
	
	return self
	
end

function Star:Update()
	
	if self.Changed or self.World.Changed or self.Transform.HasChanged or self.World.UpdateStars then
		
		local x, y, z = self.Transform:GetPosition()
		
		-- Generate new content for the shadow canvas
		setCanvas(self.ShadowCanvas)
		setShader()
		clear(255, 255, 255, 255)
		
		-- Move all the objects so that their position are corrected
		translate(-self.World.x, -self.World.y)
		setScale(self.World.z, self.World.z)
		
		-- Shadow shapes should subtract white color, so that you see black
		setBlendMode("subtract", "alphamultiply")
		setColor(255, 255, 255, 255)
		
		-- Produce the shadow shapes
		self:GenerateShadows(x, y)
		self.Moved = nil
		
		-- This needs to be put right after self:GenerateShadows, because it uses the self.Transform.HasChanged field
		if self.Transform.HasChanged then
			-- If the light has moved, mark it as it hasn't so that it doesn't update until self.Transform.HasChanged is set to true
			self.Transform.HasChanged = false
			
		end
		
		-- Draw the shadow shapes
		for _, Shapes in pairs(self.Shadows) do
			
			for _, Shadow in pairs(Shapes) do
				
				love.graphics[Shadow.type]("fill", unpack(Shadow))
				
			end
			
		end
		
		-- Draw custom shadows
		self.World:DrawShadows(self)
		
		-- Draw normal maps here
		Shadows.NormalShader:send("LightPos", {x - self.World.x, y - self.World.y, z})
		
		setShader(Shadows.NormalShader)
		for Index, NormalMap in pairs(self.World.NormalMaps) do
			
			NormalMap:Draw()
			
		end
		
		-- Draw the shapes over the shadow shapes, so that the shadow of a object doesn't cover another object
		setColor(255, 255, 255, 255)
		setBlendMode("add", "alphamultiply")
		setShader()
		
		for Index, Body in pairs(self.World.Bodies) do
			
			Body:DrawRadius(x, y, self.Radius)
			
		end
		
		-- Draw the sprites so that shadows don't cover them
		setShader(Shadows.ShapeShader)
		self.World:DrawSprites(self)
		
		-- Now stop using the shadow canvas and generate the light
		setCanvas(self.Canvas)
		setShader()
		clear()
		origin()
		translate(x - self.World.x - self.Radius, y - self.World.y - self.Radius)
		
		if self.Image then
			-- If there's a image to be used as light texture, use it
			setBlendMode("lighten", "premultiplied")
			setColor(self.R, self.G, self.B, self.A)
			draw(self.Image, self.Radius, self.Radius)
			
		else
			-- Use a shader to generate the light
			Shadows.LightShader:send("Radius", self.Radius)
			Shadows.LightShader:send("Center", {x - self.World.x, y - self.World.y, z})
			
			-- Calculate the rotation of the light
			local Arc = math.rad(self.Arc * 0.5)
			local Angle = self.Transform:GetRadians(-halfPi)
			
			-- Set the light shader
			setShader(Shadows.LightShader)
			setBlendMode("alpha", "premultiplied")
			
			-- Filling it with a arc is more efficient than with a rectangle for this case
			setColor(self.R, self.G, self.B, self.A)
			arc("fill", self.Radius, self.Radius, self.Radius, Angle - Arc, Angle + Arc)
			
			-- Unset the shader
			setShader()
			
		end
		
		if self.Blur then
			-- Generate a radial blur (to make the light softer)
			origin()
			setShader(Shadows.RadialBlurShader)
			Shadows.RadialBlurShader:send("Size", {self.Canvas:getDimensions()})
			Shadows.RadialBlurShader:send("Position", {x - self.World.x, y - self.World.y})
			Shadows.RadialBlurShader:send("Radius", self.Radius)
			
		end
		
		-- Draw the shadow shapes over the canvas
		setBlendMode("multiply", "alphamultiply")
		draw(self.ShadowCanvas, 0, 0)
		
		-- Reset the blending mode
		setBlendMode("alpha", "alphamultiply")
		setShader()
		
		-- Tell the world it needs to update it's canvas
		self.Changed = nil
		self.World.UpdateCanvas = true
		
	end
	
end

function Star:Resize(Width, Height)
	
	local w, h = self.Canvas:getDimensions()
	
	if Width ~= w or Height ~= h then
		
		self.Canvas = love.graphics.newCanvas(Width, Height)
		self.ShadowCanvas = love.graphics.newCanvas(Width, Height)
		self.Changed = true
		
	end
	
end

function Star:Remove()
	
	self.World.Stars[self.ID] = nil
	self.World.Changed = true
	
	self.Transform:SetParent(nil)
	
end

return Star