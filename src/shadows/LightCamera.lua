---@module Provides independent lighting viewports into a shared LightWorld.
local Object = require("shadows.Object")
local Shadows = require("shadows")
local Transform = require("shadows.Transform")
local Mask = require("shadows.Mask")

---@class CameraFrameMetrics:RenderWorkMetrics
---@field Frame integer World-update sequence number; initially 0.
---@field StarUpdateMs number CPU milliseconds spent updating this camera's star renderers.
---@field CompositionMs number CPU milliseconds spent composing lighting; 0 when the cached composition is reused.
---@field LightsComposited integer Local/star canvas draw submissions during composition; 0 when reused.

---@class LightCamera:Object
---@field World LightWorld Owning scene; simulation and rendering settings are shared.
---@field Settings Settings Shared world rendering settings.
---@field LightMask integer Selected light groups; defaults to Mask.ALL. Use SetLightMask.
---@field Canvas love.Canvas Composed lighting for this viewport.
---@field Width number Viewport width in logical pixels.
---@field Height number Viewport height in logical pixels.
---@field BorderRadius number Half-diagonal of the viewport in logical pixels.
---@field Transform Transform Hierarchical camera position; height and rotation do not alter the viewport.
---@field x number Last synchronized world-space left edge; defaults to 0.
---@field y number Last synchronized world-space top edge; defaults to 0.
---@field z number Positive world-to-viewport scale, independent of transform height; defaults to 1.
---@field FrameMetrics CameraFrameMetrics Work for this camera in the most recent world update; read-only.
---@field private PendingFrameMetrics CameraFrameMetrics? In-progress metrics, published only after the world update completes.
---@field private CanvasAllocationCount integer Successful composition-canvas allocations; defaults to 0.
---@field private SampledCanvasAllocationCount integer Allocations sampled by the previous world update; defaults to 0.
---@field private CompositedLights table<Light, boolean> Local lights included in this camera's last composition.
---@field private ReceiverCanvases table<integer, { Canvas: love.Canvas? }> Cached lighting passes requested by receiver mask.
---@field private UpdateCanvas boolean? Whether composition needs refreshing.
---@field private UpdateStars boolean? Whether view-dependent star shadows need refreshing.
---@field private Removed boolean? Whether this camera is detached.
---@field private __index LightCamera Instance method lookup.
---@field private __type string Runtime type name.
local LightCamera = setmetatable({}, Object)
LightCamera.__index = LightCamera
LightCamera.__type = "LightCamera"
LightCamera.LightMask = Mask.ALL

---@description Creates an empty per-camera metric bucket for an update sequence number.
---@param Frame integer Update sequence number.
---@return CameraFrameMetrics metrics Empty per-camera work metrics.
local function newFrameMetrics(Frame)
    return {
        Frame = Frame, StarUpdateMs = 0, CompositionMs = 0, LightsComposited = 0,
        ShadowRedraws = 0, GeometryRebuilds = 0, ShadowDrawCalls = 0,
        CanvasAllocations = 0,
    }
end

---@description Validates a positive integer viewport dimension before allocating graphics resources.
---@param value number Requested logical dimension.
---@return nil
local function validateDimension(value)
    assert(type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0,
        "LightCamera dimensions must be finite positive integers")
end

---@description Validates finite world-space camera coordinates.
---@param x number World x-coordinate.
---@param y number World y-coordinate.
---@return nil
local function validatePosition(x, y)
    assert(type(x) == "number" and x > -math.huge and x < math.huge
        and type(y) == "number" and y > -math.huge and y < math.huge,
        "LightCamera position must be finite")
end

---@description Allocates a cached lighting canvas for one receiver mask.
---@param Camera LightCamera Camera owning the receiver pass.
---@return love.Canvas canvas New receiver lighting canvas.
local function newReceiverCanvas(Camera)
    local canvas = love.graphics.newCanvas(Camera.Width, Camera.Height,
        { dpiscale = Camera.Settings.ShadowScale })
    Camera.CanvasAllocationCount = Camera.CanvasAllocationCount + 1
    return canvas
end

---@description Composes ambient, rooms, and only the lights accepted by both masks.
---@param Camera LightCamera Camera whose viewport is being composed.
---@param Canvas love.Canvas Destination lighting canvas.
---@param ReceiverMask integer Light groups that may illuminate this receiver pass.
---@param Metrics CameraFrameMetrics? In-progress metrics; omitted outside world updates.
---@return table<Light, boolean> compositedLights Local lights submitted to this canvas.
local function composeCanvas(Camera, Canvas, ReceiverMask, Metrics)
    local start = love.timer.getTime()
    local world = Camera.World
    love.graphics.push("all")
    love.graphics.setCanvas(Canvas)
    love.graphics.setScissor()
    love.graphics.setStencilTest()
    love.graphics.setShader()
    love.graphics.origin()
    love.graphics.clear(world.R, world.G, world.B, world.A)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("add", "alphamultiply")
    for _, star in pairs(world.Stars) do
        if Camera:AcceptsLight(star) and Mask.matches(ReceiverMask, star.LightMask) then
            local view = star:GetView(Camera)
            if not view:GetCanvasDestroyed() then
                love.graphics.draw(view.Canvas, 0, 0)
                if Metrics then Metrics.LightsComposited = Metrics.LightsComposited + 1 end
            end
        end
    end
    love.graphics.translate(-Camera.x * Camera.z, -Camera.y * Camera.z)
    love.graphics.scale(Camera.z, Camera.z)
    love.graphics.setShader(Shadows.DarkenShader)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    for _, room in pairs(world.Rooms) do room:Draw() end
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("add", "alphamultiply")
    local compositedLights = {}
    for _, light in pairs(world.Lights) do
        if not light:GetCanvasDestroyed() and Mask.matches(ReceiverMask, light.LightMask)
            and Camera:IsLightVisible(light) then
            local x, y = light:GetPosition()
            love.graphics.draw(light.Canvas, x - light.Radius, y - light.Radius)
            compositedLights[light] = true
            if Metrics then Metrics.LightsComposited = Metrics.LightsComposited + 1 end
        end
    end
    love.graphics.pop()
    if Metrics then Metrics.CompositionMs = Metrics.CompositionMs + (love.timer.getTime() - start) * 1000 end
    return compositedLights
end

---@description Returns a cached receiver lighting pass, composing it on first use.
---@param Camera LightCamera Camera owning the receiver pass.
---@param ReceiverMask integer Light groups that may illuminate this receiver.
---@return love.Canvas canvas Lighting for this receiver mask.
local function getReceiverCanvas(Camera, ReceiverMask)
    if ReceiverMask == Camera.LightMask then return Camera.Canvas end
    local entry = Camera.ReceiverCanvases[ReceiverMask]
    if not entry then
        entry = { Canvas = newReceiverCanvas(Camera) }
        Camera.ReceiverCanvases[ReceiverMask] = entry
        composeCanvas(Camera, entry.Canvas, ReceiverMask, Camera.PendingFrameMetrics)
    elseif not entry.Canvas then
        entry.Canvas = newReceiverCanvas(Camera)
        composeCanvas(Camera, entry.Canvas, ReceiverMask, Camera.PendingFrameMetrics)
    end
    return entry.Canvas
end

---@description Multiplies a lighting canvas onto the current target in screen coordinates.
---@param Canvas love.Canvas Lighting source.
---@param x number? Screen destination x-coordinate; defaults to 0.
---@param y number? Screen destination y-coordinate; defaults to 0.
---@return nil
local function drawLightingCanvas(Canvas, x, y)
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setShader()
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(Canvas, x or 0, y or 0)
    love.graphics.pop()
end

---@description Creates and registers a viewport; the world's first camera becomes its default.
---@param World LightWorld Scene to view.
---@param Width number? Logical width; defaults to the world's width or display width.
---@param Height number? Logical height; defaults to the world's height or display height.
---@return LightCamera camera Registered lighting camera.
function LightCamera:new(World, Width, Height)
    assert(World and World.Cameras and World.Settings, "LightCamera requires a LightWorld")
    local displayWidth, displayHeight = love.graphics.getDimensions()
    if Width == nil then Width = World.Width or displayWidth end
    if Height == nil then Height = World.Height or displayHeight end
    validateDimension(Width)
    validateDimension(Height)
    local camera = setmetatable({
        World = World,
        Settings = World.Settings,
        Transform = Transform:new(),
        FrameMetrics = newFrameMetrics(0),
        CanvasAllocationCount = 0, SampledCanvasAllocationCount = 0,
        CompositedLights = {}, ReceiverCanvases = {},
        x = 0, y = 0, z = 1,
    }, LightCamera)
    camera.Transform.Object = camera
    if not World.DefaultCamera then World.DefaultCamera = camera end
    World.Cameras[#World.Cameras + 1] = camera
    camera:Resize(Width, Height)
    return camera
end

---@description Starts an in-progress world-update metric bucket without changing the previous completed snapshot.
---@param Frame integer Current world-update sequence number.
---@return nil
function LightCamera:BeginFrame(Frame)
    self.PendingFrameMetrics = newFrameMetrics(Frame)
end

---@description Publishes completed camera metrics, including composition allocations made since the previous update.
---@return nil
function LightCamera:EndFrame()
    local metrics = self.PendingFrameMetrics
    assert(metrics, "LightCamera frame metrics must be started before publishing")
    metrics.CanvasAllocations = metrics.CanvasAllocations
        + self.CanvasAllocationCount - self.SampledCanvasAllocationCount
    self.SampledCanvasAllocationCount = self.CanvasAllocationCount
    self.FrameMetrics = metrics
    self.PendingFrameMetrics = nil
end

---@description Synchronizes inherited translation and invalidates view-dependent rendering when it changes.
---@return nil
function LightCamera:UpdateTransform()
    local x, y = self.Transform:GetPosition()
    validatePosition(x, y)
    if self.x ~= x or self.y ~= y then
        self.x, self.y = x, y
        self.UpdateCanvas, self.UpdateStars = true, true
        self:SyncWorld()
    end
    self.Transform.HasChanged = false
end

---@description Keeps legacy world viewport fields aligned with the default camera.
---@return nil
function LightCamera:SyncWorld()
    if self == self.World.DefaultCamera then
        local world = self.World
        world.Canvas, world.Width, world.Height = self.Canvas, self.Width, self.Height
        world.BorderRadius = self.BorderRadius
        world.x, world.y, world.z = self.x, self.y, self.z
    end
end

---@description Recreates this viewport and its star buffers without resizing other cameras.
---@param Width number New logical width.
---@param Height number New logical height.
---@return nil
function LightCamera:Resize(Width, Height)
    assert(not self.Removed, "Cannot resize a removed LightCamera")
    validateDimension(Width)
    validateDimension(Height)
    self.Canvas = love.graphics.newCanvas(Width, Height, { dpiscale = self.Settings.ShadowScale })
    self.CanvasAllocationCount = self.CanvasAllocationCount + 1
    self.Width, self.Height = Width, Height
    self.BorderRadius = math.sqrt(Width * Width + Height * Height) * 0.5
    self.UpdateCanvas, self.UpdateStars = true, true
    for _, entry in pairs(self.ReceiverCanvases) do entry.Canvas = nil end
    self:SyncWorld()
    for _, star in pairs(self.World.Stars) do
        if self:AcceptsLight(star) or star.Camera == self or star.Views[self] then
            star:GetView(self):Resize(Width, Height)
        end
    end
end

---@description Sets this view's world-space top-left and zoom without changing the scene.
---@param x number Finite world x-coordinate.
---@param y number Finite world y-coordinate.
---@param z number? Positive scale; defaults to the current scale.
---@return nil
function LightCamera:SetPosition(x, y, z)
    assert(not self.Removed, "Cannot move a removed LightCamera")
    validatePosition(x, y)
    if z == nil then z = self.z end
    assert(type(z) == "number" and z > 0 and z < math.huge,
        "LightCamera scale must be finite and positive")
    local _, _, height = self.Transform:GetPosition()
    self.Transform:SetPosition(x, y, height)
    self:UpdateTransform()
    if self.z ~= z then
        self.z = z
        self.UpdateCanvas, self.UpdateStars = true, true
        self:SyncWorld()
    end
end

---@description Returns the world-space top-left and zoom.
---@return number x World x-coordinate.
---@return number y World y-coordinate.
---@return number z World-to-viewport scale.
function LightCamera:GetPosition()
    self:UpdateTransform()
    return self.x, self.y, self.z
end

---@description Returns the camera transform for parent-relative positioning and following scene objects.
---@return Transform transform Hierarchical position transform; zoom remains separate.
function LightCamera:GetTransform()
    return self.Transform
end

---@description Returns the viewport's logical width.
---@return number width Logical width.
function LightCamera:GetWidth()
    return self.Width
end

---@description Returns the viewport's logical height.
---@return number height Logical height.
function LightCamera:GetHeight()
    return self.Height
end

---@description Returns the viewport's logical half-diagonal.
---@return number radius Half-diagonal in logical pixels.
function LightCamera:GetBorderRadius()
    return self.BorderRadius
end

---@description Tests a world-space light circle against this viewport, accounting for zoom.
---@param x number Light world x-coordinate.
---@param y number Light world y-coordinate.
---@param radius number Light radius in world units.
---@return boolean visible Whether the circle intersects the viewport.
function LightCamera:IsVisible(x, y, radius)
    local cx, cy, zoom = self:GetPosition()
    local dx = math.max(cx - x, 0, x - cx - self.Width / zoom)
    local dy = math.max(cy - y, 0, y - cy - self.Height / zoom)
    return dx * dx + dy * dy <= radius * radius
end

---@description Selects light groups for this viewport without changing other cameras or shadow geometry.
---@param mask integer Unsigned 32-bit selection mask; 0 displays only ambient color and rooms.
---@return LightCamera camera This camera, for chaining.
function LightCamera:SetLightMask(mask)
    assert(not self.Removed, "Cannot change a removed LightCamera")
    mask = Mask.validate(mask)
    if self.LightMask ~= mask then
        self.LightMask = mask
        self.UpdateCanvas = true
    end
    return self
end

---@description Returns the light groups selected by this camera.
---@return integer mask Unsigned selection mask.
function LightCamera:GetLightMask()
    return self.LightMask
end

---@description Tests group membership independently of local-light bounds or star projection.
---@param Light Light|Star Light being selected.
---@return boolean accepted Whether the camera and light share a group.
function LightCamera:AcceptsLight(Light)
    return Mask.matches(self.LightMask, Light.LightMask)
end

---@description Tests camera-selected local-light canvas bounds, including texture and particle corners.
---@param Light Light Local light whose existing or prospective canvas is tested.
---@return boolean visible Whether the canvas bounds intersect the viewport.
function LightCamera:IsLightVisible(Light)
    if not self:AcceptsLight(Light) then return false end
    local cx, cy, zoom = self:GetPosition()
    local x, y = Light:GetPosition()
    local width, height = Light.Radius * 2, Light.Radius * 2
    if Light.Canvas then width, height = Light.Canvas:getDimensions() end
    x, y = x - Light.Radius, y - Light.Radius
    return x + width >= cx and y + height >= cy
        and x <= cx + self.Width / zoom and y <= cy + self.Height / zoom
end

---@description Composes cached illumination and rooms; called by the world's update, never advances simulation.
---@return nil
function LightCamera:Compose()
    self:UpdateTransform()
    if not self.UpdateCanvas and not self.World.UpdateCanvas then return end
    local metrics = self.PendingFrameMetrics
    self.CompositedLights = composeCanvas(self, self.Canvas, self.LightMask, metrics)
    for mask, entry in pairs(self.ReceiverCanvases) do
        if mask ~= self.LightMask then
            if not entry.Canvas then entry.Canvas = newReceiverCanvas(self) end
            composeCanvas(self, entry.Canvas, mask, metrics)
        end
    end
    self.UpdateCanvas, self.UpdateStars = nil, nil
end

---@description Lights a separately rendered receiver layer and alpha-composites it onto the current target.
---@param mask integer Unsigned receiver groups; a light must match both this mask and the camera's LightMask.
---@param ReceiverCanvas love.Canvas Unlit receiver layer matching this camera's viewport.
---@param x number? Screen destination x-coordinate; defaults to 0.
---@param y number? Screen destination y-coordinate; defaults to 0.
---@return nil
function LightCamera:DrawReceiverLayer(mask, ReceiverCanvas, x, y)
    assert(not self.Removed, "Cannot draw from a removed LightCamera")
    mask = Mask.validate(mask)
    assert(type(ReceiverCanvas) == "userdata" and ReceiverCanvas:typeOf("Canvas"),
        "Receiver layer must be a LOVE Canvas")
    self:Compose()
    Shadows.ReceiverShader:send("Lighting", getReceiverCanvas(self, mask))
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setShader(Shadows.ReceiverShader)
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(ReceiverCanvas, x or 0, y or 0)
    love.graphics.pop()
end

---@description Releases the cached lighting pass for a receiver mask.
---@param mask integer Unsigned receiver groups previously passed to DrawReceiverLayer.
---@return LightCamera camera This camera, for chaining.
function LightCamera:ReleaseReceiverMask(mask)
    assert(not self.Removed, "Cannot change a removed LightCamera")
    mask = Mask.validate(mask)
    self.ReceiverCanvases[mask] = nil
    return self
end

---@description Multiplies cached lighting onto a scene viewport in screen coordinates, preserving graphics state.
---@param x number? Screen destination x-coordinate; defaults to 0.
---@param y number? Screen destination y-coordinate; defaults to 0.
---@return nil
function LightCamera:Draw(x, y)
    assert(not self.Removed, "Cannot draw a removed LightCamera")
    drawLightingCanvas(self.Canvas, x, y)
end

---@description Detaches an additional camera and drops its per-star caches; the default cannot be removed.
---@return nil
function LightCamera:Remove()
    assert(self ~= self.World.DefaultCamera, "Cannot remove the default LightCamera")
    if self.Removed then return end
    for index, camera in ipairs(self.World.Cameras) do
        if camera == self then
            table.remove(self.World.Cameras, index)
            break
        end
    end
    for _, star in pairs(self.World.Stars) do star.Views[self] = nil end
    self.CompositedLights = {}
    self.ReceiverCanvases = {}
    self.Transform:SetParent(nil)
    self.Removed = true
end

return LightCamera
