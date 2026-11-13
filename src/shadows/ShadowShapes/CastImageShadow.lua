---@module Provides upright image casters with projected alpha shadows and independently shaded sprites.
module("shadows.ShadowShapes.CastImageShadow", package.seeall)

local ImageShadow = require("shadows.ShadowShapes.ImageShadow")
local OutputShadow = require("shadows.OutputShadow")
local DPI = require("shadows.DPI")

---@class CastImageShadow:ImageShadow
---@field Texture love.Texture Upright sprite; alpha, not RGB, defines blocking coverage.
---@field Width number? World width; defaults to texture width.
---@field Height number? World height; defaults to texture height.
---@field Body Body Owning body.
---@field Transform Transform Ground anchor at the sprite's bottom center, with ground-plane rotation.
---@field Changed boolean? Inherited geometry-dirty flag; defaults to nil.
---@field private LightingCanvas love.Canvas? Accumulated sprite illumination.
---@field private VisibilityCanvas love.Canvas? Per-light sprite visibility.
---@field private SpriteMesh love.Mesh? Screen projection of the upright plane.
---@field private __index CastImageShadow Instance method lookup.
---@field private __type string Runtime shape identifier.
CastImageShadow = setmetatable({}, ImageShadow)
CastImageShadow.__index = CastImageShadow
CastImageShadow.__type = "CastImageShadow"
CastImageShadow.__lt = ImageShadow.__lt
CastImageShadow.__le = ImageShadow.__le

---@type string
local intersection = [[
    extern Image Blocker;
    extern vec3 BlockerAnchor;
    extern vec2 BlockerSize;
    extern vec2 BlockerAxis;
    extern vec3 Source;
    float coverage(vec3 point) {
        vec2 normal = vec2(-BlockerAxis.y, BlockerAxis.x);
        float denominator = dot(point.xy - Source.xy, normal);
        if (abs(denominator) < 0.0001) return 0.0;
        float t = dot(BlockerAnchor.xy - Source.xy, normal) / denominator;
        if (t <= 0.0001 || t >= 0.9999) return 0.0;
        vec3 hit = mix(Source, point, t) - BlockerAnchor;
        vec2 uv = vec2(dot(hit.xy, BlockerAxis) / BlockerSize.x + 0.5,
                       1.0 - hit.z / BlockerSize.y);
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return 0.0;
        return Texel(Blocker, uv).a;
    }
]]

---@type love.Shader
local groundShader = love.graphics.newShader(intersection .. [[
    extern vec2 GroundOrigin;
    extern float GroundScale;
    extern float GroundHeight;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 pixel) {
        return vec4(1.0, 1.0, 1.0,
            coverage(vec3(pixel / GroundScale + GroundOrigin, GroundHeight)));
    }
]])

---@type string
local receiver = [[
    extern vec3 ReceiverAnchor;
    extern vec2 ReceiverSize;
    extern vec2 ReceiverAxis;
    vec3 surface(vec2 uv) {
        return ReceiverAnchor + vec3(ReceiverAxis * ((uv.x - 0.5) * ReceiverSize.x),
                                     (1.0 - uv.y) * ReceiverSize.y);
    }
]]

---@type love.Shader
local visibilityShader = love.graphics.newShader(intersection .. receiver .. [[
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 pixel) {
        return vec4(1.0, 1.0, 1.0, coverage(surface(uv)));
    }
]])

---@type love.Shader
local lightingShader = love.graphics.newShader(receiver .. [[
    extern vec3 Source;
    extern vec4 Tint;
    extern float Radius;
    extern float ArcCos;
    extern vec2 Direction;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 pixel) {
        vec3 delta = Source - surface(uv);
        float distanceToLight = length(delta);
        float facing = max(dot(normalize(delta + vec3(0.0, 0.0, 0.0001)),
                               vec3(-ReceiverAxis.y, ReceiverAxis.x, 0.0)), 0.0);
        float falloff = max(1.0 - distanceToLight / Radius, 0.0);
        float cone = dot(normalize(-delta.xy + vec2(0.0001)), Direction) >= ArcCos ? 1.0 : 0.0;
        return vec4(Tint.rgb * Tint.a * facing * falloff * cone * Texel(tex, uv).r, 1.0);
    }
]])

---@type love.Shader
local spriteShader = love.graphics.newShader [[
    extern Image Illumination;
    vec4 effect(vec4 color, Image tex, vec2 uv, vec2 pixel) {
        vec4 sprite = Texel(tex, uv);
        return vec4(sprite.rgb * min(Texel(Illumination, uv).rgb, vec3(1.0)), sprite.a) * color;
    }
]]

---@description Creates an upright image anchored at its body's ground position.
---@param body Body Owning body.
---@param texture love.Texture Sprite texture with transparent surroundings.
---@param width number? World width; defaults to texture width.
---@param height number? World height; defaults to texture height.
---@return CastImageShadow shape Registered upright sprite.
function CastImageShadow:new(body, texture, width, height)
    assert(body and texture, "CastImageShadow requires a body and texture")
    local actualWidth, actualHeight = width or texture:getWidth(), height or texture:getHeight()
    assert(actualWidth > 0 and actualWidth < math.huge and actualHeight > 0 and actualHeight < math.huge,
        "CastImageShadow dimensions must be positive and finite")
    local shape = ImageShadow.new(self, body, texture, width, height)
    return setmetatable(shape, CastImageShadow)
end

---@description Returns the sprite's upper height for height-layer sorting.
---@return number x Ground-anchor x-coordinate.
---@return number y Ground-anchor y-coordinate.
---@return number z Top height above the ground.
function CastImageShadow:GetPosition()
    local x, y, z = self.Transform:GetPosition()
    return x, y, z + self:GetHeight()
end

---@description Returns the culling center and top height used by the world.
---@return number x Ground-anchor x-coordinate.
---@return number y Ground-anchor y-coordinate.
---@return number z Top height.
function CastImageShadow:GetCentroid()
    return self:GetPosition()
end

---@description Supplies the upright plane and dimensions to a shader.
---@param shader love.Shader Destination shader.
---@param prefix string Uniform prefix, either Blocker or Receiver.
---@return nil
function CastImageShadow:SendPlane(shader, prefix)
    local angle = self.Transform:GetRadians()
    shader:send(prefix .. "Anchor", { self.Transform:GetPosition() })
    shader:send(prefix .. "Size", { self:GetWidth(), self:GetHeight() })
    shader:send(prefix .. "Axis", { math.cos(angle), math.sin(angle) })
end

---@description Queues exact ray-plane alpha projection onto the ground layer.
---@param shapes OutputShadow[] Destination draw calls.
---@param body Body Owning body; retained for the shared shape interface.
---@param deltaX number Unused horizontal canvas offset.
---@param deltaY number Unused vertical canvas offset.
---@param layer number Current receiving height layer.
---@param light Light|Star Light producing the projection.
---@return nil
function CastImageShadow:GenerateShadows(shapes, body, deltaX, deltaY, layer, light)
    if layer ~= 0 then return end
    local x, y, z = light:GetPosition()
    local originX, originY, scale = x - light.Radius, y - light.Radius, 1
    if light.Star then
        originX, originY, scale = light.World:GetPosition()
    end
    local output = OutputShadow:new("rectangle", "fill",
        x - light.Radius, y - light.Radius, light.Radius * 2, light.Radius * 2)
    output:SetShader(groundShader)
    output:SendShader("Blocker", self.Texture)
    output:SendShader("BlockerAnchor", { self.Transform:GetPosition() })
    output:SendShader("BlockerSize", { self:GetWidth(), self:GetHeight() })
    local angle = self.Transform:GetRadians()
    output:SendShader("BlockerAxis", { math.cos(angle), math.sin(angle) })
    output:SendShader("Source", { x, y, z })
    output:SendShader("GroundOrigin", { originX, originY })
    output:SendShader("GroundScale", scale * DPI.getCanvasScale(light.ShadowRenderCanvas))
    output:SendShader("GroundHeight", 0)
    shapes[#shapes + 1] = output
end

---@description Leaves upright sprite restoration to DrawSprite instead of erasing other ground shadows.
---@param height number? Unused receiving-layer height.
---@return nil
function CastImageShadow:Draw(height)
end

---@description Accumulates one light, including occlusion from every other upright sprite.
---@param light Light|Star Source of sprite illumination.
---@return nil
function CastImageShadow:Illuminate(light)
    love.graphics.setCanvas(self.VisibilityCanvas)
    love.graphics.clear(1, 1, 1, 1)
    love.graphics.setBlendMode("subtract", "alphamultiply")
    love.graphics.setShader(visibilityShader)
    self:SendPlane(visibilityShader, "Receiver")
    visibilityShader:send("Source", { light:GetPosition() })
    local world = self.Body.World
    for _, body in ipairs(world.Bodies:GetArray()) do
        for _, shape in ipairs(body:GetShapes():GetArray()) do
            if shape ~= self and shape.__type == "CastImageShadow" then
                shape:SendPlane(visibilityShader, "Blocker")
                visibilityShader:send("Blocker", shape.Texture)
                love.graphics.draw(self.Texture, 0, 0, 0,
                    self.VisibilityCanvas:getWidth() / self.Texture:getWidth(),
                    self.VisibilityCanvas:getHeight() / self.Texture:getHeight())
            end
        end
    end
    love.graphics.setCanvas(self.LightingCanvas)
    love.graphics.setBlendMode("add", "premultiplied")
    love.graphics.setShader(lightingShader)
    self:SendPlane(lightingShader, "Receiver")
    lightingShader:send("Source", { light:GetPosition() })
    lightingShader:send("Tint", { light:GetColor() })
    lightingShader:send("Radius", light.Radius)
    lightingShader:send("ArcCos", math.cos(math.rad(light.Arc * 0.5)))
    local angle = light.Transform:GetRadians(-math.pi * 0.5)
    lightingShader:send("Direction", { math.cos(angle), math.sin(angle) })
    love.graphics.draw(self.VisibilityCanvas)
end

---@description Draws the upright sprite after world lighting, with front/back lighting and mutual sprite shadows.
---@return nil
function CastImageShadow:DrawSprite()
    assert(self.Body and self.Body.World, "Cannot draw a detached CastImageShadow")
    local width, height = self:GetWidth(), self:GetHeight()
    local canvasWidth, canvasHeight = math.ceil(width), math.ceil(height)
    if not self.LightingCanvas or self.LightingCanvas:getWidth() ~= canvasWidth
        or self.LightingCanvas:getHeight() ~= canvasHeight then
        self.LightingCanvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
        self.VisibilityCanvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
    end
    love.graphics.push("all")
    local target = love.graphics.getCanvas()
    love.graphics.origin()
    love.graphics.setScissor()
    love.graphics.setStencilTest()
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    local world = self.Body.World
    love.graphics.setCanvas(self.LightingCanvas)
    love.graphics.clear(world.R, world.G, world.B, 1)
    for _, light in pairs(world.Lights) do self:Illuminate(light) end
    for _, light in pairs(world.Stars) do self:Illuminate(light) end
    love.graphics.setCanvas(target)
    love.graphics.setShader(spriteShader)
    spriteShader:send("Illumination", self.LightingCanvas)
    love.graphics.setBlendMode("alpha", "alphamultiply")
    local x, y, z = self.Transform:GetPosition()
    local cameraX, cameraY, zoom = world:GetPosition()
    local angle = self.Transform:GetRadians()
    love.graphics.translate((x - cameraX) * zoom, (y - cameraY - z) * zoom)
    love.graphics.scale(zoom)
    local dx, dy = width * 0.5 * math.cos(angle), width * 0.5 * math.sin(angle)
    local vertices = {
        { -dx, -dy - height, 0, 0 }, { dx, dy - height, 1, 0 },
        { dx, dy, 1, 1 }, { -dx, -dy, 0, 1 },
    }
    if not self.SpriteMesh then
        self.SpriteMesh = love.graphics.newMesh(vertices, "fan", "stream")
    else
        self.SpriteMesh:setVertices(vertices)
    end
    self.SpriteMesh:setTexture(self.Texture)
    love.graphics.draw(self.SpriteMesh)
    love.graphics.pop()
end

return CastImageShadow
