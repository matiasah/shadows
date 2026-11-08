--- Checks antialiasing of diagonal projected shadows and occluder masks.
local LightWorld = require("shadows.LightWorld")
local Light = require("shadows.Light")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local Shadows = require("shadows")

local AntialiasRegression = {}

--- Counts pixels with partial coverage in a shadow or occluder canvas.
--- @param canvas love.Canvas Canvas containing a rendered silhouette.
--- @param channel integer Channel to measure: 1 for visibility, 4 for mask alpha.
--- @return integer count Number of partially covered pixels.
local function countPartialPixels(canvas, channel)
    local image = canvas:newImageData()
    local width, height = image:getDimensions()
    local count = 0
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local value = select(channel, image:getPixel(x, y))
            if value > 0.02 and value < 0.98 then count = count + 1 end
        end
    end
    return count
end

--- Checks real local and full-scene shadow rendering at a canvas DPI scale.
--- @param scale number Physical pixels per logical canvas unit.
--- @return nil
local function checkScale(scale)
    local newCanvas = love.graphics.newCanvas
    --- @description Applies a fixed DPI to canvases while preserving other creation settings.
    --- @param width number Canvas width.
    --- @param height number Canvas height.
    --- @param settings table? Canvas options; defaults to an empty table.
    --- @return love.Canvas canvas New canvas.
    love.graphics.newCanvas = function(width, height, settings)
        local options = {}
        for key, value in pairs(settings or {}) do options[key] = value end
        options.dpiscale = scale
        return newCanvas(width, height, options)
    end
    love.graphics.push("all")
    local world = LightWorld:new()
    world:Resize(256, 256)
    local light = Light:new(world, 128)
    light:SetPosition(80, 80, 1)
    light.Blur = false
    local star = Star:new(world, 300)
    star:SetPosition(80, 80, 1)
    star.Blur = false
    local body = Body:new(world)
    body:SetPosition(120, 110, 2)
    body:SetAngle(-15)
    PolygonShadow:new(body, -20, -14, 20, -14, 20, 14, -20, 14)
    world:Update()
    assert(countPartialPixels(light.ShadowCanvas, 1) >= 20,
        "Local hard shadows must have antialiased diagonal edges at DPI " .. scale)
    assert(countPartialPixels(star.ShadowCanvas, 1) >= 20,
        "Star hard shadows must have antialiased diagonal edges at DPI " .. scale)
    light.Blur, star.Blur = true, true
    world:Update()
    assert(countPartialPixels(light.Penumbra.Mask, 4) >= 10,
        "Local occluder masks must have antialiased edges at DPI " .. scale)
    assert(countPartialPixels(star.Penumbra.Mask, 4) >= 10,
        "Star occluder masks must have antialiased edges at DPI " .. scale)
    local localMask = light.Penumbra.Mask:newImageData()
    local starMask = star.Penumbra.Mask:newImageData()
    assert(select(4, localMask:getPixel(168 * scale, 158 * scale)) > 0.99,
        "Local occluder mask must retain the world-to-light transform")
    assert(select(4, starMask:getPixel(120 * scale, 110 * scale)) > 0.99,
        "Star occluder mask must retain the world-to-canvas transform")
    world:Resize(240, 240)
    world:Update()
    assert(countPartialPixels(star.ShadowCanvas, 1) >= 20,
        "Resized star shadows must retain antialiasing at DPI " .. scale)
    light:DestroyCanvas()
    assert(not light.ShadowRenderCanvas, "Destroying a light must release its multisampled target")
    world:Update()
    assert(light.ShadowRenderCanvas and countPartialPixels(light.ShadowCanvas, 1) >= 20,
        "Recreated local light shadows must retain antialiasing at DPI " .. scale)
    love.graphics.pop()
    love.graphics.newCanvas = newCanvas
end

--- Checks that partial occluder coverage blends unfiltered and filtered visibility.
--- @return nil
local function checkPartialCoverage()
    love.graphics.push("all")
    love.graphics.origin()
    local source = love.graphics.newCanvas(128, 128, { dpiscale = 1, mipmaps = "manual" })
    local mask = love.graphics.newCanvas(128, 128, { dpiscale = 1 })
    local field = love.graphics.newCanvas(128, 128, { dpiscale = 1, format = "rgba16f" })
    local radius = love.graphics.newCanvas(128, 128, { dpiscale = 1, format = "rgba16f" })
    local output = love.graphics.newCanvas(128, 128, { dpiscale = 1 })
    source:setMipmapFilter("linear")
    love.graphics.setCanvas(source)
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, 64, 128)
    love.graphics.setCanvas(field)
    love.graphics.clear(0.25, 0.5, 1, 1)
    love.graphics.setCanvas(radius)
    love.graphics.clear(24, 0, 0, 1)
    source:generateMipmaps()
    local shader = Shadows.PenumbraShader
    shader:send("DpiScale", 1)
    shader:send("Size", { 128, 128 })
    shader:send("RadiusScale", 1)
    shader:send("Occluders", mask)
    shader:send("NearestOccluder", field)
    shader:send("FilterRadius", radius)
    local values = {}
    for _, coverage in ipairs({ 0, 0.5, 1 }) do
        love.graphics.setCanvas(mask)
        love.graphics.clear(1, 1, 1, coverage)
        love.graphics.setCanvas(output)
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(source)
        love.graphics.setShader()
        love.graphics.setCanvas()
        values[#values + 1] = output:newImageData():getPixel(63, 64)
    end
    assert(values[1] > 0.1, "Uncovered edge must receive penumbra filtering")
    assert(values[3] < 0.01, "Fully covered edge must retain original visibility")
    assert(math.abs(values[2] - values[1] * 0.5) < 0.02,
        "Partial occluder coverage must blend filtered and original visibility")
    love.graphics.pop()
end

--- @description Checks that a light inside a silhouette does not select that silhouette as a directional blocker.
--- @param scale number Physical pixels per logical canvas unit.
--- @return nil
local function checkLightInsideOccluder(scale)
    love.graphics.push("all")
    love.graphics.origin()
    local options = { dpiscale = scale }
    local source = love.graphics.newCanvas(128, 128, { dpiscale = scale, mipmaps = "manual" })
    local mask = love.graphics.newCanvas(128, 128, options)
    local nearest = love.graphics.newCanvas(128, 128, { dpiscale = scale, format = "rgba16f" })
    local directional = love.graphics.newCanvas(128, 128, { dpiscale = scale, format = "rgba16f" })
    local radius = love.graphics.newCanvas(128, 128, { dpiscale = scale, format = "rgba16f" })
    local output = love.graphics.newCanvas(128, 128, options)
    nearest:setFilter("nearest", "nearest")
    directional:setFilter("nearest", "nearest")
    source:setMipmapFilter("linear")
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setCanvas(source)
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 64, 128, 64)
    love.graphics.setCanvas(nearest)
    love.graphics.clear(0.25, 0.5, 1, 1)
    love.graphics.setCanvas(directional)
    love.graphics.clear(0.25, 0.5, 1, 1)
    love.graphics.setColor(100 / 128, 0.5, 1, 1)
    love.graphics.rectangle("fill", 80, 0, 48, 128)
    source:generateMipmaps()
    local shader = Shadows.PenumbraShader
    local radiusShader = Shadows.PenumbraRadiusShader
    shader:send("DpiScale", scale)
    shader:send("Size", { 128, 128 })
    shader:send("RadiusScale", 1)
    shader:send("Occluders", mask)
    shader:send("FilterRadius", radius)
    radiusShader:send("DpiScale", scale)
    radiusShader:send("Size", { 128, 128 })
    radiusShader:send("Position", { 112, 64 })
    radiusShader:send("SourceRadius", 10)
    radiusShader:send("MinimumRadius", 8)
    radiusShader:send("Occluders", mask)
    local values = {}
    for index = 1, 3 do
        love.graphics.setCanvas(mask)
        love.graphics.clear()
        if index == 1 then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.rectangle("fill", 108, 60, 8, 8)
        end
        shader:send("NearestOccluder", index == 2 and nearest or directional)
        radiusShader:send("NearestOccluder", index == 2 and nearest or directional)
        love.graphics.setCanvas(radius)
        love.graphics.setShader(radiusShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(source)
        love.graphics.setCanvas(output)
        love.graphics.setShader(shader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(source)
        love.graphics.setShader()
        love.graphics.setCanvas()
        values[index] = output:newImageData():getPixel(64 * scale, 62 * scale)
    end
    assert(math.abs(values[1] - values[2]) < 0.01,
        "A source inside a silhouette must use the nearest blocker fallback")
    assert(math.abs(values[3] - values[2]) > 0.05,
        "The test must distinguish directional and nearest blocker filtering")
    love.graphics.pop()
end

--- Runs diagonal-edge antialiasing checks at standard and high DPI.
--- @return nil
function AntialiasRegression.run()
    for _, scale in ipairs({ 1, 2 }) do
        checkScale(scale)
        checkLightInsideOccluder(scale)
    end
    checkPartialCoverage()
    print("Shadow antialiasing regressions passed")
end

return AntialiasRegression
