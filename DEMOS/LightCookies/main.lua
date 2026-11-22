---@module Demonstrates transformed illumination cookies on point lights, cones, and full-scene stars.
local capture = require("Capture").new("light-cookies-capture.png")
local LightWorld = require("shadows.LightWorld")
local Light = require("shadows.Light")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")

---@type LightWorld
local world
---@type (Light|Star)[]
local lights = {}
---@type love.Image[]
local cookies = {}
---@type (PolygonShadow|CircleShadow)[]
local shapes = {}
---@type boolean[]
local enabled = { true, true, true }
---@type string[]
local names = { "Window / point", "Gobo / cone", "Ripples / star" }
---@type integer
local selected = 1
---@type boolean
local paused = false
---@type string[]
local qualities = { "high", "medium", "low" }
---@type integer
local goboEdgeTexels = 0

---@description Generates original cookie artwork, supersampling and feathering the radial gobo's aperture edges.
---@param pattern integer Pattern index from 1 to 3.
---@return love.Image image Generated illumination cookie.
local function makeCookie(pattern)
    local size = pattern == 2 and 512 or 128
    local data = love.image.newImageData(size, size)
    if pattern == 2 then goboEdgeTexels = 0 end
    data:mapPixel(
        ---@description Computes transparent bars, angular apertures, or colored wave bands.
        ---@param x number Pixel x-coordinate.
        ---@param y number Pixel y-coordinate.
        ---@return number r Red channel.
        ---@return number g Green channel.
        ---@return number b Blue channel.
        ---@return number a Mask intensity.
        function(x, y)
            if pattern == 1 then
                local pane = x > 8 and x < 120 and y > 12 and y < 116
                    and x % 32 > 5 and y % 32 > 5
                return 1, 0.9, 0.7, pane and 1 or 0
            elseif pattern == 2 then
                local coverage = 0
                for sy = 0, 3 do
                    for sx = 0, 3 do
                        local angle = math.atan2(y + (sy + 0.5) / 4 - size / 2,
                            x + (sx + 0.5) / 4 - size / 2)
                        local edge = math.max(0, math.min(1, 0.5 + (math.cos(angle * 7) + 0.15) / 0.18))
                        coverage = coverage + edge * edge * (3 - 2 * edge)
                    end
                end
                coverage = coverage / 16
                if coverage > 0.01 and coverage < 0.99 then goboEdgeTexels = goboEdgeTexels + 1 end
                return 1, 1, 1, 0.08 + 0.92 * coverage
            end
            local wave = math.sin(x * 0.22 + math.sin(y * 0.12) * 2)
            local intensity = math.max(0.08, wave * 0.5 + 0.5)
            return 0.45 + intensity * 0.55, 0.8, 1, intensity
        end)
    local image = love.graphics.newImage(data, { mipmaps = pattern == 2 })
    image:setFilter("linear", "linear")
    if pattern == 2 then image:setMipmapFilter("linear") end
    return image
end

---@description Fits the fixed world-space scene into the resized default lighting camera.
---@param width number Window logical width.
---@param height number Window logical height.
---@return nil
local function resizeView(width, height)
    local viewportWidth, viewportHeight = math.max(1, width - 24), math.max(1, height - 112)
    world:Resize(viewportWidth, viewportHeight)
    world:SetPosition(0, 0, math.min(viewportWidth / 960, viewportHeight / 480))
end

---@description Verifies every cookie changes illumination, preserves cached shadows, and matches full rebuilds.
---@return nil
local function verifyCookies()
    assert(goboEdgeTexels > 512,
        "The gobo must contain substantial intermediate edge coverage, not binary sprite-like apertures")
    world:Update(0)
    for i, light in ipairs(lights) do
        selected = i
        local original = world.Canvas:newImageData():getString()
        love.keypressed("c")
        world:Update(0)
        assert(world.Canvas:newImageData():getString() ~= original,
            names[i] .. " must mask actual illumination")
        assert(world.FrameMetrics.ShadowRedraws == 0 and world:GetCamera().FrameMetrics.ShadowRedraws == 0,
            "Toggling cookies must not rebuild local or star shadows")
        love.keypressed("c")
        world:Update(0)
        assert(world.Canvas:newImageData():getString() == original,
            "Restoring a cookie must restore its rendered pixels")
        light:SetCookieTransform(12, -8, 22, 0.8, 1.1)
        world:Update(0)
        assert(world.FrameMetrics.GeometryRebuilds == 0 and world.FrameMetrics.CanvasAllocations == 0
            and world:GetCamera().FrameMetrics.GeometryRebuilds == 0
            and world:GetCamera().FrameMetrics.CanvasAllocations == 0,
            "Cookie transforms must reuse geometry and buffers")
        local changed = world.Canvas:newImageData():getString()
        assert(changed ~= original, "Cookie transforms must change the projected pattern")
        world:ForceUpdate()
        world:Update(0)
        assert(changed == world.Canvas:newImageData():getString(),
            "Cookie appearance updates must match full shadow rebuilds")
        light:SetCookieTransform()
        world:Update(0)
    end
    selected = 1
    love.keypressed("tab")
    assert(selected == 2, "Tab must select the next light")
    love.keypressed("space")
    assert(paused, "Space must pause animation")
    love.keypressed("space")
    selected = 1
    print("LightCookies mask, transform, control, and shadow-cache verification passed")
end

---@description Builds procedural cookie lights and registered casters using the shared source library.
---@return nil
function love.load()
    world = LightWorld:new()
    world:SetColor(0.035, 0.04, 0.055, 1)
    for i = 1, 3 do cookies[i] = makeCookie(i) end
    lights[1] = Light:new(world, 210)
    lights[1]:SetPosition(180, 255, 6):SetColor(1, 0.75, 0.45, 1):SetCookie(cookies[1])
    lights[2] = Light:new(world, 270)
    lights[2]:SetPosition(500, 395, 6):SetColor(0.6, 1, 0.65, 1):SetCookie(cookies[2])
    lights[2].Arc = 100
    lights[3] = Star:new(world, 210)
    lights[3]:SetPosition(800, 255, 6):SetColor(0.45, 0.75, 1, 1):SetCookie(cookies[3])
    local body = Body:new(world)
    body:SetPosition(240, 280, 2)
    shapes[1] = CircleShadow:new(body, 0, 0, 22)
    body = Body:new(world)
    body:SetPosition(500, 265, 2)
    shapes[2] = PolygonShadow:new(body, -24, -14, 24, -14, 24, 14, -24, 14)
    body = Body:new(world)
    body:SetPosition(850, 275, 2)
    shapes[3] = CircleShadow:new(body, 0, 0, 20)
    resizeView(love.graphics.getDimensions())
    for _, argument in ipairs(arg or {}) do
        if argument == "--verify" then verifyCookies() end
    end
end

---@description Animates two cookie rotations and moves the selected mask in its light's local coordinates.
---@param dt number Elapsed seconds.
---@return nil
function love.update(dt)
    if not capture.auto then
        if not paused then
            for i = 2, 3 do
                local x, y, angle, sx, sy = lights[i]:GetCookieTransform()
                lights[i]:SetCookieTransform(x, y, angle + dt * (i == 2 and 18 or -8), sx, sy)
            end
        end
        local light = lights[selected]
        local x, y, angle, sx, sy = light:GetCookieTransform()
        if love.keyboard.isDown("left") then x = x - dt * 80 end
        if love.keyboard.isDown("right") then x = x + dt * 80 end
        if love.keyboard.isDown("up") then y = y - dt * 80 end
        if love.keyboard.isDown("down") then y = y + dt * 80 end
        if love.keyboard.isDown("a") then angle = angle - dt * 60 end
        if love.keyboard.isDown("d") then angle = angle + dt * 60 end
        light:SetCookieTransform(x, y, angle, sx, sy)
    end
    world:Update(dt)
end

---@description Draws a matching scene view, applies lighting, and labels cookie controls and frame work.
---@return nil
function love.draw()
    love.graphics.clear(0.025, 0.025, 0.04, 1)
    local camera = world:GetCamera()
    local x, y, zoom = camera:GetPosition()
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setScissor(12, 72, camera.Width, camera.Height)
    love.graphics.translate(12, 72)
    love.graphics.scale(zoom, zoom)
    love.graphics.translate(-x, -y)
    love.graphics.setColor(0.85, 0.85, 0.9, 1)
    love.graphics.rectangle("fill", x, y, camera.Width / zoom, camera.Height / zoom)
    love.graphics.setColor(0.6, 0.6, 0.65, 1)
    for gx = 0, camera.Width / zoom, 24 do
        love.graphics.line(gx, 0, gx, camera.Height / zoom)
    end
    for gy = 0, camera.Height / zoom, 24 do
        love.graphics.line(0, gy, camera.Width / zoom, gy)
    end
    love.graphics.setColor(0.4, 0.45, 0.5, 1)
    for _, shape in ipairs(shapes) do shape:Draw(math.huge) end
    love.graphics.pop()
    camera:Draw(12, 72)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("LightCookies | centered RGB/alpha masks preserve falloff, cones, and shadows", 12, 8)
    local light = lights[selected]
    local ox, oy, angle, sx, sy = light:GetCookieTransform()
    love.graphics.print(string.format(
        "%s | cookie %s | offset %.0f, %.0f | angle %.0f | scale %.2f, %.2f | quality %s%s",
        names[selected], enabled[selected] and "ON" or "OFF", ox, oy, angle, sx, sy,
        world.Settings:GetQuality(), paused and " | paused" or ""), 12, 28)
    love.graphics.print(string.format("Shadow redraws: shared %d / stars %d | cookie animation reuses shadow caches",
        world.FrameMetrics.ShadowRedraws, camera.FrameMetrics.ShadowRedraws), 12, 48)
    for i, source in ipairs(lights) do
        local lx, ly = source:GetPosition()
        love.graphics.setColor(selected == i and 1 or 0.7, 1, 1, 1)
        love.graphics.circle("line", 12 + lx * zoom, 72 + ly * zoom, 5)
        love.graphics.print(names[i], 12 + (i - 1) * 320 * zoom + 40, 84)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        "Tab: select | arrows: offset | A/D: rotate | +/-: scale | C: cookie | B: blur | Q: quality | R: reset | Space: pause | F12: capture",
        12, love.graphics.getHeight() - 26)
    capture.draw()
end

---@description Resizes the lighting camera and scene transform together.
---@param width number New logical window width.
---@param height number New logical window height.
---@return nil
function love.resize(width, height)
    if world then resizeView(width, height) end
end

---@description Selects and transforms masks, toggles cookies/filtering, or adjusts shared rendering quality.
---@param key string Pressed key.
---@return nil
function love.keypressed(key)
    if key == "tab" then
        selected = selected % #lights + 1
    elseif key == "space" then
        paused = not paused
    elseif key == "c" then
        enabled[selected] = not enabled[selected]
        lights[selected]:SetCookie(enabled[selected] and cookies[selected] or nil)
    elseif key == "b" then
        for _, light in ipairs(lights) do light.Blur = not light.Blur end
    elseif key == "r" then
        lights[selected]:SetCookieTransform()
    elseif key == "=" or key == "+" or key == "-" then
        local light = lights[selected]
        local x, y, angle, sx, sy = light:GetCookieTransform()
        local factor = key == "-" and 0.8 or 1.25
        light:SetCookieTransform(x, y, angle, math.max(0.1, math.min(3, sx * factor)),
            math.max(0.1, math.min(3, sy * factor)))
    elseif key == "q" then
        for i, quality in ipairs(qualities) do
            if world.Settings:GetQuality() == quality then
                world.Settings:SetQuality(qualities[i % #qualities + 1])
                break
            end
        end
    end
    capture.keypressed(key)
end
