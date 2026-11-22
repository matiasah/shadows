---@module Implements a shared full-scene light with independent rendering buffers per LightCamera.
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
--- @field Settings Settings Shared settings object from the owning world.
--- @field ID integer? Index in the world's star collection; absent on private render views.
--- @field Camera LightCamera Viewport rendered by this star or its private render view.
--- @field private Views table<LightCamera, Star> Additional-camera rendering caches.
--- @field private Penumbra Penumbra? Cached occluder-distance filtering buffers.
--- @field Changed boolean? Whether shadow geometry and all rendering stages need regeneration.
--- @field Width number Star canvas width.
--- @field Height number Star canvas height.
--- @field private RenderScale number Resolution scale used by the current canvases.
--- @field private RenderMSAA integer MSAA sample count used by the current shadow canvas.
--- @field private RenderPenumbraScale number Resolution scale used by current penumbra buffers.
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

		self.World = World
		self.Settings = World.Settings
		self.Camera = World:GetCamera()
		self.Views = {}
		self.Transform = Transform:new()
		self.Transform:SetLocalPosition(0, 0, 1)
		self.Transform.Object = self

		self.Radius = Radius
		self.Width = Width
		self.Height = Height
		self.Canvas = self:NewCanvas(Width, Height)
		self.ShadowCanvas = self:NewCanvas(Width, Height, { mipmaps = "manual" })
		self.ShadowCanvas:setMipmapFilter("linear")
		self.ShadowRenderCanvas = self:NewCanvas(Width, Height, { msaa = World.Settings.ShadowMSAA })

		self.Shapes = {}
		self.RenderScale = World.Settings.ShadowScale
		self.RenderMSAA = World.Settings.ShadowMSAA
		self.RenderPenumbraScale = World.Settings.PenumbraScale

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
	local wx, wy, wz = self.Camera:GetPosition()

	return (x - wx) * wz, (y - wy) * wz, z * wz
end

---@description Returns this star's default render cache or allocates an additional camera's private cache.
---@param Camera LightCamera Viewport whose star buffers are requested.
---@return Star view Per-camera renderer sharing the source transform and settings.
function Star:GetView(Camera)
	if Camera == self.Camera then return self end
	local view = self.Views[Camera]
	if not view then
		view = setmetatable({
			World = self.World, Settings = self.Settings, Transform = self.Transform,
			Camera = Camera, Shapes = {}, Views = {},
			Radius = self.Radius,
		}, Star)
		view:Resize(Camera.Width, Camera.Height)
		self.Views[Camera] = view
	end
	return view
end

---@description Refreshes all view caches before consuming source dirty flags; never advances simulation.
---@return nil
function Star:UpdateViews()
	for _, camera in ipairs(self.World.Cameras) do
		if camera ~= self.Camera then
			local start = love.timer.getTime()
			local view = self:GetView(camera)
			view.Radius, view.Arc = self.Radius, self.Arc
			view.Blur, view.SizeRadius = self.Blur, self.SizeRadius
			view:SetColor(self.R, self.G, self.B, self.A)
			view:SetCookie(self.Cookie)
			view:SetCookieTransform(self:GetCookieTransform())
			if view.Image ~= self.Image then
				view.Image = self.Image
				view.AppearanceChanged = true
			end
			view.ShadowChanged = view.ShadowChanged or self.ShadowChanged
			view.AppearanceChanged = view.AppearanceChanged or self.AppearanceChanged
			view:Update()
			local metrics = camera.PendingFrameMetrics
			if metrics then metrics.StarUpdateMs = metrics.StarUpdateMs + (love.timer.getTime() - start) * 1000 end
		end
	end
	local start = love.timer.getTime()
	self:Update()
	local metrics = self.Camera.PendingFrameMetrics
	if metrics then metrics.StarUpdateMs = metrics.StarUpdateMs + (love.timer.getTime() - start) * 1000 end
end

--- @description Regenerates the star's shadow and illumination canvases when dirty.
--- @return nil
function Star:Update()
	self:UpdateRenderSettings()
	if self.Camera.UpdateStars or (self.Camera == self.World.DefaultCamera and self.World.UpdateStars) then
		self.Changed = true
	end

	local shadowChanged = self.Changed or self.ShadowChanged
	if shadowChanged or self.AppearanceChanged or self.PenumbraChanged then
		local x, y, z = self.Transform:GetPosition()
		local wx, wy, wz = self.Camera:GetPosition()

		if shadowChanged or self.PenumbraChanged then
			love.graphics.origin()
			love.graphics.translate(-wx * wz, -wy * wz)
			love.graphics.scale(wz, wz)
			if shadowChanged then self:RenderShadowCanvas(x, y, z) end
			self:GeneratePenumbra(shadowChanged or false)
		end

		-- Now stop using the shadow canvas and generate the light
		love.graphics.setCanvas(self.Canvas)
		love.graphics.setShader()
		love.graphics.clear()
		love.graphics.origin()
		--love.graphics.translate((x - wx - self.Radius) * wz, (y - wy - self.Radius) * wz)

		if self.Image then
			-- If there's a image to be used as light texture, use it
			love.graphics.setBlendMode("lighten", "premultiplied")
			love.graphics.setColor(self.R, self.G, self.B, self.A)
			love.graphics.draw(self.Image, (x - wx) * wz, (y - wy) * wz, 0, wz, wz)
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
			love.graphics.setColor(self.R, self.G, self.B, self.A)
			love.graphics.rectangle("fill", 0, 0, self.Width, self.Height)

			-- Unset the shader
			love.graphics.setShader()
		end

		self:ApplyCookie()
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

		self.Camera.UpdateCanvas = true
		self.Changed = nil
		self.ShadowChanged = nil
		self.AppearanceChanged = nil
		self.PenumbraChanged = nil
	end
end

--- @description Resizes the full-scene star canvases when dimensions differ.
--- @param Width number New canvas width.
--- @param Height number New canvas height.
--- @return nil
function Star:Resize(Width, Height)
	local w, h
	if self.Canvas then w, h = self.Canvas:getDimensions() end

	if Width ~= w or Height ~= h or self.RenderScale ~= self.Settings.ShadowScale
		or self.RenderMSAA ~= self.Settings.ShadowMSAA
		or self.RenderPenumbraScale ~= self.Settings.PenumbraScale then
		self.Width = Width
		self.Height = Height
		self.Canvas = self:NewCanvas(Width, Height)
		self.ShadowCanvas = self:NewCanvas(Width, Height, { mipmaps = "manual" })
		self.ShadowCanvas:setMipmapFilter("linear")
		self.ShadowRenderCanvas = self:NewCanvas(Width, Height, { msaa = self.Settings.ShadowMSAA })
		self.Penumbra = nil
		self.Changed = true
		self.RenderScale = self.Settings.ShadowScale
		self.RenderMSAA = self.Settings.ShadowMSAA
		self.RenderPenumbraScale = self.Settings.PenumbraScale
	end
end

--- @description Removes the star from its world's star collection.
--- @return nil
function Star:Remove()
	self.World.Stars[self.ID] = nil
	self.World.UpdateCanvas = true
	self.Views = {}

	self.Transform:SetParent(nil)
end

return Star
