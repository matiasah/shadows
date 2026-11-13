---@module Demonstrates a forest of upright image casters with ground shadows and mutually shaded trees.
local capture = require("Capture").new("cast-image-capture.png")
local LightWorld = require("shadows.LightWorld")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local CastImageShadow = require("shadows.ShadowShapes.CastImageShadow")

---@type LightWorld
local world
---@type Star
local light
---@type CastImageShadow[]
local trees = {}
---@type boolean
local followMouse = false
---@type boolean
local verify = false

---@description Creates original pixel-art foliage and a trunk on a transparent texture.
---@return love.Image texture Tree sprite with nearest-neighbor filtering.
local function makeTree()
    local data = love.image.newImageData(32, 40)
    for y = 0, 39 do
        for x = 0, 31 do
            if y >= 27 and y <= 38 and x >= 13 and x <= 18 then
                data:setPixel(x, y, x < 16 and 0.34 or 0.24, 0.16, 0.065, 1)
            end
            local dx, dy = x - 15.5, (y - 16) * 0.94
            local angle = math.atan2(dy, dx)
            local edge = 14 + math.sin(angle * 7) * 1.2
            if dx * dx + dy * dy < edge * edge and y < 31 then
                local patch = (math.floor(x / 5) + math.floor(y / 5)) % 3
                local shade = 0.75 + patch * 0.1 - y * 0.006
                data:setPixel(x, y, 0.2 * shade, 0.48 * shade, 0.12 * shade, 1)
            end
        end
    end
    local texture = love.graphics.newImage(data)
    texture:setFilter("nearest", "nearest")
    return texture
end

---@description Builds every tree in the forest and optionally runs all-tree regression checks.
---@return nil
function love.load()
    for _, argument in ipairs(arg or {}) do
        if argument == "--verify" then verify = true end
    end
    world = LightWorld:new()
    world:SetColor(0.035, 0.045, 0.025, 1)
    light = Star:new(world, 1500)
    light:SetPosition(810, 475, 145)
    light:SetColor(0.9, 0.95, 0.75, 1)
    light.Blur = false
    local texture = makeTree()
    local positions = {
        { 110, 125 }, { 300, 150 }, { 540, 130 }, { 770, 145 }, { 955, 180 },
        { 210, 275 }, { 435, 275 }, { 650, 285 }, { 875, 310 },
        { 105, 430 }, { 340, 420 }, { 555, 455 }, { 760, 455 },
        { 225, 575 }, { 465, 580 }, { 695, 590 }, { 945, 570 },
    }
    for _, position in ipairs(positions) do
        local body = Body:new(world)
        body:SetPosition(position[1], position[2], 0)
        trees[#trees + 1] = CastImageShadow:new(body, texture, 80, 100)
    end
    if verify then
        require("Regression").run(world, light, trees)
    end
end

---@description Updates ground shadows and optionally follows the mouse with the light.
---@param dt number Elapsed frame time in seconds.
---@return nil
function love.update(dt)
    if followMouse and not capture.auto then
        light:SetPosition(love.mouse.getX(), love.mouse.getY(), 145)
    end
    world:Update(dt)
end

---@description Draws the grass, ground shadows, and every tree in depth order.
---@return nil
function love.draw()
    local width, height = love.graphics.getDimensions()
    love.graphics.origin()
    love.graphics.clear(0.36, 0.58, 0.27, 1)
    love.graphics.setColor(0.33, 0.54, 0.24, 1)
    for y = 0, height, 24 do
        for x = 0, width, 24 do
            if (x + y) % 72 == 0 then love.graphics.rectangle("fill", x, y, 2, 3) end
        end
    end
    world:Draw()
    for _, tree in ipairs(trees) do tree:DrawSprite() end
    local x, y = light:GetPosition()
    love.graphics.setColor(1, 0.98, 0.74, 1)
    love.graphics.circle("fill", x, y, 5)
    love.graphics.circle("line", x, y, 12)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, height - 34, width, 34)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("17 upright trees | M: mouse light " .. (followMouse and "on" or "off") ..
        " | B: soft shadows | R: reset light | F12: capture | Esc: exit", 12, height - 24)
    capture.draw()
end

---@description Toggles light movement and filtering or forwards capture and exit controls.
---@param key string Pressed key name.
---@return nil
function love.keypressed(key)
    if key == "m" then
        followMouse = not followMouse
    elseif key == "b" then
        light.Blur = not light.Blur
    elseif key == "r" then
        followMouse = false
        light:SetPosition(810, 475, 145)
    else
        capture.keypressed(key)
    end
end

---@description Resizes world lighting to match the window.
---@param width number New logical width.
---@param height number New logical height.
---@return nil
function love.resize(width, height)
    if world then world:Resize(width, height) end
end
