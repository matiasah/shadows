--- Implements a full-scene light whose canvas covers the entire world view.
module("shadows.Star", package.seeall)

Shadows      = require("shadows")
Light        = require("shadows.Light")
Transform    = require("shadows.Transform")

--- @class Star: Light
--- @field Star boolean Identifies this light as a star.
--- @field Blur boolean Whether to apply contact-hardening penumbras; defaults to true.
--- @field Transform Transform Star position and rotation.
--- @field Radius number Light radius in world units.
--- @field Canvas love.Canvas Full-scene light canvas.
--- @field ShadowCanvas love.Canvas Full-scene shadow canvas.
--- @field private ShadowRenderCanvas love.Canvas Multisampled shadow render target.
--- @field Shapes table Cached projected shadow draw calls.
--- @field World LightWorld Owning world.
--- @field ID integer Index in the world's star collection.
--- @field private Penumbra Penumbra? Cached occluder-distance filtering buffers.
--- @field Changed boolean? Whether the light canvas needs regeneration.
--- @field Width number Star canvas width.
--- @field Height number Star canvas height.
--- @field private __index Star Instance method lookup.
--- @field private __type string Runtime type name.
Star         = setmetatable({}, Light)
Star.__index = Star
Star.__type  = "Star"

Star.Star    = true
Star.Blur    = true

halfPi       = math.pi * 0.5

--- @description Creates a full-scene light and registers it with a world.
--- @param World LightWorld? Owning world.
--- @param Radius number? Light radius in world units.
--- @return Star? star New star, or nil when required arguments are omitted.
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
		self.Canvas = love.graphics.newCanvas(Width, Height)
		self.ShadowCanvas = love.graphics.newCanvas(Width, Height, { mipmaps = "manual" })
		self.ShadowCanvas:setMipmapFilter("linear")
		self.ShadowRenderCanvas = love.graphics.newCanvas(Width, Height, { msaa = 4 })

		self.Shapes = {}

		World:AddStar(self)

		return self
	end
end

--- @description Returns the star center in scaled canvas coordinates.
--- @return number x Canvas x-coordinate.
--- @return number y Canvas y-coordinate.
--- @return number z Scaled height.
function Star:GetCanvasCenter()
	local x, y, z = self.Transform:GetPosition()
	local wx, wy, wz = self.World:GetPosition()

	return (x - wx) * wz, (y - wy) * wz, z * wz
end

--- @description Regenerates the star's shadow and illumination canvases when dirty.
--- @return nil
function Star:Update()
	self:UpdatePenumbraSettings()
	if self.Transform.HasChanged then
		self.Transform.HasChanged = false
		self.Changed = true
	end

	if self.Changed or self.World.Changed or self.World.UpdateStars then
		local x, y, z = self.Transform:GetPosition()
		local wx, wy, wz = self.World:GetPosition()

		-- Generate new content for the shadow canvas
		love.graphics.setCanvas(self.ShadowRenderCanvas)
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
		self:ResolveShadowCanvas()
		self:GeneratePenumbra()

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
			Shadows.LightShader:send("DpiScale", require("shadows.DPI").getCanvasScale(self.Canvas))
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

		if self.Penumbra then
			self.Penumbra:Apply(self)
		end

		-- Draw the shadow shapes over the canvas
		love.graphics.setBlendMode("multiply", "premultiplied")
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(self.ShadowCanvas, 0, 0)

		-- Reset the blending mode
		love.graphics.setBlendMode("alpha", "alphamultiply")
		love.graphics.setShader()

		-- Tell the world it needs to update it's canvas
		self.Changed = nil
		self.World.UpdateCanvas = true
	end
end

--- @description Resizes the full-scene star canvases when dimensions differ.
--- @param Width number New canvas width.
--- @param Height number New canvas height.
--- @return nil
function Star:Resize(Width, Height)
	local w, h = self.Canvas:getDimensions()

	if Width ~= w or Height ~= h then
		self.Width = Width
		self.Height = Height
		self.Canvas = love.graphics.newCanvas(Width, Height)
		self.ShadowCanvas = love.graphics.newCanvas(Width, Height, { mipmaps = "manual" })
		self.ShadowCanvas:setMipmapFilter("linear")
		self.ShadowRenderCanvas = love.graphics.newCanvas(Width, Height, { msaa = 4 })
		self.Penumbra = nil
		self.Changed = true
	end
end

--- @description Removes the star from its world's star collection.
--- @return nil
function Star:Remove()
	self.World.Stars[self.ID] = nil
	self.World.Changed = true

	self.Transform:SetParent(nil)
end

return Star
