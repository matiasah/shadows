--- Runs the high-DPI rendering regression scene and capture controls.
local capture = require("Capture").new("highdpi-capture.png")
require("shadows")

local LightWorld = require("shadows.LightWorld")
local Light = require("shadows.Light")
local Body = require("shadows.Body")
local CircleShadow = require("shadows.ShadowShapes.CircleShadow")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")

---@type LightWorld
local world
---@type Light
local light

--- @description Creates a test light, body, and geometric shadow shapes.
--- @return nil
function love.load()
    world = LightWorld:new()
    light = Light:new(world, 240)
    light:SetColor(255, 255, 255, 255)
    light:SetPosition(390, 280, 1.1)

    local body = Body:new(world)
    body:SetPosition(330, 300)
    body:SetAngle(-15)
    PolygonShadow:new(body, -28, -18, 30, -18, 30, 18, -28, 18)
    CircleShadow:new(body, 72, -20, 20)
end

--- @description Tracks the pointer and updates the light world.
--- @return nil
function love.update()
    if capture.auto then
        light:SetPosition(390, 280, 1.1)
    else
        light:SetPosition(love.mouse.getX(), love.mouse.getY(), 1.1)
    end
    world:Update()
end

--- @description Renders the scene and reports logical, pixel, and DPI dimensions.
--- @return nil
function love.draw()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    world:Draw()

    local logicalWidth, logicalHeight = love.graphics.getDimensions()
    local pixelWidth, pixelHeight = love.graphics.getPixelDimensions()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format(
        "Screen DPI %.2f | canvas DPI %.2f | logical %dx%d | pixels %dx%d | press S to capture",
        love.graphics.getDPIScale(),
        world.Canvas:getDPIScale(),
        logicalWidth,
        logicalHeight,
        pixelWidth,
        pixelHeight
    ), 12, 12)
    capture.draw()
end

--- @description Forwards keyboard input to the shared screenshot controls.
--- @param key string Pressed key name.
--- @return nil
function love.keypressed(key)
    capture.keypressed(key)
end
