---@module Demonstrates translucent glass panes casting RGB-transmitted shadows.
local capture = require("Capture").new("glass-shadow-capture.png")
local LightWorld = require("shadows.LightWorld")
local Star = require("shadows.Star")
local Body = require("shadows.Body")
local PolygonShadow = require("shadows.ShadowShapes.PolygonShadow")
local DPI = require("shadows.DPI")

---@type LightWorld
local world
---@type Star
local light
---@type table[]
local panes = {}
---@type boolean
local softShadows = true
---@type boolean
local verify = false

---@description Creates a glass pane caster and retains its scene-drawing data.
---@param x number Pane center x-coordinate.
---@param y number Pane center y-coordinate.
---@param z number Pane height.
---@param width number Pane width.
---@param height number Pane height.
---@param red number Red light transmission.
---@param green number Green light transmission.
---@param blue number Blue light transmission.
---@param label string Pane label.
---@return table pane Pane shape and display settings.
local function addPane(x, y, z, width, height, red, green, blue, label)
	local body = Body:new(world)
	body:SetPosition(x, y, z)
	local shape = PolygonShadow:new(body,
		-width * 0.5, -height * 0.5,
		width * 0.5, -height * 0.5,
		width * 0.5, height * 0.5,
		-width * 0.5, height * 0.5)
	shape:SetTransmission(red, green, blue)
	local pane = {
		x = x, y = y, z = z, width = width, height = height,
		red = red, green = green, blue = blue, label = label, shape = shape,
	}
	panes[#panes + 1] = pane
	return pane
end

---@description Verifies that the first pane produces its expected tinted shadow.
---@return nil
local function verifyGlass()
	local pane = panes[1]
	local lightX, lightY, lightZ = light:GetPosition()
	local projection = lightZ / (lightZ - pane.z)
	local farX, farY = pane.x + pane.width * 0.5, pane.y + pane.height * 0.5
	local projectedFarX = lightX + (farX - lightX) * projection
	local projectedFarY = lightY + (farY - lightY) * projection
	local shadowX = (farX + projectedFarX) * 0.5
	local shadowY = (farY + projectedFarY) * 0.5
	local scale = DPI.getCanvasScale(light.ShadowCanvas)
	local pixels = light.ShadowCanvas:newImageData()
	local bestError = math.huge

	for y = math.floor(shadowY) - 8, math.floor(shadowY) + 8 do
		for x = math.floor(shadowX) - 8, math.floor(shadowX) + 8 do
			local red, green, blue = pixels:getPixel(
				math.floor(x * scale), math.floor(y * scale))
			local error = math.abs(red - pane.red) + math.abs(green - pane.green) +
				math.abs(blue - pane.blue)
			if error < bestError then bestError = error end
		end
	end

	assert(bestError < 0.2, "Glass must tint its projected shadow with its RGB transmission")
	print(string.format("Glass verified: RGB shadow transmission error %.3f", bestError))
end

---@description Creates the lighting world, glass casters, and optional pixel verification.
---@return nil
function love.load()
	for _, argument in ipairs(arg or {}) do
		if argument == "--verify" then verify = true end
	end

	world = LightWorld:new()
	world:SetColor(0.055, 0.07, 0.1, 1)
	light = Star:new(world, 1500)
	light:SetColor(1, 0.96, 0.82, 1)
	light:SetPosition(190, 100, 230)
	light.Blur = false

	addPane(340, 220, 50, 130, 84, 0.08, 0.7, 0.92, "CYAN")
	addPane(650, 210, 50, 130, 84, 0.88, 0.22, 0.48, "MAGENTA")
	addPane(480, 420, 50, 130, 84, 0.88, 0.72, 0.16, "AMBER")

	world:Update(0)
	if verify then verifyGlass() end
	light.Blur = softShadows
	world:Update(0)
end

---@description Updates the world and optionally follows the mouse with the light.
---@param dt number Elapsed frame time in seconds.
---@return nil
function love.update(dt)
	if not capture.auto then
		local x, y = love.mouse.getPosition()
		light:SetPosition(x, y, 230)
	end
	light.Blur = softShadows
	world:Update(dt)
end

---@description Draws a checkerboard, glass panes, and controls over the lit world.
---@return nil
function love.draw()
	local width, height = love.graphics.getDimensions()
	love.graphics.origin()
	love.graphics.clear(0.24, 0.27, 0.32, 1)
	for y = 0, height, 40 do
		for x = 0, width, 40 do
			if (math.floor(x / 40) + math.floor(y / 40)) % 2 == 0 then
				love.graphics.setColor(0.3, 0.33, 0.39, 1)
				love.graphics.rectangle("fill", x, y, 40, 40)
			end
		end
	end

	world:Draw()
	for _, pane in ipairs(panes) do
		local left, top = pane.x - pane.width * 0.5, pane.y - pane.height * 0.5
		love.graphics.setColor(pane.red, pane.green, pane.blue, 0.24)
		love.graphics.rectangle("fill", left, top, pane.width, pane.height)
		love.graphics.setColor(pane.red, pane.green, pane.blue, 0.95)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", left, top, pane.width, pane.height)
		love.graphics.setColor(1, 1, 1, 0.9)
		love.graphics.print(pane.label, left + 8, top + 8)
	end

	local lightX, lightY = light:GetPosition()
	love.graphics.setColor(1, 0.96, 0.82, 1)
	love.graphics.circle("fill", lightX, lightY, 5)
	love.graphics.circle("line", lightX, lightY, 12)
	love.graphics.setColor(0, 0, 0, 0.76)
	love.graphics.rectangle("fill", 0, height - 34, width, 34)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.print("RGB glass transmission | Move mouse: light | B: soft shadows " ..
		(softShadows and "on" or "off") .. " | F12: capture | Esc: exit", 12, height - 24)
	capture.draw()
end

---@description Toggles soft shadows or forwards capture and exit controls.
---@param key string Pressed key name.
---@return nil
function love.keypressed(key)
	if key == "b" then
		softShadows = not softShadows
	else
		capture.keypressed(key)
	end
end

---@description Resizes the world and its full-scene light canvases.
---@param width number New logical width.
---@param height number New logical height.
---@return nil
function love.resize(width, height)
	if world then world:Resize(width, height) end
end
