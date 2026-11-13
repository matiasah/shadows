---@module Verifies every forest tree's alpha projection, front/back shading, and mutual occlusion.
local LightWorld = require("shadows.LightWorld")
local Star = require("shadows.Star")
local Light = require("shadows.Light")
local Body = require("shadows.Body")
local CastImageShadow = require("shadows.ShadowShapes.CastImageShadow")
local DPI = require("shadows.DPI")
local Regression = {}

---@description Reads a logical-coordinate pixel from a canvas.
---@param canvas love.Canvas Canvas to inspect.
---@param x number Logical x-coordinate.
---@param y number Logical y-coordinate.
---@return number red Red channel of the selected pixel.
local function pixel(canvas, x, y)
    local scale = DPI.getCanvasScale(canvas)
    local data = canvas:newImageData(1, 1, math.floor(x * scale), math.floor(y * scale), 1, 1)
    return data:getPixel(0, 0)
end

---@description Draws a receiver into a temporary target and reads its center illumination.
---@param shape CastImageShadow Upright image receiver.
---@param target love.Canvas Temporary scene target.
---@return number brightness Red illumination at the center of the sprite.
local function brightness(shape, target)
    love.graphics.setCanvas(target)
    love.graphics.origin()
    love.graphics.clear(0, 0, 0, 0)
    shape:DrawSprite()
    love.graphics.setCanvas()
    return pixel(shape.LightingCanvas, shape:GetWidth() * 0.5, shape:GetHeight() * 0.5)
end

---@description Checks one actual tree's texture, size, anchor, projection, and receiver behavior.
---@param original CastImageShadow Tree from the forest, not a shared representative.
---@param index integer Tree identifier used in assertion output.
---@param scale number Physical pixels per logical unit.
---@return nil
local function checkTree(original, index, scale)
    local world = LightWorld:new()
    world:Resize(400, 320)
    world:SetColor(0.03, 0.03, 0.03, 1)
    local x, y, z = original.Transform:GetPosition()
    world:SetPosition(x - 180, y - 140, 1)
    local light
    if index % 2 == 0 then
        light = Light:new(world, 300)
    else
        light = Star:new(world, 700)
    end
    light.Blur = false
    light:SetPosition(x, y + 120, z + 145)
    local body = Body:new(world)
    body:SetPosition(x, y, z)
    local tree = CastImageShadow:new(body, original.Texture, original:GetWidth(), original:GetHeight())
    local rotation = (index % 3 - 1) * 25
    tree.Transform:SetLocalRotation(rotation)
    local target = love.graphics.newCanvas(400, 320, { dpiscale = scale })
    local label = "tree " .. index .. ", DPI " .. scale
    world:Update()

    local crownHeight = tree:GetHeight() * 0.5
    local projectedY = y + (y - (y + 120)) * (z + crownHeight) / (145 - crownHeight)
    local canvasX, canvasY
    if light.Star then
        canvasX, canvasY = 180, projectedY - (y - 140)
    else
        canvasX, canvasY = light.Radius, projectedY - (y + 120 - light.Radius)
    end
    assert(pixel(light.ShadowCanvas, canvasX, canvasY) < 0.05, label .. ": opaque crown must cast a ground shadow")
    assert(pixel(light.ShadowCanvas, canvasX + 80, canvasY) > 0.95,
        label .. ": transparent surroundings must not cast a rectangular shadow")
    local lit = brightness(tree, target)
    assert(lit > 0.3, label .. ": tree facing the light must be illuminated")

    light:SetPosition(x, y - 120, z + 145)
    world:Update()
    local backlit = brightness(tree, target)
    assert(backlit < 0.04 and lit - backlit > 0.25,
        label .. ": backlit tree must become an ambient-only silhouette")

    local secondLight = Star:new(world, light.Radius)
    secondLight.Blur = false
    secondLight:SetPosition(x, y + 120, z + 145)
    world:Update()
    assert(math.abs(brightness(tree, target) - lit) < 0.01,
        label .. ": a front light must still illuminate a tree with another light behind it")
    secondLight:Remove()

    light:SetPosition(x, y + 120, z + 145)
    local blockerBody = Body:new(world)
    blockerBody:SetPosition(x, y + 40, z)
    local blocker = CastImageShadow:new(blockerBody, original.Texture, original:GetWidth(), original:GetHeight())
    blocker.Transform:SetLocalRotation(rotation)
    world:Update()
    local blocked = brightness(tree, target)
    assert(blocked < 0.04 and lit - blocked > 0.25,
        label .. ": another tree must shadow this tree's crown")
    blocker:Remove()
    world:Update()
    assert(math.abs(brightness(tree, target) - lit) < 0.01,
        label .. ": removing the blocker must restore illumination")

    light.Arc = 40
    light:SetAngle(180)
    world:Update()
    assert(brightness(tree, target) < 0.04, label .. ": an outward-facing cone must not illuminate the tree")
    light:SetAngle(0)
    light.Arc = 360
    light:SetColor(1, 1, 1, 0.5)
    world:Update()
    assert(math.abs(brightness(tree, target) - (0.03 + (lit - 0.03) * 0.5)) < 0.015,
        label .. ": light alpha must scale the direct contribution, not ambient")
    light:SetColor(1, 1, 1, 1)

    tree.Transform:SetLocalRotation(0)
    local mask = love.image.newImageData(2, 2)
    mask:setPixel(0, 0, 0, 0, 0, 1)
    mask:setPixel(0, 1, 0, 0, 0, 1)
    local maskTexture = love.graphics.newImage(mask)
    maskTexture:setFilter("nearest", "nearest")
    tree:SetTexture(maskTexture)
    world:Update()
    local offset = tree:GetWidth() * 0.25 * 145 / (145 - crownHeight)
    assert(pixel(light.ShadowCanvas, canvasX - offset, canvasY) < 0.05,
        label .. ": black opaque texture pixels must still cast a solid shadow")
    assert(pixel(light.ShadowCanvas, canvasX + offset, canvasY) > 0.95,
        label .. ": an internal transparent half must transmit light")
    tree:SetTexture(original.Texture)
    world:Update()

    local unrotated = brightness(tree, target)
    local zoom = 1.25
    world:SetPosition(x - 180 / zoom, y - 140 / zoom, zoom)
    world:Update()
    local zoomY = light.Star and (140 + (projectedY - y) * zoom) or canvasY
    assert(pixel(light.ShadowCanvas, canvasX, zoomY) < 0.05,
        label .. ": ground projection must follow camera translation and zoom")
    assert(math.abs(brightness(tree, target) - unrotated) < 0.01,
        label .. ": camera zoom must not change sprite illumination")
    assert(pixel(target, 180, 140 - crownHeight * zoom) > 0.02,
        label .. ": shaded sprite must be drawn at the camera-transformed position")

    local cached = light.ShadowCanvas:newImageData():getString()
    world:ForceUpdate()
    world:Update()
    assert(cached == light.ShadowCanvas:newImageData():getString(),
        label .. ": incremental ground shadows must match a full rebuild")
end

---@description Verifies every forest tree at both DPIs and checks all forest draw calls.
---@param world LightWorld Actual forest scene.
---@param light Star Actual forest light.
---@param trees CastImageShadow[] Every tree in the demonstration.
---@return nil
function Regression.run(world, light, trees)
    love.graphics.push("all")
    local newCanvas = love.graphics.newCanvas
    for _, scale in ipairs({ 1, 2 }) do
        ---@description Applies the selected DPI to all regression canvases.
        ---@param width number Logical canvas width.
        ---@param height number Logical canvas height.
        ---@param settings table? Canvas options; defaults to an empty table.
        ---@return love.Canvas canvas New test canvas.
        love.graphics.newCanvas = function(width, height, settings)
            local options = {}
            for key, value in pairs(settings or {}) do options[key] = value end
            options.dpiscale = scale
            return newCanvas(width, height, options)
        end
        for index, tree in ipairs(trees) do checkTree(tree, index, scale) end
    end
    love.graphics.newCanvas = newCanvas
    local target = love.graphics.newCanvas(world.Width, world.Height)
    local originalX, originalY, originalZ = light:GetPosition()
    for _, position in ipairs({ { 810, 475, 145 }, { 240, 500, 145 }, { 500, 80, 145 } }) do
        light:SetPosition(unpack(position))
        world:Update()
        local sprites = {}
        for index, tree in ipairs(trees) do
            assert(light.Shapes[0][tree.Body][tree] and #light.Shapes[0][tree.Body][tree] == 1,
                "forest tree " .. index .. " must contribute its own projected ground shadow")
            brightness(tree, target)
            sprites[index] = tree.LightingCanvas:newImageData():getString()
        end
        local cached = light.ShadowCanvas:newImageData():getString()
        world:ForceUpdate()
        world:Update()
        assert(cached == light.ShadowCanvas:newImageData():getString(),
            "complete forest ground shadows must match a forced rebuild")
        for index, tree in ipairs(trees) do
            brightness(tree, target)
            assert(sprites[index] == tree.LightingCanvas:newImageData():getString(),
                "forest tree " .. index .. ": receiver illumination must match a forced rebuild")
        end
    end
    light:SetPosition(originalX, originalY, originalZ)
    world:Update()
    love.graphics.pop()
    print("CastImage verified all " .. #trees ..
        " trees at DPI 1 and 2: ground alpha, rotated planes, front/back lighting, mutual occlusion, " ..
        "multiple lights, removal, cones, alpha, texture replacement, camera zoom, " ..
        "and complete forest rebuild equality at three light positions")
end

return Regression
