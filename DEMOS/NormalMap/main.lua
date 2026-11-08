--- Runs the normal-map lighting showcase and its screenshot controls.
local capture      = require("Capture").new("normalmap-capture.png")
local shadows      = require("shadows")

local LightWorld   = require("shadows.LightWorld")
local Light        = require("shadows.Light")
local NormalShadow = require("shadows.ShadowShapes.NormalShadow")
local Body         = require("shadows.Body")

--- @description Creates the light world, light, normal map, and background texture.
--- @return nil
function love.load()
	---@type LightWorld
	newLightWorld = LightWorld:new()
	---@type Light
	newLight      = Light:new(newLightWorld, 400)
	newLight:SetColor(255, 255, 255, 255)

	---@type Body
	newBody = Body:new(newLightWorld)
	---@type NormalShadow
	newNormalShadow = NormalShadow:new(newBody, love.graphics.newImage("DEMOS/NormalMap/Normal.png"))
	---@type love.Image
	newImage = love.graphics.newImage("DEMOS/NormalMap/Texture.jpg")
end

--- @description Moves the light and updates the scene.
--- @param dt number Elapsed frame time in seconds.
--- @return nil
function love.update(dt)
	if capture.auto then
		newLight:SetPosition(512, 360, 20)
	else
		newLight:SetPosition(love.mouse.getX(), love.mouse.getY(), 20)
	end
	newLightWorld:Update()
end

--- @description Draws the background and lit scene.
--- @return nil
function love.draw()
	love.graphics.setColor(255, 255, 255, 255)
	love.graphics.origin()

	love.graphics.draw(newImage, 0, 0)

	newLightWorld:Draw()
	capture.draw()
	--- @description Forwards key presses to the shared capture controls.
	--- @param key string Pressed key name.
	--- @return nil
	function love.keypressed(key)
		capture.keypressed(key)
	end
end
