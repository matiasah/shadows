---@module Owns lights, stars, shadow bodies, rooms, and the composed scene canvas.
module("shadows.LightWorld", package.seeall)

Object                                                 = require("shadows.Object")

Shadows                                                = require("shadows")
Body                                                   = require("shadows.Body")
BodyTransform                                          = require("shadows.BodyTransform")
PriorityQueue                                          = require("shadows.PriorityQueue")

---@class ShadowBounds
---@field x number World-space centroid x-coordinate.
---@field y number World-space centroid y-coordinate.
---@field z number World-space centroid height.
---@field radius number Shape bounding radius.
---@field angle number World-space rotation in degrees.

--- @class LightWorld: Object
--- @field Canvas love.Canvas Composited world canvas.
--- @field Width number Canvas width.
--- @field Height number Canvas height.
--- @field BorderRadius number Half-diagonal of the world canvas.
--- @field Bodies PriorityQueue Bodies ordered by height.
--- @field BodyTracks table Physics-body-following transforms.
--- @field Rooms Room[] Registered dark rooms.
--- @field Lights Light[] Registered local lights.
--- @field Stars Star[] Registered full-scene lights.
--- @field Changed boolean Whether all shadow caches need rebuilding.
--- @field private ShapeBounds table<Shadow, ShadowBounds> Last updated shape bounds, including removed shapes until the next update.
--- @field UpdateCanvas boolean? Whether the composed canvas needs redrawing.
--- @field UpdateStars boolean? Whether stars need updating.
--- @field x number Camera x-coordinate.
--- @field y number Camera y-coordinate.
--- @field z number Camera scale.
--- @field R number Ambient red channel in the 0-1 range; defaults to 0.
--- @field G number Ambient green channel in the 0-1 range; defaults to 0.
--- @field B number Ambient blue channel in the 0-1 range; defaults to 0.
--- @field A number Ambient alpha channel in the 0-1 range; defaults to 1.
--- @field private __index LightWorld Instance method lookup.
--- @field private __type string Runtime type name.
LightWorld                                             = setmetatable({}, Object)
LightWorld.__index                                     = LightWorld
LightWorld.__type                                      = "LightWorld"

LightWorld.R, LightWorld.G, LightWorld.B, LightWorld.A = 0, 0, 0, 1
LightWorld.x, LightWorld.y, LightWorld.z               = 0, 0, 1

--- @description Creates a world and allocates its canvas at the current display size.
--- @return LightWorld world New light world.
function LightWorld:new()
	local self = setmetatable({}, LightWorld)
	local Width, Height = love.graphics.getDimensions()

	self.Canvas = love.graphics.newCanvas(Width, Height)
	self.Width = Width
	self.Height = Height
	self.BorderRadius = math.sqrt(Width * Width + Height * Height) * 0.5

	self.Bodies = PriorityQueue:new() -- Bodies sorted by height

	self.BodyTracks = {}
	self.Rooms = {}
	self.Lights = {}
	self.Stars = {}
	self.ShapeBounds = {}
	self.Changed = true

	return self
end

--- @description Resizes the world canvas and all registered star canvases.
--- @param Width number New canvas width.
--- @param Height number New canvas height.
--- @return nil
function LightWorld:Resize(Width, Height)
	self.Canvas = love.graphics.newCanvas(Width, Height)
	self.Width = Width
	self.Height = Height
	self.BorderRadius = math.sqrt(Width * Width + Height * Height) * 0.5

	self.UpdateCanvas = true

	for Index, Light in pairs(self.Stars) do
		Light:Resize(Width, Height)
	end
end

--- @description Copies the bodies and supported fixtures from a LÖVE physics world.
--- @param PhysicsWorld love.World Physics world to import.
--- @return nil
function LightWorld:InitFromPhysics(PhysicsWorld)
	for _, BodyObject in pairs(PhysicsWorld:getBodies()) do
		Body:new(self):InitFromPhysics(BodyObject)
	end
end

--- @description Returns the world's canvas half-diagonal.
--- @return number radius Border radius.
function LightWorld:GetBorderRadius()
	return self.BorderRadius
end

--- @description Returns the world canvas width.
--- @return number width Canvas width.
function LightWorld:GetWidth()
	return self.Width
end

--- @description Returns the world canvas height.
--- @return number height Canvas height.
function LightWorld:GetHeight()
	return self.Height
end

--- @description Registers a body with this world and marks its canvas dirty.
--- @param Body Body Body to register.
--- @return nil
function LightWorld:AddBody(Body)
	Body.World = self

	self.UpdateCanvas = true
	self.Bodies:Insert(Body)
end

---@description Invalidates local lights intersecting shape bounds and all full-scene stars.
---@param Bounds ShadowBounds Previous or current shape bounds.
---@return nil
function LightWorld:InvalidateBounds(Bounds)
	for _, Light in pairs(self.Lights) do
		local x, y = Light:GetPosition()
		local radius = Light.Radius + Bounds.radius
		if (Bounds.x - x)^2 + (Bounds.y - y)^2 <= radius^2 then
			Light.ShadowChanged = true
		end
	end
	for _, Star in pairs(self.Stars) do
		Star.ShadowChanged = true
	end
end

---@description Tracks shape changes and invalidates lights using both old and new bounds.
---@return nil
function LightWorld:UpdateShapeBounds()
	local current = {}
	for i = 1, self.Bodies:GetLength() do
		local body = self.Bodies:Get(i)
		local shapes = body:GetShapes()
		for j = 1, shapes:GetLength() do
			local shape = shapes:Get(j)
			local x, y, z = shape:GetCentroid()
			local radius = shape:GetRadius()
			local angle = shape:GetTransform():GetRotation()
			local previous = self.ShapeBounds[shape]
			if body:GetChanged() or shape:GetChanged() or not previous
				or previous.x ~= x or previous.y ~= y or previous.z ~= z
				or previous.radius ~= radius or previous.angle ~= angle then
				shape:SetChanged(true)
				if previous then self:InvalidateBounds(previous) end
				current[shape] = { x = x, y = y, z = z, radius = radius, angle = angle }
				self:InvalidateBounds(current[shape])
			else
				current[shape] = previous
			end
		end
	end
	for shape, previous in pairs(self.ShapeBounds) do
		if not current[shape] then self:InvalidateBounds(previous) end
	end
	self.ShapeBounds = current
end

--- @description Registers a local light with this world.
--- @param Light Light Light to register.
--- @return Light light Registered light.
function LightWorld:AddLight(Light)
	local ID = #self.Lights + 1
	Light:SetWorld(self)
	Light.ID = ID

	self.UpdateCanvas = true
	self.Lights[ID] = Light

	return Light
end

--- @description Registers a star with this world.
--- @param Star Star Star to register.
--- @return Star star Registered star.
function LightWorld:AddStar(Star)
	local ID = #self.Stars + 1
	Star:SetWorld(self)
	Star.ID = ID

	self.UpdateCanvas = true
	self.Stars[ID] = Star

	return Star
end

--- @description Registers a dark room with this world.
--- @param Room Room Room to register.
--- @return Room room Registered room.
function LightWorld:AddRoom(Room)
	local ID = #self.Rooms + 1
	Room.World = self
	Room.ID = Room

	self.UpdateCanvas = true
	self.Rooms[ID] = Room

	return Room
end

--- @description Tracks a physics body using a transform registered with this world.
--- @param Body love.Body Physics body to follow.
--- @return BodyTransform transform Tracked transform.
function LightWorld:TrackBody(Body)
	local Transform = BodyTransform:new(Body)
	local ID = #self.BodyTracks + 1
	Transform.World = self
	Transform.TransformID = ID

	self.BodyTracks[ID] = Transform

	return Transform
end

--- @description Draws the composed world canvas at the origin.
--- @return nil
function LightWorld:Draw()
	love.graphics.origin()
	love.graphics.setBlendMode("multiply", "premultiplied")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.Canvas, 0, 0)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

--- @description Sets the ambient RGBA color and invalidates the world canvas.
--- @param R number Red channel in the 0-1 range.
--- @param G number Green channel in the 0-1 range.
--- @param B number Blue channel in the 0-1 range.
--- @param A number Alpha channel in the 0-1 range.
--- @return nil
function LightWorld:SetColor(R, G, B, A)
	if R ~= self.R then
		self.R = R
		self.UpdateCanvas = true
	end

	if G ~= self.G then
		self.G = G
		self.UpdateCanvas = true
	end

	if B ~= self.B then
		self.B = B
		self.UpdateCanvas = true
	end

	if A ~= self.A then
		self.A = A
		self.UpdateCanvas = true
	end
end

--- @description Returns the world color channels in the implementation's order.
--- @return number R Red channel in the 0-1 range.
--- @return number G Green channel in the 0-1 range.
--- @return number A Alpha channel in the 0-1 range.
--- @return number B Blue channel in the 0-1 range.
function LightWorld:GetColor()
	return self.R, self.G, self.A, self.B
end

--- @description Sets the camera position and scale and invalidates world rendering.
--- @param x number Camera x-coordinate.
--- @param y number Camera y-coordinate.
--- @param z number? Camera scale; current scale is retained when omitted.
--- @return nil
function LightWorld:SetPosition(x, y, z)
	if x ~= self.x then
		self.x = x
		self.UpdateCanvas = true
		self.UpdateStars = true
	end

	if y ~= self.y then
		self.y = y
		self.UpdateCanvas = true
		self.UpdateStars = true
	end

	if z then
		if z ~= self.z then
			self.z = z
			self.UpdateCanvas = true
			self.UpdateStars = true
		end
	end
end

--- @description Returns camera position and scale.
--- @return number x Camera x-coordinate.
--- @return number y Camera y-coordinate.
--- @return number z Camera scale.
function LightWorld:GetPosition()
	return self.x, self.y, self.z
end

--- @description Updates scene objects, lights, stars, rooms, and the world canvas.
--- @param dt number? Elapsed time in seconds; currently unused.
--- @return nil
function LightWorld:Update(dt)
	for Index, Transform in pairs(self.BodyTracks) do
		Transform:Update()
	end

	for Index, Body in pairs(self.Bodies:GetArray()) do
		Body:Update()
	end

	Shadows.insertionSort(self.Bodies:GetArray())
	self:UpdateShapeBounds()

	for Index, Light in pairs(self.Lights) do
		Light:Update()
	end; love.graphics.setCanvas()

	for Index, Star in pairs(self.Stars) do
		Star:Update()
	end; love.graphics.setCanvas()

	for Index, Room in pairs(self.Rooms) do
		Room:Update()
	end; love.graphics.setCanvas()

	self.Changed = false

	if self.UpdateCanvas then
		self.UpdateCanvas = nil
		self.UpdateStars = nil

		love.graphics.setCanvas(self.Canvas)
		love.graphics.setShader()
		love.graphics.setBlendMode("alpha", "alphamultiply")
		love.graphics.clear(self.R, self.G, self.B, self.A)

		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setBlendMode("add", "alphamultiply")
		love.graphics.origin()
		love.graphics.scale(1, 1)

		for _, Light in pairs(self.Stars) do
			if not Light:GetCanvasDestroyed() then
				love.graphics.draw(Light.Canvas, 0, 0)
			end
		end

		love.graphics.translate(-self.x * self.z, -self.y * self.z)
		love.graphics.scale(self.z, self.z)
		love.graphics.setShader(Shadows.DarkenShader)
		love.graphics.setBlendMode("alpha", "alphamultiply")

		for _, Room in pairs(self.Rooms) do
			Room:Draw()
		end

		love.graphics.setShader()
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setBlendMode("add", "alphamultiply")

		love.graphics.origin()
		love.graphics.translate(-self.x * self.z, -self.y * self.z)
		love.graphics.scale(self.z, self.z)

		for _, Light in pairs(self.Lights) do
			if not Light:GetCanvasDestroyed() then
				local x, y = Light:GetPosition()

				love.graphics.draw(Light.Canvas, x - Light.Radius, y - Light.Radius)
			end
		end

		love.graphics.setBlendMode("alpha", "alphamultiply")
		love.graphics.origin()
	end

	for i = 1, self.Bodies:GetLength() do
		local Body = self.Bodies:Get(i)
		local Shapes = Body:GetShapes()

		Body:SetChanged(false)
		for j = 1, Shapes:GetLength() do
			Shapes:Get(j):SetChanged(false)
		end
	end

	love.graphics.setCanvas()
	love.graphics.setShader()
end

--- @description Callback for custom shadow geometry drawn by each light or star.
--- @param Light Light|Star Light currently rendering.
--- @return nil
function LightWorld:DrawShadows(Light)
	-- Light object can be of type 'Light' or 'Star'
end

--- @description Callback for custom sprites that should cover shadow geometry.
--- @param Light Light|Star Light currently rendering.
--- @return nil
function LightWorld:DrawSprites(Light)
	-- Light object can be of type 'Light' or 'Star'
end

--- @description Marks the world as changed to force shadow regeneration.
--- @return nil
function LightWorld:ForceUpdate()
	self.Changed = true
end

return LightWorld
