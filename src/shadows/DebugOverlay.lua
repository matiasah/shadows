---@module Draws lighting diagnostics from existing scene objects and caches without regenerating shadows.
local Object = require("shadows.Object")

---@class DebugStats
---@field LocalLights integer Registered shared local lights, including particle lights.
---@field LocalCanvases integer Local lights with allocated illumination caches.
---@field Stars integer Registered stars.
---@field ShadowRedraws integer Lifetime redraws across local lights and this camera's existing star renderers.
---@field GeometryRebuilds integer Lifetime shape/layer geometry generations across those renderers.
---@field CachedDrawCalls integer Deferred shadow draws currently cached by those renderers.

---@class DebugFrameStats
---@field Camera CameraFrameMetrics Read-only snapshot of the selected camera's last completed update.
---@field Shared WorldFrameMetrics Read-only shared local-light snapshot, reported once per world rather than charged per camera.

---@class DebugOverlay:Object
---@field World LightWorld Scene whose diagnostics are drawn.
---@field LightBounds boolean Draw source positions, influence circles, and cone directions; defaults to true.
---@field ShadowGeometry boolean Draw occluder outlines and cached shadow draw-call wireframes; defaults to true.
---@field CameraViewports boolean Draw registered camera world bounds; defaults to true.
---@field CacheCounters boolean Draw completed per-frame camera/shared work and current cache counts; defaults to true.
---@field CumulativeTotals boolean Append lifetime redraw/rebuild counters; defaults to false.
---@field private __index DebugOverlay Instance method lookup.
---@field private __type string Runtime type name.
local DebugOverlay = setmetatable({}, Object)
DebugOverlay.__index = DebugOverlay
DebugOverlay.__type = "DebugOverlay"

---@description Resolves a diagnostic camera and validates that it remains attached to this world.
---@param world LightWorld Scene being inspected.
---@param camera LightCamera? Requested view; defaults to the world's default camera.
---@return LightCamera camera Attached view from this world.
local function resolveCamera(world, camera)
    camera = camera or world:GetCamera()
    assert(camera.World == world and not camera.Removed,
        "DebugOverlay requires an attached camera from its world")
    return camera
end

---@description Returns an existing star view without allocating buffers for diagnostics.
---@param star Star Source star.
---@param camera LightCamera Requested camera.
---@return Star? view Existing renderer, or nil before its first world update.
local function getStarView(star, camera)
    if star.Camera == camera then return star end
    return star.Views[camera]
end

---@description Outlines a cached built-in draw call without applying its shader or changing its arguments.
---@param output OutputShadow Cached deferred shadow draw.
---@return nil
local function drawOutput(output)
    local input = output.Input
    if output.Type == "polygon" then
        love.graphics.polygon("line", type(input[1]) == "table" and input[1] or input)
    elseif output.Type == "circle" then
        love.graphics.circle("line", unpack(input))
    elseif output.Type == "rectangle" then
        love.graphics.rectangle("line", unpack(input))
    elseif output.Type == "draw" then
        local texture = input[1]
        assert(texture and texture:typeOf("Texture"),
            "DebugOverlay supports texture bounds for cached draw operations")
        love.graphics.push()
        love.graphics.translate(input[2] or 0, input[3] or 0)
        love.graphics.rotate(input[4] or 0)
        love.graphics.scale(input[5] or 1, input[6] or input[5] or 1)
        love.graphics.shear(input[9] or 0, input[10] or 0)
        love.graphics.rectangle("line", -(input[7] or 0), -(input[8] or 0), texture:getDimensions())
        love.graphics.pop()
    else
        error("DebugOverlay does not support cached draw operation: " .. tostring(output.Type))
    end
end

---@description Outlines all currently cached shadow draw calls for one renderer.
---@param light Light|Star Renderer whose cached geometry is inspected.
---@return nil
local function drawCachedGeometry(light)
    for _, bodies in pairs(light.Shapes or {}) do
        for _, shapes in pairs(bodies) do
            for _, outputs in pairs(shapes) do
                for _, output in ipairs(outputs) do drawOutput(output) end
            end
        end
    end
end

---@description Outlines built-in occluders; textured and custom shapes use drawable bounds rather than alpha contours.
---@param shape CircleShadow|PolygonShadow|ImageShadow|NormalShadow|HeightShadow|CastImageShadow Occluder being inspected.
---@return nil
local function drawOccluder(shape)
    local x, y, z = shape:GetTransform():GetPosition()
    if shape.__type == "PolygonShadow" then
        love.graphics.polygon("line", shape:GetVertices())
    elseif shape.__type == "CastImageShadow" then
        local width, height = shape:GetWidth(), shape:GetHeight()
        local angle = shape:GetTransform():GetRadians()
        local dx, dy = width * 0.5 * math.cos(angle), width * 0.5 * math.sin(angle)
        love.graphics.polygon("line",
            x - dx, y - dy - z - height, x + dx, y + dy - z - height,
            x + dx, y + dy - z, x - dx, y - dy - z)
    elseif shape.Texture then
        love.graphics.push()
        love.graphics.translate(x, y)
        love.graphics.rotate(shape:GetTransform():GetRadians())
        love.graphics.rectangle("line", 0, 0, shape:GetWidth(), shape:GetHeight())
        love.graphics.pop()
    else
        love.graphics.circle("line", x, y, shape:GetRadius())
    end
end

---@description Adds a renderer's cumulative work and cached draw-call count to a statistics record.
---@param stats DebugStats Record being accumulated.
---@param light Light|Star Renderer being inspected.
---@return nil
local function addStats(stats, light)
    local redraws, rebuilds = light:GetDebugCounts()
    stats.ShadowRedraws = stats.ShadowRedraws + redraws
    stats.GeometryRebuilds = stats.GeometryRebuilds + rebuilds
    for _, bodies in pairs(light.Shapes or {}) do
        for _, shapes in pairs(bodies) do
            for _, outputs in pairs(shapes) do
                stats.CachedDrawCalls = stats.CachedDrawCalls + #outputs
            end
        end
    end
end

---@description Draws a source marker, radius bound, heading, cone edges, and identifier.
---@param light Light|Star Source being inspected.
---@param zoom number Camera scale used to keep markers readable.
---@return nil
local function drawLightBounds(light, zoom)
    local x, y = light:GetPosition()
    local angle = math.rad(light:GetAngle()) - math.pi * 0.5
    local radius = light:GetRadius()
    love.graphics.setColor(light.Star and 0.9 or 1, light.Star and 0.5 or 0.75, 0.2,
        light:GetCanvasDestroyed() and 0.4 or 0.9)
    love.graphics.circle("line", x, y, radius)
    love.graphics.circle("line", x, y, 4 / zoom)
    local length = math.min(radius, 28 / zoom)
    love.graphics.line(x, y, x + math.cos(angle) * length, y + math.sin(angle) * length)
    if not light.Star and light.Arc < 360 then
        local arc = math.rad(light.Arc * 0.5)
        for _, edge in ipairs({ angle - arc, angle + arc }) do
            love.graphics.line(x, y, x + math.cos(edge) * radius, y + math.sin(edge) * radius)
        end
    end
    love.graphics.print((light.Star and "Star " or "Light ") .. tostring(light.ID),
        x + 7 / zoom, y + 5 / zoom, 0, 1 / zoom, 1 / zoom)
end

---@description Creates draw-only scene diagnostics with all four categories enabled.
---@param World LightWorld Scene to inspect.
---@return DebugOverlay overlay New diagnostic overlay.
function DebugOverlay:new(World)
    assert(World and World.Cameras and World.Lights, "DebugOverlay requires a LightWorld")
    return setmetatable({
        World = World,
        LightBounds = true,
        ShadowGeometry = true,
        CameraViewports = true,
        CacheCounters = true,
        CumulativeTotals = false,
    }, DebugOverlay)
end

---@description Returns counters for shared locals and a camera's existing star views without allocating caches.
---@param Camera LightCamera? View to inspect; defaults to the world's default camera.
---@return DebugStats stats Current cumulative work and cache sizes.
function DebugOverlay:GetStats(Camera)
    Camera = resolveCamera(self.World, Camera)
    local stats = {
        LocalLights = 0, LocalCanvases = 0, Stars = 0,
        ShadowRedraws = 0, GeometryRebuilds = 0, CachedDrawCalls = 0,
    }
    for _, light in pairs(self.World.Lights) do
        stats.LocalLights = stats.LocalLights + 1
        if not light:GetCanvasDestroyed() then stats.LocalCanvases = stats.LocalCanvases + 1 end
        addStats(stats, light)
    end

    ---@description Returns stable completed-update camera and shared metrics without resetting or sampling counters.
    ---@param Camera LightCamera? View to inspect; defaults to the world's default camera.
    ---@return DebugFrameStats stats Read-only snapshots; replaced on the next completed world update.
    function DebugOverlay:GetFrameStats(Camera)
        Camera = resolveCamera(self.World, Camera)
        return { Camera = Camera.FrameMetrics, Shared = self.World.FrameMetrics }
    end
    for _, star in pairs(self.World.Stars) do
        stats.Stars = stats.Stars + 1
        local view = getStarView(star, Camera)
        if view then addStats(stats, view) end
    end
    return stats
end

---@description Draws overlays after scene lighting, clipped to the camera viewport and preserving graphics state.
---@param Camera LightCamera? Camera whose transform is used; defaults to the world's default camera.
---@param screenX number? Screen-space viewport left edge; defaults to 0.
---@param screenY number? Screen-space viewport top edge; defaults to 0.
---@return nil
function DebugOverlay:Draw(Camera, screenX, screenY)
    Camera = resolveCamera(self.World, Camera)
    screenX, screenY = screenX or 0, screenY or 0
    local x, y, zoom = Camera:GetPosition()
    love.graphics.push("all")
    local sx, sy, sw, sh = love.graphics.getScissor()
    local left, top = screenX, screenY
    local right, bottom = screenX + Camera.Width, screenY + Camera.Height
    if sx then
        left, top = math.max(left, sx), math.max(top, sy)
        right, bottom = math.min(right, sx + sw), math.min(bottom, sy + sh)
    end
    love.graphics.setScissor(left, top, math.max(0, right - left), math.max(0, bottom - top))
    love.graphics.setStencilTest()
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setLineStyle("smooth")
    love.graphics.setLineWidth(1.5 / zoom)
    love.graphics.origin()
    love.graphics.translate(screenX, screenY)
    love.graphics.scale(zoom, zoom)
    love.graphics.translate(-x, -y)

    if self.ShadowGeometry then
        love.graphics.setColor(1, 0.25, 0.35, 0.75)
        for _, light in pairs(self.World.Lights) do drawCachedGeometry(light) end
        for _, star in pairs(self.World.Stars) do
            local view = getStarView(star, Camera)
            if view then drawCachedGeometry(view) end
        end
        love.graphics.setColor(0.2, 1, 0.45, 1)
        for _, body in ipairs(self.World.Bodies:GetArray()) do
            for _, shape in ipairs(body:GetShapes():GetArray()) do drawOccluder(shape) end
        end
    end
    if self.LightBounds then
        for _, light in pairs(self.World.Lights) do drawLightBounds(light, zoom) end
        for _, star in pairs(self.World.Stars) do drawLightBounds(star, zoom) end
    end
    if self.CameraViewports then
        for index, camera in ipairs(self.World.Cameras) do
            local cx, cy, scale = camera:GetPosition()
            love.graphics.setColor(0.25, 0.8, 1, 1)
            love.graphics.rectangle("line", cx, cy, camera.Width / scale, camera.Height / scale)
            love.graphics.print("Camera " .. index, cx + 5 / zoom, cy + 5 / zoom, 0, 1 / zoom, 1 / zoom)
        end
    end
    if self.CacheCounters then
        local stats = self:GetStats(Camera)
        local frame = self:GetFrameStats(Camera)
        local camera, shared = frame.Camera, frame.Shared
        local text = string.format(
            "Frame %d | camera CPU %.3f ms\nStar %.3f / compose %.3f ms\nStar redraw %d / geo %d / draws %d\nComposited %d | new canvases %d\nShared locals (world): %.3f ms\nRedraw %d / geo %d / draws %d / new %d\nCaches: locals %d/%d | stars %d | draws %d",
            camera.Frame, camera.StarUpdateMs + camera.CompositionMs,
            camera.StarUpdateMs, camera.CompositionMs,
            camera.ShadowRedraws, camera.GeometryRebuilds, camera.ShadowDrawCalls,
            camera.LightsComposited, camera.CanvasAllocations,
            shared.SharedUpdateMs, shared.ShadowRedraws, shared.GeometryRebuilds,
            shared.ShadowDrawCalls, shared.CanvasAllocations,
            stats.LocalCanvases, stats.LocalLights, stats.Stars, stats.CachedDrawCalls)
        if self.CumulativeTotals then
            text = text .. string.format("\nLifetime: redraw %d / geometry %d", stats.ShadowRedraws, stats.GeometryRebuilds)
        end
        local _, lines = love.graphics.getFont():getWrap(text, math.max(1, Camera.Width - 32))
        love.graphics.origin()
        love.graphics.setColor(0.02, 0.02, 0.04, 0.9)
        love.graphics.rectangle("fill", screenX + 8, screenY + 26,
            math.max(1, Camera.Width - 16), #lines * love.graphics.getFont():getHeight() + 12)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(text, screenX + 14, screenY + 32, math.max(1, Camera.Width - 28))
    end
    love.graphics.pop()
end

return DebugOverlay
