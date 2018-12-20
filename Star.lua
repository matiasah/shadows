module("shadows.Star", package.seeall)

Shadows		=		require("shadows")
Light		=		require("shadows.Light")
Transform	=		require("shadows.Transform")

Star = setmetatable( {}, Light )
Star.__index = Star
Star.__type = "Star"

Star.Star = true
Star.Blur = true

halfPi = math.pi * 0.5

function Star:new(World, Radius)
	-- Class constructor
	if World and Radius then
		
		local self = setmetatable({}, Star)
		local Width, Height = World.Canvas:getDimensions()
		
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		self.Transform.Object = self
		
		self.Radius = Radius
		self.Width = Width
		self.Height = Height
		self.Canvas = love.graphics.newCanvas( Width, Height )
		self.ShadowCanvas = love.graphics.newCanvas( Width, Height )
		
		self.Shapes = {}
		
		World:AddStar(self)
		
		return self
		
	end
	
end

function Star:GetCanvasCenter()
	
	local x, y, z = self.Transform:GetPosition()
	local wx, wy, wz = self.World:GetPosition()
	
	return ( x - wx ) * wz, ( y - wy ) * wz, z * wz
	
end

function Star:Update()
	
	if self.Transform.HasChanged then
		
		self.Transform.HasChanged = false
		self.Changed = true
		
	end
	
	if self.Changed or self.World.Changed or self.World.UpdateStars then
		
		local x, y, z = self.Transform:GetPosition()
		local wx, wy, wz = self.World:GetPosition()
		
		-- Generate new content for the shadow canvas
		love.graphics.setCanvas(self.ShadowCanvas)
		love.graphics.setShader()
		love.graphics.clear(255, 255, 255, 255)
		
		-- Move all the objects so that their position are corrected
		love.graphics.origin()
		love.graphics.translate(-wx * wz, -wy * wz)
		love.graphics.scale(wz, wz)
		
		self:GenerateDarkness(x, y, z)
		
		-- Draw custom shadows
		love.graphics.setBlendMode("subtract", "alphamultiply")
		love.graphics.setColor(1, 1, 1, 1)
		self.World:DrawShadows(self)
		
		-- Draw the sprites so that shadows don't cover them
		love.graphics.setShader(Shadows.ShapeShader)
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(1, 1, 1, 1)
		self.World:DrawSprites(self)
		
		-- Now stop using the shadow canvas and generate the light
		love.graphics.setCanvas(self.Canvas)
		love.graphics.setShader()
		love.graphics.clear()
		love.graphics.origin()
		--love.graphics.translate((x - wx - self.Radius) * wz, (y - wy - self.Radius) * wz)
		
		if self.Image then
			-- If there's a image to be used as light texture, use it
			love.graphics.setBlendMode("lighten", "premultiplied")
			love.graphics.setColor(self.R / 255, self.G / 255, self.B / 255, self.A / 255)
			love.graphics.draw(self.Image, self.Radius * wz, self.Radius * wz)
			
		else
			-- Use a shader to generate the light
			Shadows.LightShader:send("Radius", self.Radius * wz)
			Shadows.LightShader:send("Center", { self:GetCanvasCenter() })
			
			-- Calculate the rotation of the light
			local Arc = math.rad(self.Arc * 0.5)
			local Angle = self.Transform:GetRadians(-halfPi)
			
			-- Set the light shader
			love.graphics.setShader(Shadows.LightShader)
			love.graphics.setBlendMode("alpha", "premultiplied")
			
			-- Filling it with a arc is more efficient than with a rectangle for this case
			love.graphics.setColor(self.R / 255, self.G / 255, self.B / 255, self.A / 255)
			love.graphics.rectangle("fill", 0, 0, self.Width, self.Height)
			
			-- Unset the shader
			love.graphics.setShader()
			
		end
		
		if self.Blur then
			
			-- Generate a radial blur (to make the light softer)
			love.graphics.origin()
			love.graphics.setShader(Shadows.RadialBlurShader)
			Shadows.RadialBlurShader:send("Size", { self.Canvas:getDimensions() })
			Shadows.RadialBlurShader:send("Position", { self:GetCanvasCenter() })
			Shadows.RadialBlurShader:send("Radius", self.Radius * wz)
			
		end
		
		-- Draw the shadow shapes over the canvas
		love.graphics.setBlendMode("multiply", "premultiplied")
		love.graphics.draw(self.ShadowCanvas, 0, 0)
		
		-- Reset the blending mode
		love.graphics.setBlendMode("alpha", "alphamultiply")
		love.graphics.setShader()
		
		-- Tell the world it needs to update it's canvas
		self.Changed = nil
		self.World.UpdateCanvas = true
		
	end
	
end

function Star:Resize(Width, Height)
	
	local w, h = self.Canvas:getDimensions()
	
	if Width ~= w or Height ~= h then
		
		self.Width = Width
		self.Height = Height
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