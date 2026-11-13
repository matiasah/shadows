---@module Demonstrates a transparent image casting a colored, soft-edged shadow.
local capture = require("Capture").new("image-shadow-capture.png")
local LightWorld = require("shadows.LightWorld")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local ImageShadow = require("shadows.ShadowShapes.ImageShadow")

---@type LightWorld?
local world
---@type Star?
local light
---@type Body?
local imageBody
---@type love.Canvas?
local flower
---@type number
local imageX = 390
---@type number
local imageY = 220
---@type number
local lightX = 190
---@type number
local lightY = 160
---@type boolean
local softShadows = true

--- @description Creates a transparent flower image and adds it as a shadow caster.
--- @return nil
function love.load()
	local width, height = love.graphics.getDimensions()
	local imageSize = 192
	flower = love.graphics.newCanvas(imageSize, imageSize)

	love.graphics.push("all")
	love.graphics.setCanvas(flower)
	love.graphics.clear(0, 0, 0, 0)
	love.graphics.origin()
	love.graphics.setColor(0.16, 0.48, 0.22, 1)
	love.graphics.setLineWidth(9)
	love.graphics.line(96, 102, 96, 174)
	love.graphics.polygon("fill", 96, 143, 59, 124, 66, 154)
	love.graphics.polygon("fill", 96, 153, 130, 130, 124, 160)

	for petal = 0, 11 do
		love.graphics.push()
		love.graphics.translate(96, 82)
		love.graphics.rotate(petal * math.pi / 6)
		love.graphics.setColor(1, petal % 2 == 0 and 0.65 or 0.78, 0.2, 1)
		love.graphics.ellipse("fill", 0, -36, 16, 31)
		love.graphics.pop()
	end

	love.graphics.setColor(0.43, 0.23, 0.1, 1)
	love.graphics.circle("fill", 96, 82, 25)
	love.graphics.setColor(0.95, 0.75, 0.28, 1)
	for seed = 0, 17 do
		local angle = seed * math.pi * 2 / 18
		love.graphics.circle("fill", 96 + math.cos(angle) * 16, 82 + math.sin(angle) * 16, 2.2)
	end
	love.graphics.setCanvas()
	love.graphics.pop()

	world = LightWorld:new()
	world:SetColor(0.12, 0.13, 0.15, 1)

	light = Star:new(world, math.max(width, height) * 1.5)
	light.SizeRadius = 10
	light:SetColor(1, 0.9, 0.68, 0.65)

	imageBody = Body:new(world)
	imageBody:SetPosition(imageX, imageY, 16)
	ImageShadow:new(imageBody, flower, imageSize, imageSize)
end

--- @description Moves the full-scene light and refreshes the world.
--- @param dt number Elapsed frame time in seconds.
--- @return nil
function love.update(dt)
	if capture.auto then
		lightX, lightY = 190, 160
	else
		lightX, lightY = love.mouse.getPosition()
	end
	light:SetPosition(lightX, lightY, 70)
	light.Blur = softShadows
	world:Update(dt)
end

--- @description Draws a checkerboard floor, the image, its lighting, and controls.
--- @return nil
function love.draw()
	local width, height = love.graphics.getDimensions()
	love.graphics.origin()
	love.graphics.clear(0.72, 0.7, 0.63, 1)

	for y = 0, height, 48 do
		for x = 0, width, 48 do
			if (math.floor(x / 48) + math.floor(y / 48)) % 2 == 0 then
				love.graphics.setColor(0.77, 0.75, 0.69, 1)
				love.graphics.rectangle("fill", x, y, 48, 48)
			end
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(flower, imageX, imageY)
	world:Draw()

	love.graphics.setColor(1, 0.92, 0.56, 0.9)
	love.graphics.circle("line", lightX, lightY, 9)
	love.graphics.circle("fill", lightX, lightY, 3)
	love.graphics.setColor(0, 0, 0, 0.68)
	love.graphics.rectangle("fill", 0, height - 34, width, 34)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print(
		"ImageShadow: transparent flower casts a textured shadow | Move mouse: light | B: soft shadows " ..
			(softShadows and "on" or "off") .. " | F12: capture | Esc: exit",
		12,
		height - 25
	)
	capture.draw()
end

--- @description Toggles soft shadows or forwards capture and exit controls.
--- @param key string Pressed key name.
--- @return nil
function love.keypressed(key)
	if key == "b" then
		softShadows = not softShadows
	else
		capture.keypressed(key)
	end
end

--- @description Resizes the world and full-scene light canvases with the window.
--- @param width number New window width.
--- @param height number New window height.
--- @return nil
function love.resize(width, height)
	if world then
		world:Resize(width, height)
		light.Radius = math.max(width, height) * 1.5
	end
end
