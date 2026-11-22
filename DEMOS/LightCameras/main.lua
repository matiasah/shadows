---@module Demonstrates independently positioned lighting cameras sharing one animated scene.
local capture = require("Capture").new("lightcameras-capture.png")
local LightWorld = require("shadows.LightWorld")
local LightCamera = require("shadows.LightCamera")
local Light = require("shadows.Light")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")

---@type LightWorld
local world
---@type LightCamera[]
local cameras = {}
---@type Body
local movingBody
---@type PolygonShadow
local rectangle
---@type CircleShadow
local circle
---@type integer
local selected = 1
---@type number
local elapsed = 0
---@type boolean
local paused = false
---@type string[]
local qualities = { "high", "medium", "low" }

---@description Fits both viewports to the current window without changing their world positions.
---@param width number Window logical width.
---@param height number Window logical height.
---@return nil
local function resizeViews(width, height)
    local viewportWidth = math.max(1, math.floor((width - 36) / 2))
    local viewportHeight = math.max(1, height - 104)
    for _, camera in ipairs(cameras) do camera:Resize(viewportWidth, viewportHeight) end
end

---@description Verifies independent views, shared lighting, and incremental rendering against full rebuilds.
---@return nil
local function verifyViews()
    world:Update(0)
    local right = cameras[2]
    local rx, ry, rz = right:GetPosition()
    local original = right.Canvas:newImageData():getString()
    assert(original ~= cameras[1].Canvas:newImageData():getString(),
        "Different camera positions and zooms must render different views")
    right:SetPosition(cameras[1]:GetPosition())
    world:Update(0)
    assert(right.Canvas:newImageData():getString() == cameras[1].Canvas:newImageData():getString(),
        "Matching cameras must render identical shared lights and stars")
    right:SetPosition(rx, ry, rz)
    movingBody:SetPosition(380, 270, 2)
    world:Update(0)
    local images = {}
    for i, camera in ipairs(cameras) do images[i] = camera.Canvas:newImageData():getString() end
    assert(images[2] ~= original, "Both views must see shared scene movement")
    world:ForceUpdate()
    world:Update(0)
    for i, camera in ipairs(cameras) do
        assert(images[i] == camera.Canvas:newImageData():getString(),
            "Camera " .. i .. " incremental lighting must match a full rebuild")
    end
    movingBody:SetPosition(360, 240, 2)
    world:Update(0)
    print("LightCamera split-screen verification passed")
end

---@description Builds one scene with two cameras, a local light, and a full-scene star.
---@return nil
function love.load()
    world = LightWorld:new()
    world:SetColor(0.06, 0.06, 0.09, 1)
    cameras = { world:GetCamera(), LightCamera:new(world) }
    resizeViews(love.graphics.getDimensions())
    cameras[2]:SetPosition(170, 50, 0.8)
    local light = Light:new(world, 300)
    light:SetPosition(260, 210, 5)
    light:SetColor(1, 0.6, 0.2, 1)
    local star = Star:new(world, 600)
    star:SetPosition(170, 80, 6)
    star:SetColor(0.25, 0.35, 0.55, 1)
    movingBody = Body:new(world)
    movingBody:SetPosition(360, 240, 2)
    rectangle = PolygonShadow:new(movingBody, -32, -24, 32, -24, 32, 24, -32, 24)
    local body = Body:new(world)
    body:SetPosition(210, 330, 2)
    circle = CircleShadow:new(body, 0, 0, 26)
    for _, argument in ipairs(arg or {}) do
        if argument == "--verify" then verifyViews() end
    end
end

---@description Moves the shared body once and navigates only the selected camera.
---@param dt number Elapsed seconds.
---@return nil
function love.update(dt)
    if not capture.auto then
        if not paused then elapsed = elapsed + dt end
        movingBody:SetPosition(360 + math.sin(elapsed) * 50, 240, 2)
        local camera = cameras[selected]
        local x, y, zoom = camera:GetPosition()
        local distance = 180 * dt / zoom
        if love.keyboard.isDown("left") then x = x - distance end
        if love.keyboard.isDown("right") then x = x + distance end
        if love.keyboard.isDown("up") then y = y - distance end
        if love.keyboard.isDown("down") then y = y + distance end
        camera:SetPosition(x, y, zoom)
    end
    world:Update(dt)
end

---@description Draws the shared scene through one camera's transform, then applies matching lighting.
---@param camera LightCamera View to draw.
---@param screenX number Screen-space left edge.
---@return nil
local function drawView(camera, screenX)
    local x, y, zoom = camera:GetPosition()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor(screenX, 52, camera:GetWidth(), camera:GetHeight())
    love.graphics.translate(screenX, 52)
    love.graphics.scale(zoom, zoom)
    love.graphics.translate(-x, -y)
    love.graphics.setColor(0.8, 0.8, 0.85, 1)
    love.graphics.rectangle("fill", x, y, camera:GetWidth() / zoom, camera:GetHeight() / zoom)
    love.graphics.setColor(0.65, 0.65, 0.7, 1)
    for gx = math.floor(x / 40) * 40, x + camera:GetWidth() / zoom, 40 do
        love.graphics.line(gx, y, gx, y + camera:GetHeight() / zoom)
    end
    for gy = math.floor(y / 40) * 40, y + camera:GetHeight() / zoom, 40 do
        love.graphics.line(x, gy, x + camera:GetWidth() / zoom, gy)
    end
    love.graphics.setColor(0.4, 0.45, 0.5, 1)
    rectangle:Draw(math.huge)
    circle:Draw(math.huge)
    love.graphics.pop()
    camera:Draw(screenX, 52)
end

---@description Shows the two lit viewports and their independent camera coordinates.
---@return nil
function love.draw()
    love.graphics.clear(0.04, 0.04, 0.06, 1)
    for i, camera in ipairs(cameras) do
        local screenX = 12 + (i - 1) * (camera:GetWidth() + 12)
        drawView(camera, screenX)
        local x, y, zoom = camera:GetPosition()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(string.format("%s Camera %d | position %.0f, %.0f | zoom %.2f",
            selected == i and ">" or " ", i, x, y, zoom), screenX, 28)
    end
    love.graphics.print("One world, two LightCameras | quality " .. world.Settings:GetQuality(), 12, 8)
    love.graphics.print("Tab: select view | arrows: pan | +/-: zoom | Q: quality | Space: pause | F12: capture",
        12, love.graphics.getHeight() - 36)
    capture.draw()
end

---@description Resizes each lighting viewport to match its screen rectangle.
---@param width number New window width.
---@param height number New window height.
---@return nil
function love.resize(width, height)
    if world then resizeViews(width, height) end
end

---@description Selects a camera, changes its zoom, or adjusts shared rendering quality.
---@param key string Pressed key.
---@return nil
function love.keypressed(key)
    if key == "tab" then
        selected = 3 - selected
    elseif key == "space" then
        paused = not paused
    elseif key == "=" or key == "+" or key == "-" then
        local camera = cameras[selected]
        local x, y, zoom = camera:GetPosition()
        camera:SetPosition(x, y, math.max(0.25, math.min(3, zoom * (key == "-" and 0.8 or 1.25))))
    elseif key == "q" then
        local current = world.Settings:GetQuality()
        for i, quality in ipairs(qualities) do
            if quality == current then
                world.Settings:SetQuality(qualities[i % #qualities + 1])
                break
            end
        end
    end
    capture.keypressed(key)
end
