---@module Measures penumbra contact hardness, light colors, brightness, occluder protection, and DPI invariance.
local Penumbra = require("shadows.Penumbra")
local Shadows = require("shadows")
local Regression = {}

---@description Checks normalized ambient and room colors, opacity, and cache invalidation.
---@return nil
local function checkWorldColors()
    local LightWorld = require("shadows.LightWorld")
    local CircleRoom = require("shadows.Room.CircleRoom")
    local RectangleRoom = require("shadows.Room.RectangleRoom")
    local PolygonRoom = require("shadows.Room.PolygonRoom")
    love.graphics.push("all")
    local world = LightWorld:new()
    world:Resize(128, 128)
    assert(world.R == 0 and world.G == 0 and world.B == 0 and world.A == 1,
        "Default ambient color must be normalized opaque black")
    world:SetColor(0.2, 0.4, 0.6, 0.8)
    local r, g, a, b = world:GetColor()
    assert(r == 0.2 and g == 0.4 and b == 0.6 and a == 0.8,
        "Ambient colors must round-trip in the existing r,g,a,b order")
    world:Update()
    local image = world.Canvas:newImageData()
    r, g, b, a = image:getPixel(0, 0)
    assert(math.abs(r - 0.2) < 0.01 and math.abs(g - 0.4) < 0.01
        and math.abs(b - 0.6) < 0.01 and math.abs(a - 0.8) < 0.01,
        "Ambient canvas must preserve normalized channels")
    world:SetColor(1, 1, 1, 1)
    local rooms = {
        CircleRoom:new(world, 20, 20, 10),
        RectangleRoom:new(world, 50, 10, 20, 20),
        PolygonRoom:new(world, 90, 10, { 0, 0, 20, 0, 20, 20, 0, 20 }),
    }
    for _, room in ipairs(rooms) do
        r, g, b, a = room:GetColor()
        assert(r == 0 and g == 0 and b == 0 and a == 1,
            "Default room color must be normalized opaque black")
        room:SetColor(0.2, 0.4, 0.6, 0.5)
        r, g, b, a = room:GetColor()
        assert(r == 0.2 and g == 0.4 and b == 0.6 and a == 0.5,
            "Room colors must round-trip without conversion")
    end
    world:Update()
    image = world.Canvas:newImageData()
    local scale = world.Canvas:getDPIScale()
    for _, x in ipairs({ 20, 60, 100 }) do
        r, g, b, a = image:getPixel(x * scale, 20 * scale)
        assert(math.abs(r - 0.6) < 0.01 and math.abs(g - 0.7) < 0.01
            and math.abs(b - 0.8) < 0.01 and math.abs(a - 1) < 0.01,
            "Room fills must blend normalized tint and opacity over ambient color")
    end
    for _, room in ipairs(rooms) do room:SetColor(0, 0, 0, 1) end
    world:Update()
    image = world.Canvas:newImageData()
    r, g, b = image:getPixel(20 * scale, 20 * scale)
    assert(r == 0 and g == 0 and b == 0, "Room color changes must invalidate the world canvas")
    love.graphics.pop()
    print("Ambient and room color regressions passed")
end

---@description Checks radial light tint, opacity, falloff, and color cache invalidation.
---@return nil
local function checkLightColors()
    local LightWorld = require("shadows.LightWorld")
    local Light = require("shadows.Light")
    local Star = require("shadows.Star")
    for _, kind in ipairs({ "local", "star" }) do
        for _, blur in ipairs({ false, true }) do
            love.graphics.push("all")
            local world = LightWorld:new()
            world:Resize(128, 128)
            local light = (kind == "local" and Light or Star):new(world, 64)
            light:SetPosition(64, 64, 1)
            light.Blur = blur
            assert(light.R == 1 and light.G == 1 and light.B == 1 and light.A == 1,
                "Default light color must be normalized opaque white")
            for _, color in ipairs({ { 1, 0, 0, 1 }, { 0.25, 0.5, 1, 0.5 },
                { 1, 1, 1, 1 }, { 1, 0.5, 0.25, 0 } }) do
                light:SetColor(unpack(color))
                local r, g, b, a = light:GetColor()
                assert(r == color[1] and g == color[2] and b == color[3] and a == color[4],
                    "Light colors must round-trip without conversion")
                world:Update()
                local image = light.Canvas:newImageData()
                local scale = light.Canvas:getDPIScale()
                for _, x in ipairs({ 64, 96 }) do
                    local px, py = math.floor(x * scale), math.floor(64 * scale)
                    local dx, dy = (px + 0.5) / scale - 64, (py + 0.5) / scale - 64
                    local alpha = color[4] * (1 - math.sqrt(dx * dx + dy * dy + 1) / 64)
                    local r, g, b, a = image:getPixel(px, py)
                    for channel, actual in ipairs({ r, g, b, a }) do
                        local expected = channel == 4 and alpha or color[channel] * alpha
                        assert(math.abs(actual - expected) < 0.015, string.format(
                            "%s light blur=%s channel=%d must preserve premultiplied color and falloff: %.3f vs %.3f",
                            kind, tostring(blur), channel, actual, expected))
                    end
                end
            end
            light:SetColor(0.2, 0.3, 0.4, 0.6)
            light:SetColor(0.5, 0.6, 0.7)
            local _, _, _, alpha = light:GetColor()
            assert(alpha == 0.6, "Omitted light alpha must retain the current normalized value")
            love.graphics.pop()
        end
    end
    print("Light color rendering regressions passed")
end

--- @description Reads visibility at a logical position in a rendered test canvas.
--- @param image love.ImageData Rendered visibility samples.
--- @param x number Logical x-coordinate.
--- @param y number Logical y-coordinate.
--- @param scale number Canvas DPI scale.
--- @return number visibility Red-channel visibility.
local function visibility(image, x, y, scale)
    return image:getPixel(math.floor(x * scale), math.floor(y * scale))
end

--- @description Measures the 20-to-80-percent transition width across a shadow edge.
--- @param image love.ImageData Rendered visibility samples.
--- @param x number Logical distance along the cast shadow.
--- @param scale number Canvas DPI scale.
--- @return number width Transition width in logical units.
local function transitionWidth(image, x, scale)
    local first, last
    for y = 70 * scale, 144 * scale do
        local value = image:getPixel(x * scale, y)
        if value <= 0.8 and not first then first = y end
        if value <= 0.2 and not last then last = y end
    end
    assert(first and last, string.format(
        "Expected a complete shadow transition at x=%d, DPI=%d (20%%=%s, 80%%=%s, center=%.3f)",
        x, scale, tostring(first), tostring(last), image:getPixel(x * scale, 144 * scale)))
    return (last - first) / scale
end

--- @description Renders a controlled hard-shadow strip filtered by a rectangular occluder.
--- @param scale number Canvas DPI scale.
--- @param sourceRadius number Effective source radius in logical units.
--- @param withOccluder boolean Whether to draw an occluder silhouette.
--- @param uniform number? Constant input visibility; defaults to a hard-shadow strip.
--- @param lightX number? Light x-coordinate; defaults to 16.
--- @param worldScale number? World-to-canvas scale; defaults to 1.
--- @return love.ImageData image Filtered visibility samples.
local function render(scale, sourceRadius, withOccluder, uniform, lightX, worldScale)
    local canvas = love.graphics.newCanvas(256, 256, { dpiscale = scale, mipmaps = "manual" })
    canvas:setMipmapFilter("linear")
    local output = love.graphics.newCanvas(256, 256, { dpiscale = scale })
    love.graphics.push("all")
    love.graphics.origin()
    love.graphics.setCanvas(canvas)
    love.graphics.setShader()
    local value = uniform or 1
    love.graphics.clear(value, value, value, 1)
    love.graphics.setBlendMode("replace", "premultiplied")
    if uniform == nil then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 64, 112, 192, 64)
    end
    love.graphics.setColor(1, 1, 1, 1)

    --- @class PenumbraTestLight
    --- @field ShadowCanvas love.Canvas Controlled input visibility mask.
    --- @field SizeRadius number Effective source radius.
    --- @field World table Test occluder callbacks.
    local light = {
        ShadowCanvas = canvas,
        SizeRadius = sourceRadius,
        World = {
            Bodies = {
                --- @description Reports the absence of body occluders in this synthetic scene.
                --- @return integer length Zero bodies.
                GetLength = function() return 0 end,
            },
            --- @description Draws the test caster silhouette for the distance field.
            --- @param self table Test world.
            --- @param currentLight PenumbraTestLight Light whose mask is being rendered.
            --- @return nil
            DrawSprites = function(self, currentLight)
                if withOccluder then
                    love.graphics.rectangle("fill", 48, 112, 16, 64)
                end
            end,
        },
        --- @description Returns the synthetic light position.
        --- @return number x Light x-coordinate.
        --- @return number y Light y-coordinate.
        GetPosition = function() return lightX or 16, 144 end,
        --- @description Returns the synthetic light center in canvas coordinates.
        --- @return number x Canvas x-coordinate.
        --- @return number y Canvas y-coordinate.
        GetCanvasCenter = function() return lightX or 16, 144 end,
    }
    local penumbra = Penumbra:new(canvas)
    penumbra:Update(light, worldScale)
    love.graphics.setCanvas(output)
    love.graphics.setBlendMode("replace", "premultiplied")
    penumbra:Apply(light)
    love.graphics.draw(canvas)
    love.graphics.setCanvas()
    local image = output:newImageData()
    love.graphics.pop()
    return image
end

--- @description Checks full-scene cache reuse, camera scaling, hard-shadow toggles, and resizing.
--- @return nil
local function checkStarLifecycle()
    local LightWorld = require("shadows.LightWorld")
    local Star = require("shadows.Star")
    local Body = require("shadows.Body")
    local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
    love.graphics.push("all")
    local world = LightWorld:new()
    world:Resize(256, 192)
    local star = Star:new(world, 300)
    star:SetPosition(80, 90, 1)
    local body = Body:new(world)
    body:SetPosition(110, 90, 2)
    PolygonShadow:new(body, -10, -15, 10, -15, 10, 15, -10, 15)
    world:SetPosition(20, 10, 1.5)
    world:Update()
    local x, y = star:GetCanvasCenter()
    assert(x == 90 and y == 120, "Star center must follow camera translation and zoom")
    local cached = star.Penumbra
    assert(cached, "Soft star must allocate filtering buffers")
    world:Update()
    assert(star.Penumbra == cached, "Unchanged star must reuse filtering buffers")
    star.Blur = false
    world:Update()
    assert(not star.Penumbra, "Hard star must discard filtering buffers")
    star.Blur = true
    star.SizeRadius = 0
    world:Update()
    assert(not star.Penumbra, "Zero-radius star must bypass filtering")
    star.SizeRadius = 12
    world:Update()
    assert(star.Penumbra, "Restoring source size must reenable filtering")
    cached = star.Penumbra
    world:Resize(300, 220)
    assert(not star.Penumbra, "Star resize must invalidate old filtering buffers")
    world:Update()
    assert(star.Penumbra and star.Penumbra ~= cached, "Resized star must recreate filtering buffers")
    love.graphics.pop()
    print("Penumbra star lifecycle regressions passed")
end

--- @description Checks minimum softness in actual local-light and star composites.
--- @return nil
local function checkRealLights()
    local LightWorld = require("shadows.LightWorld")
    local Light = require("shadows.Light")
    local Star = require("shadows.Star")
    local Body = require("shadows.Body")
    local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
    for _, kind in ipairs({ "local", "star" }) do
        for _, case in ipairs({ { 24, 260 }, { -80, 360 } }) do
            love.graphics.push("all")
            local world = LightWorld:new()
            world:Resize(256, 256)
            local light = (kind == "local" and Light or Star):new(world, case[2])
            light:SetPosition(case[1], 128, 1)
            light.SizeRadius = 0.001
            light.Blur = false
            local body = Body:new(world)
            body:SetPosition(120, 128, 2)
            PolygonShadow:new(body, -8, -20, 8, -20, 8, 20, -8, 20)
            world:Update()
            local hard = light.Canvas:newImageData()
            light.Blur = true
            world:Update()
            local soft = light.Canvas:newImageData()
            local dpi = light.Canvas:getDPIScale()
            local x = kind == "local" and 200 - case[1] + case[2] or 200
            local offsetY = kind == "local" and case[2] - 128 or 0
            local difference = 0
            for y = 60, 196 do
                local px, py = math.floor(x * dpi), math.floor((y + offsetY) * dpi)
                difference = math.max(difference, math.abs(hard:getPixel(px, py) - soft:getPixel(px, py)))
            end
            assert(difference > 0.02, string.format(
                "%s radius %d at x=%d must visibly soften a real shadow (difference %.3f)",
                kind, case[2], case[1], difference))
            love.graphics.pop()
        end
    end
    print("Penumbra real-light regressions passed")
end

--- @description Runs pixel assertions at both standard and high canvas DPI scales.
--- @return nil
function Regression.run()
    checkWorldColors()
    checkLightColors()
    local widths = {}
    for _, scale in ipairs({ 1, 2 }) do
        local image = render(scale, 12, true)
        local near = transitionWidth(image, 68, scale)
        local far = transitionWidth(image, 200, scale)
        for _, x in ipairs({ 150, 180, 200 }) do
            for y = 70 * scale, 143 * scale do
                local upper = image:getPixel(x * scale, y)
                local upperNext = image:getPixel(x * scale, y + 1)
                local lower = image:getPixel(x * scale, (288 * scale) - y - 1)
                local lowerNext = image:getPixel(x * scale, (288 * scale) - y - 2)
                assert(upperNext - upper < 0.06 and lowerNext - lower < 0.06,
                    string.format("Both penumbra edges must fade without bright seams at x=%d DPI=%d", x, scale))
            end
        end
        assert(near <= 3, "Contact penumbra must remain at most 3 logical pixels wide")
        assert(far >= 8 and far >= near * 3, "Distant penumbra must be at least 8 pixels and 3x wider")
        assert(visibility(image, 56, 114, scale) > 0.99, "Occluder must not be darkened by filtering")
        assert(visibility(image, 200, 40, scale) > 0.99, "Fully lit regions must retain brightness")
        assert(visibility(image, 90, 128, scale) < 0.01, "Near umbra must remain dark")
        widths[scale] = far

        local hard = render(scale, 0, true)
        assert(transitionWidth(hard, 200, scale) == 0, "Zero source radius must preserve hard edges")
        local empty = render(scale, 12, false)
        assert(transitionWidth(empty, 200, scale) == 0, "No blocker must preserve the original shadow mask")
        for _, value in ipairs({ 0, 0.35, 1 }) do
            local uniform = render(scale, 12, true, value)
            assert(math.abs(visibility(uniform, 200, 112, scale) - value) < 0.01,
                "Normalized filtering must preserve constant visibility")
        end
        for _, lightX in ipairs({ 16, -2000 }) do
            for _, radius in ipairs({ 0.001, 1, 12 }) do
                local minimum = render(scale, radius, true, nil, lightX)
                local width = transitionWidth(minimum, 200, scale)
                assert(width >= 4, string.format(
                    "Positive source radius %.3f at x=%d must produce a visible penumbra at DPI %d (%.2f px)",
                    radius, lightX, scale, width))
            end
        end
        local zoomed = render(scale, 0.001, true, nil, -2000, 2)
        local unzoomed = render(scale, 0.001, true, nil, -2000, 1)
        assert(transitionWidth(zoomed, 200, scale) > transitionWidth(unzoomed, 200, scale) * 1.5,
            "Minimum softness must scale with star camera zoom")
        assert(far > transitionWidth(unzoomed, 200, scale),
            "Larger nearby sources must still produce additional softness")
        print(string.format("Penumbra DPI %d: near %.2f px, far %.2f px", scale, near, far))
    end
    assert(math.abs(widths[1] - widths[2]) <= 1, "Penumbra width must agree within 1 logical pixel across DPI")
    love.graphics.setShader()
    assert(Shadows.PenumbraShader, "Penumbra shader must be registered")
    checkStarLifecycle()
    checkRealLights()
    print("Penumbra pixel regressions passed")
end

return Regression
