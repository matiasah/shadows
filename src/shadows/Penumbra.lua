---@module Builds occluder-distance and filter-radius fields for contact-hardening shadows.
local Shadows = require("shadows")
local DPI = require("shadows.DPI")

---@type number
local FILTER_RADIUS_SCALE = 0.9

---@class Penumbra
---@field private Mask love.Canvas Occluder silhouette mask.
---@field private Field love.Canvas Nearest-occluder coordinates and validity.
---@field private Scratch love.Canvas Jump-flood ping-pong target.
---@field private Radius love.Canvas Per-pixel shadow filter radius.
---@field private Scale number World-to-canvas scale used for filtering.
---@field private __index Penumbra Instance method lookup.
local Penumbra = {}
Penumbra.__index = Penumbra

---@description Allocates filtering buffers with the shadow canvas dimensions and DPI.
---@param Canvas love.Canvas Shadow canvas whose dimensions and DPI are matched.
---@return Penumbra penumbra New filtering buffers.
function Penumbra:new(Canvas)
    local width, height = Canvas:getDimensions()
    local scale = DPI.getCanvasScale(Canvas)
    local self = setmetatable({}, Penumbra)
    self.Mask = love.graphics.newCanvas(width, height, { dpiscale = scale, msaa = 4 })
    self.Field = love.graphics.newCanvas(width, height, { dpiscale = scale, format = "rgba16f" })
    self.Scratch = love.graphics.newCanvas(width, height, { dpiscale = scale, format = "rgba16f" })
    self.Radius = love.graphics.newCanvas(width, height, { dpiscale = scale, format = "rgba16f" })
    self.Scale = 1
    self.Field:setFilter("nearest", "nearest")
    self.Scratch:setFilter("nearest", "nearest")
    return self
end

---@description Draws eligible body silhouettes using the current world-to-canvas transform.
---@param Light Light|Star Light whose bodies and sprite callback provide silhouettes.
---@return nil
function Penumbra:DrawOccluders(Light)
    local x, y = Light:GetPosition()
    for i = 1, Light.World.Bodies:GetLength() do
        local body = Light.World.Bodies:Get(i)
        local shapes = body:GetShapes()
        for j = 1, shapes:GetLength() do
            local shape = shapes:Get(j)
            local sx, sy, sz = shape:GetCentroid()
            local radius = Light:GetRadius() + shape:GetRadius()
            if sz > 0 and (sx - x)^2 + (sy - y)^2 < radius^2 then
                love.graphics.setShader(Shadows.ShapeShader)
                if shape.Texture then
                    love.graphics.draw(shape.Texture, sx, sy, shape:GetTransform():GetRadians(),
                        shape:GetWidth() / shape.Texture:getWidth(),
                        shape:GetHeight() / shape.Texture:getHeight())
                else
                    shape:Draw(math.huge)
                end
            end
        end
    end
    love.graphics.setShader(Shadows.ShapeShader)
    Light.World:DrawSprites(Light)
end

---@description Rebuilds occluder-distance and filter-radius fields for the current light.
---@param Light Light|Star Light being regenerated.
---@param Scale number? World-to-canvas scale; defaults to the star camera scale or 1.
---@return nil
function Penumbra:Update(Light, Scale)
    love.graphics.setCanvas(self.Mask)
    love.graphics.clear()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setColor(1, 1, 1, 1)
    self:DrawOccluders(Light)

    love.graphics.origin()
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setCanvas(self.Field)
    love.graphics.setShader(Shadows.OccluderSeedShader)
    love.graphics.draw(self.Mask)

    local width, height = self.Field:getPixelDimensions()
    Shadows.OccluderDistanceShader:send("PixelSize", { width, height })
    love.graphics.setShader(Shadows.OccluderDistanceShader)
    local step = 1
    while step < math.max(width, height) do
        step = step * 2
    end
    while step >= 1 do
        love.graphics.setCanvas(self.Scratch)
        Shadows.OccluderDistanceShader:send("Step", step)
        love.graphics.draw(self.Field)
        self.Field, self.Scratch = self.Scratch, self.Field
        step = step / 2
    end
    love.graphics.setShader()
    Light.ShadowCanvas:generateMipmaps()
    local scale = Scale or (Light.Star and select(3, Light.World:GetPosition())) or 1
    self.Scale = scale
    local x, y = Light:GetCanvasCenter()
    Shadows.PenumbraRadiusShader:send("DpiScale", DPI.getCanvasScale(Light.ShadowCanvas))
    Shadows.PenumbraRadiusShader:send("Size", { Light.ShadowCanvas:getDimensions() })
    Shadows.PenumbraRadiusShader:send("Position", { x, y })
    Shadows.PenumbraRadiusShader:send("SourceRadius",
        Light.SizeRadius * scale * FILTER_RADIUS_SCALE)
    Shadows.PenumbraRadiusShader:send("MinimumRadius", 8 * scale * FILTER_RADIUS_SCALE)
    Shadows.PenumbraRadiusShader:send("Occluders", self.Mask)
    Shadows.PenumbraRadiusShader:send("NearestOccluder", self.Field)
    love.graphics.setCanvas(self.Radius)
    love.graphics.setShader(Shadows.PenumbraRadiusShader)
    love.graphics.draw(Light.ShadowCanvas)
    love.graphics.setShader()
end

---@description Configures normalized filtering using the cached radius field.
---@param Light Light|Star Light whose shadow canvas will be composited next.
---@return nil
function Penumbra:Apply(Light)
    Shadows.PenumbraShader:send("DpiScale", DPI.getCanvasScale(Light.ShadowCanvas))
    Shadows.PenumbraShader:send("Size", { Light.ShadowCanvas:getDimensions() })
    Shadows.PenumbraShader:send("RadiusScale", self.Scale)
    Shadows.PenumbraShader:send("Occluders", self.Mask)
    Shadows.PenumbraShader:send("NearestOccluder", self.Field)
    Shadows.PenumbraShader:send("FilterRadius", self.Radius)
    love.graphics.setShader(Shadows.PenumbraShader)
end

return Penumbra
