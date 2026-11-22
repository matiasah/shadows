---@module Provides independent lighting viewports into a shared LightWorld.
local Object = require("shadows.Object")
local Shadows = require("shadows")

---@class LightCamera:Object
---@field World LightWorld Owning scene; simulation and rendering settings are shared.
---@field Settings Settings Shared world rendering settings.
---@field Canvas love.Canvas Composed lighting for this viewport.
---@field Width number Viewport width in logical pixels.
---@field Height number Viewport height in logical pixels.
---@field BorderRadius number Half-diagonal of the viewport in logical pixels.
---@field x number World-space left edge; defaults to 0.
---@field y number World-space top edge; defaults to 0.
---@field z number Positive world-to-viewport scale; defaults to 1.
---@field private UpdateCanvas boolean? Whether composition needs refreshing.
---@field private UpdateStars boolean? Whether view-dependent star shadows need refreshing.
---@field private Removed boolean? Whether this camera is detached.
---@field private __index LightCamera Instance method lookup.
---@field private __type string Runtime type name.
local LightCamera = setmetatable({}, Object)
LightCamera.__index = LightCamera
LightCamera.__type = "LightCamera"

---@description Validates a positive integer viewport dimension before allocating graphics resources.
---@param value number Requested logical dimension.
---@return nil
local function validateDimension(value)
    assert(type(value) == "number" and value > 0 and value < math.huge and value % 1 == 0,
        "LightCamera dimensions must be finite positive integers")
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
        x = 0, y = 0, z = 1,
    }, LightCamera)
    if not World.DefaultCamera then World.DefaultCamera = camera end
    World.Cameras[#World.Cameras + 1] = camera
    camera:Resize(Width, Height)
    return camera
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
    self.Width, self.Height = Width, Height
    self.BorderRadius = math.sqrt(Width * Width + Height * Height) * 0.5
    self.UpdateCanvas, self.UpdateStars = true, true
    self:SyncWorld()
    for _, star in pairs(self.World.Stars) do
        star:GetView(self):Resize(Width, Height)
    end
end

---@description Sets this view's world-space top-left and zoom without changing the scene.
---@param x number Finite world x-coordinate.
---@param y number Finite world y-coordinate.
---@param z number? Positive scale; defaults to the current scale.
---@return nil
function LightCamera:SetPosition(x, y, z)
    assert(not self.Removed, "Cannot move a removed LightCamera")
    assert(type(x) == "number" and x > -math.huge and x < math.huge
        and type(y) == "number" and y > -math.huge and y < math.huge,
        "LightCamera position must be finite")
    if z == nil then z = self.z end
    assert(type(z) == "number" and z > 0 and z < math.huge,
        "LightCamera scale must be finite and positive")
    if self.x ~= x or self.y ~= y or self.z ~= z then
        self.x, self.y, self.z = x, y, z
        self.UpdateCanvas, self.UpdateStars = true, true
        self:SyncWorld()
    end
end

---@description Returns the world-space top-left and zoom.
---@return number x World x-coordinate.
---@return number y World y-coordinate.
---@return number z World-to-viewport scale.
function LightCamera:GetPosition()
    return self.x, self.y, self.z
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
    local dx = math.max(self.x - x, 0, x - self.x - self.Width / self.z)
    local dy = math.max(self.y - y, 0, y - self.y - self.Height / self.z)
    return dx * dx + dy * dy <= radius * radius
end

---@description Composes cached illumination and rooms; called by the world's update, never advances simulation.
---@return nil
function LightCamera:Compose()
    if not self.UpdateCanvas and not self.World.UpdateCanvas then return end
    local world = self.World
    love.graphics.push("all")
    love.graphics.setCanvas(self.Canvas)
    love.graphics.setScissor()
    love.graphics.setStencilTest()
    love.graphics.setShader()
    love.graphics.origin()
    love.graphics.clear(world.R, world.G, world.B, world.A)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("add", "alphamultiply")
    for _, star in pairs(world.Stars) do
        local view = star:GetView(self)
        if not view:GetCanvasDestroyed() then love.graphics.draw(view.Canvas, 0, 0) end
    end
    love.graphics.translate(-self.x * self.z, -self.y * self.z)
    love.graphics.scale(self.z, self.z)
    love.graphics.setShader(Shadows.DarkenShader)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    for _, room in pairs(world.Rooms) do room:Draw() end
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("add", "alphamultiply")
    for _, light in pairs(world.Lights) do
        if not light:GetCanvasDestroyed() then
            local x, y = light:GetPosition()
            love.graphics.draw(light.Canvas, x - light.Radius, y - light.Radius)
        end
    end
    love.graphics.pop()
    self.UpdateCanvas, self.UpdateStars = nil, nil
end

---@description Multiplies cached lighting onto a scene viewport in screen coordinates, preserving graphics state.
---@param x number? Screen destination x-coordinate; defaults to 0.
---@param y number? Screen destination y-coordinate; defaults to 0.
---@return nil
function LightCamera:Draw(x, y)
    assert(not self.Removed, "Cannot draw a removed LightCamera")
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setShader()
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.Canvas, x or 0, y or 0)
    love.graphics.pop()
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
    self.Removed = true
    self.World.UpdateCanvas = true
end

return LightCamera
