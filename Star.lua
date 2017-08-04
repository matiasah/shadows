module("shadows.Star", package.seeall)

Shadows		=		require("shadows")
Light			=		require("shadows.Light")
Transform	=		require("shadows.Transform")

Star = setmetatable( {}, Light )
Star.__index = Star

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
		self.Canvas = love.graphics.newCanvas( Width, Height )
		self.ShadowCanvas = love.graphics.newCanvas( Width, Height )
		
		World:AddStar(self)
		
		return self
		
	end
	
end

function Star:GetCanvasCenter()
	
	local x, y, z = self.Transform:GetPosition()
	
	return x - self.World.x, y - self.World.y, z
	
end

function Star:Update()
	
	if self.Changed or self.World.Changed or self.Transform.HasChanged or self.World.UpdateStars then
		
		local x, y, z = self.Transform:GetPosition()
		local MinAltitude = 0
		local MinAltitudeLast
		
		-- Generate new content for the shadow canvas
		love.graphics.setCanvas(self.ShadowCanvas)
		love.graphics.setShader()
		love.graphics.clear(255, 255, 255, 255)
		
		-- Move all the objects so that their position are corrected
		love.graphics.translate(-self.World.x, -self.World.y)
		love.graphics.scale(self.World.z, self.World.z)
		
		while MinAltitude ~= MinAltitudeLast and MinAltitude and MinAltitude < z do
			
			local Layer = MinAltitude
			
			-- Shadow shapes should subtract white color, so that you see black
			love.graphics.setBlendMode("subtract", "alphamultiply")
			love.graphics.setColor(255, 255, 255, 255)
			
			-- Produce the shadow shapes
			MinAltitudeLast = MinAltitude
			Shapes, MinAltitude, MaxAltitude = self:GenerateShadows(x, y, z, Layer)
			
			-- Draw the shadow shapes
			for Index = 1, #Shapes do
				
				local Shadow = Shapes[Index]
				
				Shadow:Draw(MinAltitude)
				
			end
			
			-- Draw the shapes over the shadow shapes, so that the shadow of a object doesn't cover another object
			love.graphics.setBlendMode("add", "alphamultiply")
			love.graphics.setColor(255, 255, 255, 255)
			love.graphics.setShader()
			
			for Index = self.World.Bodies:GetLength(), 1, -1 do
				
				local Body = self.World.Bodies:Get(Index)
				local Bx, By, Bz = Body:GetPosition()
				
				if Bz <= Layer then
					
					break
					
				end
				
				-- As long as this body is on top of the layer
				Body:DrawRadius(x, y, self.Radius)
				
			end
			
		end
		
		self.Moved = nil
		
		-- This needs to be put right after self:GenerateShadows, because it uses the self.Transform.HasChanged field
		if self.Transform.HasChanged then
			-- If the light has moved, mark it as it hasn't so that it doesn't update until self.Transform.HasChanged is set to true
			self.Transform.HasChanged = false
			
		end
		
		-- Draw custom shadows
		love.graphics.setBlendMode("subtract", "alphamultiply")
		love.graphics.setColor(255, 255, 255, 255)
		self.World:DrawShadows(self)
		
		-- Draw the sprites so that shadows don't cover them
		love.graphics.setShader(Shadows.ShapeShader)
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(255, 255, 255, 255)
		self.World:DrawSprites(self)
		
		-- Now stop using the shadow canvas and generate the light
		love.graphics.setCanvas(self.Canvas)
		love.graphics.setShader()
		love.graphics.clear()
		love.graphics.origin()
		love.graphics.translate(x - self.World.x - self.Radius, y - self.World.y - self.Radius)
		
		if self.Image then
			-- If there's a image to be used as light texture, use it
			love.graphics.setBlendMode("lighten", "premultiplied")
			love.graphics.setColor(self.R, self.G, self.B, self.A)
			love.graphics.draw(self.Image, self.Radius, self.Radius)
			
		else
			-- Use a shader to generate the light
			Shadows.LightShader:send("Radius", self.Radius)
			Shadows.LightShader:send("Center", {x - self.World.x, y - self.World.y, z})
			
			-- Calculate the rotation of the light
			local Arc = math.rad(self.Arc * 0.5)
			local Angle = self.Transform:GetRadians(-halfPi)
			
			-- Set the light shader
			love.graphics.setShader(Shadows.LightShader)
			love.graphics.setBlendMode("alpha", "premultiplied")
			
			-- Filling it with a arc is more efficient than with a rectangle for this case
			love.graphics.setColor(self.R, self.G, self.B, self.A)
			love.graphics.arc("fill", self.Radius, self.Radius, self.Radius, Angle - Arc, Angle + Arc)
			
			-- Unset the shader
			love.graphics.setShader()
			
		end
		
		if self.Blur then
			-- Generate a radial blur (to make the light softer)
			love.graphics.origin()
			love.graphics.setShader(Shadows.RadialBlurShader)
			Shadows.RadialBlurShader:send("Size", {self.Canvas:getDimensions()})
			Shadows.RadialBlurShader:send("Position", {x - self.World.x, y - self.World.y})
			Shadows.RadialBlurShader:send("Radius", self.Radius)
			
		end
		
		-- Draw the shadow shapes over the canvas
		love.graphics.setBlendMode("multiply", "alphamultiply")
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