---@module Implements a local light with cached shadow and illumination canvases.
module("shadows.Light", package.seeall)

Object                             = require("shadows.Object")

Shadows                            = require("shadows")
Transform                          = require("shadows.Transform")

--- @class Light: Object
--- @field World LightWorld? World that owns this light.
--- @field Settings Settings? Shared settings object from the owning world.
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
--- @field Cookie love.Texture? Optional RGB/alpha illumination mask; defaults to nil, configured through SetCookie.
--- @field CookieX number Cookie center offset along the light's local x-axis; defaults to 0.
--- @field CookieY number Cookie center offset along the light's local y-axis; defaults to 0.
--- @field CookieAngle number Cookie rotation relative to the light in degrees; defaults to 0.
--- @field CookieScaleX number Positive horizontal multiplier on the diameter-fitted texture; defaults to 1.
--- @field CookieScaleY number Positive vertical multiplier on the diameter-fitted texture; defaults to 1.
--- @field Canvas love.Canvas? Cached light canvas.
--- @field ShadowCanvas love.Canvas? Cached shadow canvas.
--- @field private ShadowRenderCanvas love.Canvas? Multisampled shadow render target.
--- @field Shapes table? Cached projected shadow draw calls.
--- @field Changed boolean? Whether shadow geometry and all rendering stages need regeneration.
--- @field ShadowChanged boolean? Whether shadow pixels changed without invalidating all cached geometry.
--- @field protected AppearanceChanged boolean? Whether illumination needs recompositing.
--- @field protected PenumbraChanged boolean? Whether the filter radius needs updating.
--- @field Star boolean? Whether this light uses a full-scene canvas.
--- @field Moved boolean? Whether the light has moved.
--- @field private Penumbra Penumbra? Cached occluder-distance filtering buffers.
--- @field private PreviousBlur boolean? Last rendered blur setting.
--- @field private PreviousSizeRadius number? Last rendered effective source radius.
--- @field private PreviousRadius number? Last updated light radius.
--- @field private PreviousArc number? Last updated angular coverage.
--- @field private PreviousAngle number? Last updated world rotation.
--- @field private PreviousX number? Last updated world x-coordinate.
--- @field private PreviousY number? Last updated world y-coordinate.
--- @field private PreviousZ number? Last updated world height.
--- @field private ShadowRenderCount integer Completed shadow-canvas redraws over this renderer's lifetime; defaults to 0.
--- @field private GeometryRebuildCount integer Completed shape/layer geometry generations over this renderer's lifetime; defaults to 0.
--- @field private ShadowDrawCount integer Executed cached shadow draw calls over this renderer's lifetime; defaults to 0.
--- @field private CanvasAllocationCount integer Successful canvas allocations, including penumbra buffers; defaults to 0.
--- @field private SampledShadowRenderCount integer Redraw total sampled by the previous world update; defaults to 0.
--- @field private SampledGeometryRebuildCount integer Geometry total sampled by the previous world update; defaults to 0.
--- @field private SampledShadowDrawCount integer Draw total sampled by the previous world update; defaults to 0.
--- @field private SampledCanvasAllocationCount integer Allocation total sampled by the previous world update; defaults to 0.
--- @field private __index Light Instance method lookup.
--- @field private __type string Runtime type name.
Light                              = setmetatable({}, Object)
Light.__index                      = Light
Light.__type                       = "Light"

Light.Arc                          = 360
Light.Radius                       = 0
Light.SizeRadius                   = 10
Light.Blur                         = true
Light.CookieX, Light.CookieY, Light.CookieAngle = 0, 0, 0
Light.CookieScaleX, Light.CookieScaleY = 1, 1
Light.ShadowRenderCount             = 0
Light.GeometryRebuildCount          = 0
Light.ShadowDrawCount               = 0
Light.CanvasAllocationCount         = 0
Light.SampledShadowRenderCount      = 0
Light.SampledGeometryRebuildCount   = 0
Light.SampledShadowDrawCount        = 0
Light.SampledCanvasAllocationCount = 0

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

--- @description Allocates a canvas using this light world's rendering quality.
--- @param Width number Canvas width in logical pixels.
--- @param Height number Canvas height in logical pixels.
--- @param Options table? Additional LÖVE canvas settings.
--- @return love.Canvas canvas New canvas.
function Light:NewCanvas(Width, Height, Options)
	local canvasOptions = { dpiscale = self.Settings.ShadowScale }
	if Options then
		for name, value in pairs(Options) do
			canvasOptions[name] = value
		end
	end
	local canvas = love.graphics.newCanvas(Width, Height, canvasOptions)
	self.CanvasAllocationCount = self.CanvasAllocationCount + 1
	return canvas
end

--- @description Creates shadow and illumination canvases when they do not exist.
--- @return nil
function Light:InitCanvas()
	if not self.Canvas then
		self.Canvas = self:NewCanvas(self.Radius * 2, self.Radius * 2)
	end

	if not self.ShadowCanvas then
		self.ShadowCanvas = self:NewCanvas(self.Radius * 2, self.Radius * 2, { mipmaps = "manual" })
		self.ShadowCanvas:setMipmapFilter("linear")
	end

	if not self.ShadowRenderCanvas then
		self.ShadowRenderCanvas = self:NewCanvas(self.Radius * 2, self.Radius * 2,
			{ msaa = self.Settings.ShadowMSAA })
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
	if self.Canvas and self.World then self.World:InvalidateLight(self) end
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
					self.GeometryRebuildCount = self.GeometryRebuildCount + 1

					newBodyShapes[Shape] = ShadowList
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
	local MinAltitude = 0.0
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
					if (not Shadow.Layer or Shadow.Layer == MinAltitude)
						and Shadow:IsVisible(self.ShadowRenderCanvas) then
						Shadow:Draw(MinAltitude)
						self.ShadowDrawCount = self.ShadowDrawCount + 1
					end
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

--- @description Retains a shared light cache while its canvas bounds intersect any registered camera.
--- @return boolean visible Whether the light should be rendered.
function Light:GetUpdateVisibility()
	for _, Camera in ipairs(self.World.Cameras) do
		if Camera:IsLightVisible(self) then
			if self:GetCanvasDestroyed() then self:InitCanvas() end
			return true
		end
	end
	self:DestroyCanvas()
	return false
end

---@description Rebuilds shadow pixels with the caller's world-to-canvas transform.
---@param x number Light world x-coordinate.
---@param y number Light world y-coordinate.
---@param z number Light height.
---@return nil
function Light:RenderShadowCanvas(x, y, z)
	love.graphics.setCanvas(self.ShadowRenderCanvas)
	love.graphics.setShader()
	love.graphics.clear(1, 1, 1, 1)
	self:GenerateDarkness(x, y, z)
	love.graphics.setBlendMode("subtract", "alphamultiply")
	love.graphics.setColor(1, 1, 1, 1)
	self.World:DrawShadows(self)
	love.graphics.setShader(Shadows.ShapeShader)
	love.graphics.setBlendMode("add", "alphamultiply")
	love.graphics.setColor(1, 1, 1, 1)
	self.World:DrawSprites(self)
	self:ResolveShadowCanvas()
	self.ShadowRenderCount = self.ShadowRenderCount + 1
end

---@description Returns completed shadow redraws and shape/layer geometry rebuilds for this renderer.
---@return integer shadowRedraws Lifetime shadow-canvas redraw count.
---@return integer geometryRebuilds Lifetime geometry generation count, including empty results.
function Light:GetDebugCounts()
	return self.ShadowRenderCount, self.GeometryRebuildCount
end

---@description Samples work completed since this renderer's previous world update, including pending allocations.
---@return integer shadowRedraws Shadow redraws since the previous sample.
---@return integer geometryRebuilds Geometry generations since the previous sample.
---@return integer shadowDrawCalls Cached draw executions since the previous sample.
---@return integer canvasAllocations Successful allocations since the previous sample.
function Light:SampleFrameWork()
	local redraws = self.ShadowRenderCount - self.SampledShadowRenderCount
	local rebuilds = self.GeometryRebuildCount - self.SampledGeometryRebuildCount
	local draws = self.ShadowDrawCount - self.SampledShadowDrawCount
	local allocations = self.CanvasAllocationCount - self.SampledCanvasAllocationCount
	self.SampledShadowRenderCount = self.ShadowRenderCount
	self.SampledGeometryRebuildCount = self.GeometryRebuildCount
	self.SampledShadowDrawCount = self.ShadowDrawCount
	self.SampledCanvasAllocationCount = self.CanvasAllocationCount
	return redraws, rebuilds, draws, allocations
end

--- @description Updates cached canvases when the light or its world has changed.
--- @return nil
function Light:Update()
	self:UpdateRenderSettings()
	-- If the object shouldn't be visible
	if not self:GetUpdateVisibility() then
		-- Do nothing
		return nil
	end

	local shadowChanged = self.Changed or self.ShadowChanged
	if shadowChanged or self.AppearanceChanged or self.PenumbraChanged then
		local x, y, z = self.Transform:GetPosition()

		if shadowChanged or self.PenumbraChanged then
			love.graphics.origin()
			love.graphics.translate(self.Radius - x, self.Radius - y)
			if shadowChanged then self:RenderShadowCanvas(x, y, z) end
			self:GeneratePenumbra(shadowChanged or false)
		end

		-- Now stop using the shadow canvas and generate the light
		love.graphics.setCanvas(self.Canvas)
		love.graphics.setShader()
		love.graphics.clear()
		love.graphics.origin()

		self:DrawLight(z)
		self:ApplyCookie()

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

		self.World:InvalidateLight(self)
		self.Changed = nil
		self.ShadowChanged = nil
		self.AppearanceChanged = nil
		self.PenumbraChanged = nil
	end
end

---@description Multiplies illumination by a centered cookie without changing its existing alpha or shadow buffers.
---@return nil
function Light:ApplyCookie()
	if not self.Cookie then return end
	local width, height = self.Cookie:getDimensions()
	local zoom = (self.Star and select(3, self.Camera:GetPosition())) or 1
	local x, y = self:GetCanvasCenter()
	local angle = math.rad(self:GetAngle())
	local c, s = math.cos(angle), math.sin(angle)
	local rotation = math.rad(self:GetAngle() + self.CookieAngle)
	local fit = self.Radius * 2 / math.max(width, height) * zoom
	local shader = Shadows.CookieShader
	shader:send("Cookie", self.Cookie)
	shader:send("CookiePremultiplied", self.Cookie:typeOf("Canvas"))
	shader:send("DpiScale", require("shadows.DPI").getCanvasScale(self.Canvas))
	shader:send("CookieCenter", {
		x + (c * self.CookieX - s * self.CookieY) * zoom,
		y + (s * self.CookieX + c * self.CookieY) * zoom,
	})
	shader:send("CookieSize", { width * fit * self.CookieScaleX, height * fit * self.CookieScaleY })
	shader:send("CookieRotation", { math.cos(rotation), math.sin(rotation) })
	love.graphics.setShader(shader)
	love.graphics.setBlendMode("multiply", "premultiplied")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("fill", 0, 0, self.Canvas:getDimensions())
	love.graphics.setShader()
end

---@description Draws unshadowed illumination into the active local-light canvas.
---@param z number Light height.
---@return nil
function Light:DrawLight(z)
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
end

---@description Separates geometry, illumination, and filter-setting invalidation.
---@return nil
function Light:UpdateRenderSettings()
	self:UpdatePenumbraSettings()
	local x, y, z = self:GetPosition()
	local angle = self:GetAngle()
	if self.PreviousRadius ~= self.Radius then
		if self.PreviousRadius and not self.Star then self:DestroyCanvas() end
		self.PreviousRadius = self.Radius
		self.Changed = true
	end
	if self.PreviousX ~= x or self.PreviousY ~= y or self.PreviousZ ~= z or self.World.Changed then
		self.Changed = true
	end
	if self.PreviousAngle ~= angle or self.PreviousArc ~= self.Arc then
		self.AppearanceChanged = true
	end
	self.PreviousX, self.PreviousY, self.PreviousZ = x, y, z
	self.PreviousAngle, self.PreviousArc = angle, self.Arc
	self.Transform.HasChanged = false
end

--- @description Invalidates cached rendering when public penumbra settings change.
--- @return nil
function Light:UpdatePenumbraSettings()
	assert(type(self.SizeRadius) == "number" and self.SizeRadius >= 0 and self.SizeRadius < math.huge,
		"SizeRadius must be a finite nonnegative number")
	if self.PreviousBlur ~= self.Blur or self.PreviousSizeRadius ~= self.SizeRadius then
		self.PreviousBlur = self.Blur
		self.PreviousSizeRadius = self.SizeRadius
		self.PenumbraChanged = true
	end
end

--- @description Builds occluder-distance buffers using the current shadow rendering transform.
--- @param Rebuild boolean? Whether shadow pixels changed; defaults to true.
--- @return nil
function Light:GeneratePenumbra(Rebuild)
	if self.Blur and self.SizeRadius > 0 then
		if not self.Penumbra then
			self.Penumbra = require("shadows.Penumbra"):new(
				self.ShadowCanvas, self.Settings.PenumbraScale, self.Settings.ShadowMSAA, self)
			Rebuild = true
		end
		if Rebuild ~= false then
			self.Penumbra:Update(self)
		else
			self.Penumbra:UpdateRadius(self)
		end
	else
		self.Penumbra = nil
	end
end

--- @description Assigns the owning light world.
--- @param World LightWorld Owning world.
--- @return nil
function Light:SetWorld(World)
	self.World = World
	self.Settings = World.Settings
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
		self.AppearanceChanged = true
	end

	if G ~= self.G then
		self.G = G
		self.AppearanceChanged = true
	end

	if B ~= self.B then
		self.B = B
		self.AppearanceChanged = true
	end

	if A ~= nil and A ~= self.A then
		self.A = A
		self.AppearanceChanged = true
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
		self.AppearanceChanged = true
	end
end

--- @description Returns the custom light texture.
--- @return love.Texture? image Custom texture, if configured.
function Light:GetImage()
	return self.Image
end

---@description Sets or clears an illumination cookie without changing the light radius or rebuilding shadows.
---@param Texture love.Texture? Two-dimensional Image or Canvas mask; nil disables cookies. Canvas pixels are premultiplied.
---@return Light light This light, for chaining.
function Light:SetCookie(Texture)
	assert(Texture == nil or (type(Texture) == "userdata" and Texture:typeOf("Texture")
		and Texture:getTextureType() == "2d"), "Cookie must be a two-dimensional texture or nil")
	assert(Texture == nil or Texture ~= self.Canvas, "Cookie cannot sample the light's own illumination canvas")
	if self.Cookie ~= Texture then
		self.Cookie = Texture
		self.AppearanceChanged = true
	end
	return self
end

---@description Returns the optional illumination mask.
---@return love.Texture? texture Cookie texture, or nil when disabled.
function Light:GetCookie()
	return self.Cookie
end

---@description Sets light-relative cookie placement, rotation, and positive scale multipliers without rebuilding shadows.
---@param x number? Local x-offset in world units; defaults to 0.
---@param y number? Local y-offset in world units; defaults to 0.
---@param angle number? Rotation relative to the light in degrees; defaults to 0.
---@param scaleX number? Positive horizontal scale; defaults to 1.
---@param scaleY number? Positive vertical scale; defaults to scaleX.
---@return Light light This light, for chaining.
function Light:SetCookieTransform(x, y, angle, scaleX, scaleY)
	if x == nil then x = 0 end
	if y == nil then y = 0 end
	if angle == nil then angle = 0 end
	if scaleX == nil then scaleX = 1 end
	if scaleY == nil then scaleY = scaleX end
	assert(type(x) == "number" and x > -math.huge and x < math.huge
		and type(y) == "number" and y > -math.huge and y < math.huge
		and type(angle) == "number" and angle > -math.huge and angle < math.huge,
		"Cookie offsets and angle must be finite numbers")
	assert(type(scaleX) == "number" and scaleX > 0 and scaleX < math.huge
		and type(scaleY) == "number" and scaleY > 0 and scaleY < math.huge,
		"Cookie scales must be finite positive numbers")
	if self.CookieX ~= x or self.CookieY ~= y or self.CookieAngle ~= angle
		or self.CookieScaleX ~= scaleX or self.CookieScaleY ~= scaleY then
		self.CookieX, self.CookieY, self.CookieAngle = x, y, angle
		self.CookieScaleX, self.CookieScaleY = scaleX, scaleY
		self.AppearanceChanged = true
	end
	return self
end

---@description Returns the light-relative cookie offset, rotation, and scale multipliers.
---@return number x Local x-offset in world units.
---@return number y Local y-offset in world units.
---@return number angle Rotation relative to the light in degrees.
---@return number scaleX Horizontal scale multiplier.
---@return number scaleY Vertical scale multiplier.
function Light:GetCookieTransform()
	return self.CookieX, self.CookieY, self.CookieAngle, self.CookieScaleX, self.CookieScaleY
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
		self.World:InvalidateLight(self)
		self.World.Lights[self.ID] = nil
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
