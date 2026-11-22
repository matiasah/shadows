---@module Demonstrates lighting diagnostics, cached shadow geometry, and multiple camera bounds.
local capture = require("Capture").new("debug-overlay-capture.png")
local LightWorld = require("shadows.LightWorld")
local LightCamera = require("shadows.LightCamera")
local DebugOverlay = require("shadows.DebugOverlay")
local Light = require("shadows.Light")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")

---@type LightWorld
local world
---@type DebugOverlay
local overlay
---@type LightCamera
local overview
---@type Light
local spotlight
---@type Body
local movingBody
---@type (CircleShadow|PolygonShadow)[]
local shapes = {}
---@type number
local elapsed = 0
---@type boolean
local paused = false
---@type boolean
local visible = true
---@type boolean
local tinted = false
---@type string[]
local categories = { "LightBounds", "ShadowGeometry", "CameraViewports", "CacheCounters" }

---@description Resizes the main view and overview to fit the current window.
---@param width number Logical window width.
---@param height number Logical window height.
---@return nil
local function resizeViews(width, height)
    local mainWidth = math.max(1, math.floor((width - 36) * 0.68))
    world:Resize(mainWidth, math.max(1, height - 100))
    overview:Resize(math.max(1, width - mainWidth - 36), math.max(1, math.floor((height - 100) * 0.5)))
end

---@description Verifies completed-frame metrics, cumulative counters, overlay toggles, and non-mutating drawing.
---@return nil
local function verifyOverlay()
    world:Update(0)
    local initial = overlay:GetStats()
    local firstFrame = overlay:GetFrameStats()
    assert(firstFrame.Camera.ShadowRedraws > 0 and firstFrame.Shared.ShadowRedraws > 0,
        "Camera star work and shared local-light work must be reported separately")
    assert(initial.ShadowRedraws > 0 and initial.GeometryRebuilds > 0 and initial.CachedDrawCalls > 0,
        "Diagnostics must report actual cached rendering work")
    world:Update(0)
    local stationary = overlay:GetFrameStats()
    assert(stationary.Camera.ShadowRedraws == 0 and stationary.Shared.ShadowRedraws == 0
        and stationary.Camera.CanvasAllocations == 0 and stationary.Shared.CanvasAllocations == 0
        and stationary.Camera.LightsComposited == 0,
        "Stationary frames must show zero redraws, allocations, and composition submissions")
    assert(overlay:GetStats().ShadowRedraws == initial.ShadowRedraws,
        "Stationary updates must keep shadow redraw counts unchanged")
    spotlight:SetColor(0.5, 0.7, 1, 1)
    world:Update(0)
    assert(overlay:GetStats().GeometryRebuilds == initial.GeometryRebuilds,
        "Tint-only updates must reuse cached geometry")
    movingBody:SetPosition(350, 255, 2)
    world:Update(0)
    local movedFrame = overlay:GetFrameStats()
    assert(movedFrame.Camera.ShadowRedraws > 0 and movedFrame.Shared.ShadowRedraws > 0,
        "Moving casters must register actual work in the current frame")
    local mainBefore = overlay:GetFrameStats()
    overview:SetPosition(110, 90, 0.55)
    world:Update(0)
    local mainFrame, overviewFrame = overlay:GetFrameStats(), overlay:GetFrameStats(overview)
    assert(mainFrame.Camera.ShadowRedraws == 0 and overviewFrame.Camera.ShadowRedraws > 0
        and mainFrame.Shared.ShadowRedraws == 0,
        "Moving the overview must charge its star work only to that camera")
    assert(mainBefore.Camera.ShadowRedraws > 0,
        "Previously completed frame snapshots must remain stable")
    overview:SetPosition(100, 80, 0.55)
    world:Update(0)
    assert(overlay:GetStats().ShadowRedraws > initial.ShadowRedraws,
        "Moving a caster must register new shadow redraws")
    local before = world.Canvas:newImageData():getString()
    local target = love.graphics.newCanvas(world.Width, world.Height, { dpiscale = 1 })
    love.graphics.setCanvas(target)
    love.graphics.clear()
    overlay:Draw()
    love.graphics.setCanvas()
    assert(before == world.Canvas:newImageData():getString(),
        "Diagnostics must not modify the composed lighting cache")
    local _, green, blue = target:newImageData():getPixel(0, world.Height - 4)
    assert(green > 0.2 and blue > 0.2, "Camera viewport wireframes must reach the output")
    for i, field in ipairs(categories) do
        love.keypressed(tostring(i))
        assert(not overlay[field], "Number keys must disable their overlay category")
        love.keypressed(tostring(i))
        assert(overlay[field], "Number keys must re-enable their overlay category")
    end
    spotlight:SetColor(1, 0.65, 0.25, 1)
    movingBody:SetPosition(340, 250, 2)
    world:Update(0)
    love.keypressed("t")
    assert(overlay.CumulativeTotals, "T must enable secondary lifetime totals")
    love.keypressed("t")
    assert(not overlay.CumulativeTotals, "T must return to frame metrics only")
    print("DebugOverlay per-frame ownership, rendering, toggle, and cache-counter verification passed")
end

---@description Builds a shared scene with a spotlight, point light, star, geometric casters, and overview camera.
---@return nil
function love.load()
    world = LightWorld:new()
    world:SetColor(0.09, 0.09, 0.13, 1)
    overview = LightCamera:new(world)
    overview:SetPosition(100, 80, 0.55)
    resizeViews(love.graphics.getDimensions())
    overlay = DebugOverlay:new(world)
    spotlight = Light:new(world, 210)
    spotlight:SetPosition(220, 240, 5)
    spotlight:SetAngle(90)
    spotlight.Arc = 110
    spotlight:SetColor(1, 0.65, 0.25, 1)
    local light = Light:new(world, 175)
    light:SetPosition(490, 350, 5)
    light:SetColor(0.25, 0.65, 1, 1)
    local star = Star:new(world, 550)
    star:SetPosition(420, 90, 6)
    star:SetColor(0.3, 0.25, 0.4, 1)
    movingBody = Body:new(world)
    movingBody:SetPosition(340, 250, 2)
    shapes[1] = PolygonShadow:new(movingBody, -35, -24, 35, -24, 35, 24, -35, 24)
    local body = Body:new(world)
    body:SetPosition(465, 360, 2)
    shapes[2] = CircleShadow:new(body, 0, 0, 27)
    body = Body:new(world)
    body:SetPosition(555, 195, 2)
    shapes[3] = PolygonShadow:new(body, -35, -30, 35, -30, 35, -10, 0, -10,
        -15, 35, -35, 35, -12, -10)
    for _, argument in ipairs(arg or {}) do
        if argument == "--verify" then verifyOverlay() end
    end
    if capture.auto then world:ForceUpdate() end
end

---@description Animates one caster and pans the main camera while counting actual rendering work.
---@param dt number Elapsed seconds.
---@return nil
function love.update(dt)
    if not capture.auto then
        if not paused then elapsed = elapsed + dt end
        movingBody:SetPosition(340 + math.sin(elapsed) * 28, 250, 2)
        movingBody:SetAngle(math.sin(elapsed * 0.5) * 20)
        local camera = world:GetCamera()
        local x, y, zoom = camera:GetPosition()
        if love.keyboard.isDown("left") then x = x - 150 * dt end
        if love.keyboard.isDown("right") then x = x + 150 * dt end
        if love.keyboard.isDown("up") then y = y - 150 * dt end
        if love.keyboard.isDown("down") then y = y + 150 * dt end
        camera:SetPosition(x, y, zoom)
    end
    world:Update(dt)
end

---@description Draws matching scene and lighting transforms, followed by optional diagnostics.
---@param camera LightCamera View to draw.
---@param screenX number Screen-space viewport left edge.
---@param screenY number Screen-space viewport top edge.
---@return nil
local function drawView(camera, screenX, screenY)
    local x, y, zoom = camera:GetPosition()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor(screenX, screenY, camera.Width, camera.Height)
    love.graphics.translate(screenX, screenY)
    love.graphics.scale(zoom, zoom)
    love.graphics.translate(-x, -y)
    love.graphics.setColor(0.65, 0.65, 0.7, 1)
    love.graphics.rectangle("fill", x, y, camera.Width / zoom, camera.Height / zoom)
    love.graphics.setColor(0.45, 0.45, 0.5, 1)
    for gx = math.floor(x / 40) * 40, x + camera.Width / zoom, 40 do
        love.graphics.line(gx, y, gx, y + camera.Height / zoom)
    end
    for gy = math.floor(y / 40) * 40, y + camera.Height / zoom, 40 do
        love.graphics.line(x, gy, x + camera.Width / zoom, gy)
    end
    love.graphics.setColor(0.35, 0.4, 0.45, 1)
    for _, shape in ipairs(shapes) do shape:Draw(math.huge) end
    love.graphics.pop()
    camera:Draw(screenX, screenY)
    if visible then overlay:Draw(camera, screenX, screenY) end
end

---@description Displays diagnostics in the main view and a differently zoomed overview.
---@return nil
function love.draw()
    love.graphics.clear(0.025, 0.025, 0.04, 1)
    drawView(world:GetCamera(), 12, 60)
    drawView(overview, world.Width + 24, 60)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("DebugOverlay | orange: light bounds | green: occluders | red: cached shadows | cyan: cameras",
        12, 10)
    local states = {}
    for i, field in ipairs(categories) do
        states[i] = i .. ": " .. field .. (overlay[field] and " ON" or " OFF")
    end
    love.graphics.print(table.concat(states, " | "), 12, 32)
    love.graphics.print("D: hide | T: totals | Space: pause | C: tint | B: soft/hard | R: rebuild | arrows: pan | F12: capture",
        12, love.graphics.getHeight() - 26)
    capture.draw()
end

---@description Resizes both diagnostic viewports after a window change.
---@param width number New logical window width.
---@param height number New logical window height.
---@return nil
function love.resize(width, height)
    if world then resizeViews(width, height) end
end

---@description Toggles diagnostic categories, pauses geometry, changes tint, or forces a rebuild.
---@param key string Pressed key.
---@return nil
function love.keypressed(key)
    local index = tonumber(key)
    if index and categories[index] then
        local field = categories[index]
        overlay[field] = not overlay[field]
    elseif key == "d" then
        visible = not visible
    elseif key == "t" then
        overlay.CumulativeTotals = not overlay.CumulativeTotals
    elseif key == "space" then
        paused = not paused
    elseif key == "c" then
        tinted = not tinted
        spotlight:SetColor(tinted and 0.5 or 1, 0.65, tinted and 1 or 0.25, 1)
    elseif key == "b" then
        for _, light in pairs(world.Lights) do light.Blur = not light.Blur end
        for _, star in pairs(world.Stars) do star.Blur = not star.Blur end
    elseif key == "r" then
        world:ForceUpdate()
    end
    capture.keypressed(key)
end
