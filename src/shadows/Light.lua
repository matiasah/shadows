---@module Implements a local light with cached shadow and illumination canvases.
module("shadows.Light", package.seeall)

Object                             = require("shadows.Object")

Shadows                            = require("shadows")
Transform                          = require("shadows.Transform")

--- @class Light: Object
--- @field World LightWorld? World that owns this light.
--- @field ID integer? Index in the world's light table.
--- @field Transform Transform Light position and rotation.
--- @field Radius number Light radius in world units.
--- @field Arc number Angular coverage in degrees.
--- @field SizeRadius number Effective source radius for penumbras in world units; defaults to 10.
--- @field Blur boolean Whether to apply contact-hardening penumbras; defaults to true.
--- @field R number Red color channel in the 0-1 range; defaults to 1.
--- @field G number Green color channel in the 0-1 range; defaults to 1.
--- @field B number Blue color channel in the 0-1 range; defaults to 1.
--- @field A number Alpha color channel in the 0-1 range; defaults to 1.
--- @field Image love.Texture? Optional custom light texture.
--- @field Canvas love.Canvas? Cached light canvas.
--- @field ShadowCanvas love.Canvas? Cached shadow canvas.
--- @field private ShadowRenderCanvas love.Canvas? Multisampled shadow render target.
--- @field Shapes table? Cached projected shadow draw calls.
--- @field Changed boolean? Whether the light canvas needs regeneration.
--- @field Moved boolean? Whether the light has moved.
--- @field private Penumbra Penumbra? Cached occluder-distance filtering buffers.
--- @field private PreviousBlur boolean? Last rendered blur setting.
--- @field private PreviousSizeRadius number? Last rendered effective source radius.
--- @field private __index Light Instance method lookup.
--- @field private __type string Runtime type name.
Light                              = setmetatable({}, Object)
Light.__index                      = Light
Light.__type                       = "Light"

Light.Arc                          = 360
Light.Radius                       = 0
Light.SizeRadius                   = 10
Light.Blur                         = true

Light.R, Light.G, Light.B, Light.A = 1, 1, 1, 1

halfPi                             = math.pi * 0.5

--- @description Creates and registers a light with the supplied world.
--- @param World LightWorld? Owning world.
--- @param Radius number? Light radius in world units.
--- @return Light? light New light, or nil when required arguments are omitted.
function Light:new(World, Radius)
	-- Class constructor
	if World and Radius then
		local self = setmetatable({}, Light)

		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		self.Transform.Object = self

		self.Radius = Radius

		World:AddLight(self)

		return self
	end
end

--- @description Creates shadow and illumination canvases when they do not exist.
--- @return nil
function Light:InitCanvas()
	if not self.Canvas then
		self.Canvas = love.graphics.newCanvas(self.Radius * 2, self.Radius * 2)
	end

	if not self.ShadowCanvas then
		self.ShadowCanvas = love.graphics.newCanvas(self.Radius * 2, self.Radius * 2, { mipmaps = "manual" })
		self.ShadowCanvas:setMipmapFilter("linear")
	end

	if not self.ShadowRenderCanvas then
		self.ShadowRenderCanvas = love.graphics.newCanvas(self.Radius * 2, self.Radius * 2, { msaa = 4 })
	end

	if not self.Shapes then
		self.Shapes = {}
	end

	self.Changed = true
	self.Moved = true
end

--- @description Releases references to the cached light and shadow canvases.
--- @return nil
function Light:DestroyCanvas()
	self.Canvas = nil
	self.ShadowCanvas = nil
	self.ShadowRenderCanvas = nil
	self.Shapes = nil
	self.Penumbra = nil
end

--- @description Reports whether the cached light canvas has been released.
--- @return boolean destroyed True when the canvas is absent.
function Light:GetCanvasDestroyed()
	return self.Canvas == nil
end

--- @description Generates shadow draw calls for bodies intersecting a height layer.
--- @param x number Light x-coordinate.
--- @param y number Light y-coordinate.
--- @param z number Light height.
--- @param Layer number Shadow height layer to process.
--- @return table shapes Draw calls grouped by body and shape.
--- @return number? nextHeight Next body height to process.
function Light:GenerateShadows(x, y, z, Layer)
	local preLayerShapes = self.Shapes[Layer] or {}
	local newLayerShapes = {}
	local newZ

	for Index = self.World.Bodies:GetLength(), 1, -1 do
		local Body = self.World.Bodies:Get(Index)
		-- If a body has been removed from the local reference, the light has moved, or the body has moved

		local preBodyShapes = preLayerShapes[Body] or {}
		local newBodyShapes = {}

		newLayerShapes[Body] = newBodyShapes

		local ShapesList = Body:GetShapes()

		for i = ShapesList:GetLength(), 1, -1 do
			local Shape = ShapesList:Get(i)
			local SqrRadius = (self.Radius + Shape:GetRadius()) *
				(self.Radius + Shape:GetRadius()) --self.Radius * self.Radius + Shape:GetSqrRadius()
			local ShapeX, ShapeY, ShapeZ = Shape:GetCentroid()
			local dx, dy, dz = ShapeX - x, ShapeY - y, Layer

			if ShapeZ <= Layer then
				-- All the remaining bodies on the iteration will have a ShapeZ lower than 'Layer' so just return the shapes and the new z	
				return newLayerShapes, newZ
			end

			-- Is the light in the draw range?
			if dx * dx + dy * dy + dz * dz <= SqrRadius then
				if Shape:GetChanged() or Body:GetChanged() or self.Changed or not preBodyShapes[Shape] then
					local ShadowList = {}

					Shape:GenerateShadows(ShadowList, Body, 0, 0, dz, self)

					if #ShadowList > 0 then
						newBodyShapes[Shape] = ShadowList
					end
				else
					newBodyShapes[Shape] = preBodyShapes[Shape]
				end

				if not newZ or ShapeZ < newZ then
					newZ = ShapeZ
				end
			end
		end
	end

	return newLayerShapes, newZ
end

--- @description Returns the light-canvas center and light height.
--- @return number x Canvas-center x-coordinate.
--- @return number y Canvas-center y-coordinate.
--- @return number z Light height.
function Light:GetCanvasCenter()
	local x, y, z = self.Transform:GetPosition()

	return self.Radius, self.Radius, z
end

--- @description Resolves the multisampled shadow target into the mipmapped visibility canvas.
--- @return nil
function Light:ResolveShadowCanvas()
	love.graphics.push("all")
	love.graphics.setCanvas(self.ShadowCanvas)
	love.graphics.origin()
	love.graphics.setShader()
	love.graphics.setScissor()
	love.graphics.setStencilTest()
	love.graphics.setBlendMode("replace", "premultiplied")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.ShadowRenderCanvas)
	love.graphics.pop()
end

--- @description Renders the shadow layers and occluding bodies to the shadow canvas.
--- @param x number Light x-coordinate.
--- @param y number Light y-coordinate.
--- @param z number Light height.
--- @return nil
function Light:GenerateDarkness(x, y, z)
	local newShapes = {}
	local MinAltitude = 0
	local MinAltitudeLast

	while MinAltitude ~= MinAltitudeLast and MinAltitude and MinAltitude < z do
		local Layer = MinAltitude

		-- Shadow shapes should subtract white color, so that you see black
		love.graphics.setBlendMode("subtract", "alphamultiply")
		love.graphics.setColor(1, 1, 1, 1)

		-- Produce the shadow shapes
		MinAltitudeLast = MinAltitude
		Shapes, MinAltitude = self:GenerateShadows(x, y, z, Layer)

		-- Draw the shadow shapes		
		for Body, BodyShapes in pairs(Shapes) do
			for Shape, ShadowList in pairs(BodyShapes) do
				for _, Shadow in pairs(ShadowList) do
					Shadow:Draw(MinAltitude)
				end
			end
		end

		-- Draw the shapes over the shadow shapes, so that the shadow of a object doesn't cover another object
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setShader()

		for Index = self.World.Bodies:GetLength(), 1, -1 do
			local Body = self.World.Bodies:Get(Index)
			local Bx, By, Bz = Body:GetPosition()

			if Bz <= Layer then
				break
			end

			-- As long as this body is on top of the layer
			Body:DrawRadius(x, y, z, self.Radius)
		end

		newShapes[Layer] = Shapes
	end

	self.Shapes = newShapes
end

--- @description Initializes or releases canvases according to world visibility.
--- @return boolean visible Whether the light should be rendered.
function Light:GetUpdateVisibility()
	-- World's position
	local wx, wy, wz = self.World:GetPosition()

	-- Light's position
	local x, y, z = self:GetPosition()

	-- Delta
	local dx = (wx + self.World:GetWidth() * 0.5) - x
	local dy = (wy + self.World:GetHeight() * 0.5) - y
	local Distance = math.sqrt(dx * dx + dy * dy)

	if self:GetCanvasDestroyed() then
		-- If the distance is lower than the light's radius + world's border radius
		if Distance <= (self.World:GetBorderRadius() + self.Radius) * wz then
			-- Must be initialized
			self:InitCanvas()
			return true
		end
	else
		-- If the distance is higher than the light's radius + world's border radius
		if Distance > (self.World:GetBorderRadius() + self.Radius) * wz then
			self:DestroyCanvas()
			return false
		end
	end

	return not self:GetCanvasDestroyed()
end

--- @description Updates cached canvases when the light or its world has changed.
--- @return nil
function Light:Update()
	self:UpdatePenumbraSettings()
	-- If the object shouldn't be visible
	if not self:GetUpdateVisibility() then
		-- Do nothing
		return nil
	end

	if self.Transform.HasChanged then
		self.Transform.HasChanged = false
		self.Changed = true
	end

	if self.Changed or self.World.Changed then
		local x, y, z = self.Transform:GetPosition()

		-- Generate new content for the shadow canvas
		love.graphics.setCanvas(self.ShadowRenderCanvas)
		love.graphics.setShader()
		love.graphics.clear(1, 1, 1, 1)

		-- Move all the objects so that their position local to the light are corrected
		love.graphics.origin()
		love.graphics.translate(self.Radius - x, self.Radius - y)

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

		if self.Image then
			-- If there's a image to be used as light texture, use it
			love.graphics.setBlendMode("lighten", "premultiplied")
			love.graphics.setColor(self.R, self.G, self.B, self.A)
			love.graphics.draw(self.Image, self.Radius, self.Radius)
		else
			-- Use a shader to generate the light
			Shadows.LightShader:send("DpiScale", require("shadows.DPI").getCanvasScale(self.Canvas))
			Shadows.LightShader:send("Radius", self.Radius)
			Shadows.LightShader:send("Center", { self.Radius, self.Radius, z })

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

		if self.Penumbra then
			self.Penumbra:Apply(self)
		end

		-- Composite shadow visibility without filtering the light's falloff.
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

--- @description Invalidates cached rendering when public penumbra settings change.
--- @return nil
function Light:UpdatePenumbraSettings()
	assert(type(self.SizeRadius) == "number" and self.SizeRadius >= 0 and self.SizeRadius < math.huge,
		"SizeRadius must be a finite nonnegative number")
	if self.PreviousBlur ~= self.Blur or self.PreviousSizeRadius ~= self.SizeRadius then
		self.PreviousBlur = self.Blur
		self.PreviousSizeRadius = self.SizeRadius
		self.Changed = true
	end
end

--- @description Builds occluder-distance buffers using the current shadow rendering transform.
--- @return nil
function Light:GeneratePenumbra()
	if self.Blur and self.SizeRadius > 0 then
		if not self.Penumbra then
			self.Penumbra = require("shadows.Penumbra"):new(self.ShadowCanvas)
		end
		self.Penumbra:Update(self)
	else
		self.Penumbra = nil
	end
end

--- @description Assigns the owning light world.
--- @param World LightWorld Owning world.
--- @return nil
function Light:SetWorld(World)
	self.World = World
end

--- @description Returns the owning light world.
--- @return LightWorld? world Owning world.
function Light:GetWorld()
	return self.World
end

--- @description Sets the light's local rotation in degrees.
--- @param Angle number Rotation angle.
--- @return Light light This light, for chaining.
function Light:SetAngle(Angle)
	self.Transform:SetLocalRotation(Angle)

	return self
end

--- @description Returns the light's world rotation in degrees.
--- @return number angle World rotation.
function Light:GetAngle()
	return self.Transform:GetRotation()
end

--- @description Sets the light's position and optional height.
--- @param x number World x-coordinate.
--- @param y number World y-coordinate.
--- @param z number? Height; defaults to the current height.
--- @return Light light This light, for chaining.
function Light:SetPosition(x, y, z)
	self.Transform:SetLocalPosition(x, y, z)

	return self
end

--- @description Returns the light's world position and height.
--- @return number x World x-coordinate.
--- @return number y World y-coordinate.
--- @return number z World height.
function Light:GetPosition()
	return self.Transform:GetPosition()
end

--- @description Sets the light's RGBA color and invalidates its canvas when changed.
--- @param R number Red channel in the 0-1 range.
--- @param G number Green channel in the 0-1 range.
--- @param B number Blue channel in the 0-1 range.
--- @param A number? Alpha channel in the 0-1 range; defaults to the current alpha.
--- @return Light light This light, for chaining.
function Light:SetColor(R, G, B, A)
	if R ~= self.R then
		self.R = R
		self.Changed = true
	end

	if G ~= self.G then
		self.G = G
		self.Changed = true
	end

	if B ~= self.B then
		self.B = B
		self.Changed = true
	end

	if A ~= nil and A ~= self.A then
		self.A = A
		self.Changed = true
	end

	return self
end

--- @description Returns the light's RGBA color.
--- @return number R Red channel in the 0-1 range.
--- @return number G Green channel in the 0-1 range.
--- @return number B Blue channel in the 0-1 range.
--- @return number A Alpha channel in the 0-1 range.
function Light:GetColor()
	return self.R, self.G, self.B, self.A
end

--- @description Sets a custom texture and derives the light radius from its dimensions.
--- @param Image love.Texture Texture used to draw the light.
--- @return nil
function Light:SetImage(Image)
	if Image ~= self.Image then
		local Width, Height = Image:getDimensions()

		self.Image = Image
		self.Radius = math.sqrt(Width * Width + Height * Height) * 0.5
		self.Changed = true
	end
end

--- @description Returns the custom light texture.
--- @return love.Texture? image Custom texture, if configured.
function Light:GetImage()
	return self.Image
end

--- @description Sets the light radius and invalidates its canvas when changed.
--- @param Radius number New radius in world units.
--- @return nil
function Light:SetRadius(Radius)
	if Radius ~= self.Radius then
		self.Radius = Radius
		self.Changed = true
	end
end

--- @description Returns the light radius in world units.
--- @return number radius Light radius.
function Light:GetRadius()
	return self.Radius
end

--- @description Removes the light from its world and detaches its transform.
--- @return nil
function Light:Remove()
	if self.World then
		self.World.Lights[self.ID] = nil
		self.World.Changed = true
		self.World = nil
		self.ID = nil

		self.Transform:SetParent(nil)
	end
end

--- @description Returns the light transform.
--- @return Transform transform Light transform.
function Light:GetTransform()
	return self.Transform
end

return Light
