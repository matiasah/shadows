---@module Owns a shared lighting scene and updates its independent LightCamera viewports.
module("shadows.LightWorld", package.seeall)

Object                                                 = require("shadows.Object")

Shadows                                                = require("shadows")
Body                                                   = require("shadows.Body")
BodyTransform                                          = require("shadows.BodyTransform")
PriorityQueue                                          = require("shadows.PriorityQueue")
Settings                                               = require("shadows.Settings")
LightCamera                                            = require("shadows.LightCamera")

---@class ShadowBounds
---@field x number World-space centroid x-coordinate.
---@field y number World-space centroid y-coordinate.
---@field z number World-space centroid height.
---@field radius number Shape bounding radius.
---@field angle number World-space rotation in degrees.

---@class RenderWorkMetrics
---@field ShadowRedraws integer Completed shadow redraws in this update.
---@field GeometryRebuilds integer Completed shape/layer geometry generations in this update.
---@field ShadowDrawCalls integer Cached shadow draw calls executed in this update.
---@field CanvasAllocations integer Successful canvas allocations since the previous update.

---@class WorldFrameMetrics:RenderWorkMetrics
---@field Frame integer Completed world-update sequence number; initially 0.
---@field SharedUpdateMs number CPU milliseconds spent updating shared local lights, including particle simulation.

--- @class LightWorld: Object
--- @field Canvas love.Canvas Composited world canvas.
--- @field Width number Canvas width.
--- @field Height number Canvas height.
--- @field BorderRadius number Half-diagonal of the world canvas.
--- @field DefaultCamera LightCamera Default viewport backing the legacy world rendering API.
--- @field private Cameras LightCamera[] Registered viewports sharing this scene.
--- @field Bodies PriorityQueue Bodies ordered by height.
--- @field BodyTracks table Physics-body-following transforms.
--- @field Rooms Room[] Registered dark rooms.
--- @field Lights Light[] Registered local lights.
--- @field Stars Star[] Registered full-scene lights.
--- @field Changed boolean Whether all shadow caches need rebuilding.
--- @field private ShapeBounds table<Shadow, ShadowBounds> Last updated shape bounds, including removed shapes until the next update.
--- @field Settings Settings Shared rendering settings for this world's lights and stars.
--- @field FrameMetrics WorldFrameMetrics Shared local-light work for the most recent world update; read-only.
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

---@description Creates zeroed shared metrics for a world-update sequence number.
---@param Frame integer Update sequence number.
---@return WorldFrameMetrics metrics Empty shared local-light metrics.
local function newFrameMetrics(Frame)
	return {
		Frame = Frame, SharedUpdateMs = 0,
		ShadowRedraws = 0, GeometryRebuilds = 0, ShadowDrawCalls = 0, CanvasAllocations = 0,
	}
end

---@description Accumulates renderer work into its shared-world or camera-specific bucket.
---@param Metrics RenderWorkMetrics Destination work metrics.
---@param Light Light|Star Renderer being sampled once per world update.
---@return nil
local function sampleFrameWork(Metrics, Light)
	local redraws, rebuilds, draws, allocations = Light:SampleFrameWork()
	Metrics.ShadowRedraws = Metrics.ShadowRedraws + redraws
	Metrics.GeometryRebuilds = Metrics.GeometryRebuilds + rebuilds
	Metrics.ShadowDrawCalls = Metrics.ShadowDrawCalls + draws
	Metrics.CanvasAllocations = Metrics.CanvasAllocations + allocations
end

--- @description Creates a scene with a default camera at the current display size.
--- @return LightWorld world New light world.
function LightWorld:new()
	local self = setmetatable({}, LightWorld)
	self.Settings = Settings:new(self)
	self.FrameMetrics = newFrameMetrics(0)

	self.Bodies = PriorityQueue:new() -- Bodies sorted by height

	self.BodyTracks = {}
	self.Rooms = {}
	self.Lights = {}
	self.Stars = {}
	self.ShapeBounds = {}
	self.Changed = true
	self.Cameras = {}
	LightCamera:new(self)

	return self
end

--- @description Resizes the default camera and its star buffers; additional cameras are unchanged.
--- @param Width number New canvas width.
--- @param Height number New canvas height.
--- @return nil
function LightWorld:Resize(Width, Height)
	self.DefaultCamera:Resize(Width, Height)
end

---@description Returns the default lighting camera used by the legacy world viewport methods.
---@return LightCamera camera Default viewport.
function LightWorld:GetCamera()
	return self.DefaultCamera
end

--- @description Applies a quality preset and optional per-world setting overrides.
--- @param Preset string Preset name: "low", "medium", or "high".
--- @param Overrides table? Optional ShadowScale, ShadowMSAA, and PenumbraScale overrides.
--- @return nil
function LightWorld:SetQuality(Preset, Overrides)
	self.Settings:SetQuality(Preset, Overrides)
end

---@description Rebuilds world-owned canvases after shared rendering quality changes.
---@return nil
function LightWorld:OnQualityChanged()
	self.UpdateCanvas = true
	for _, Light in pairs(self.Lights) do
		Light:DestroyCanvas()
	end
	for _, Camera in ipairs(self.Cameras) do
		Camera:Resize(Camera.Width, Camera.Height)
	end
end

---@description Returns the settings object shared by this world's lights and stars.
---@return Settings settings Shared world settings.
function LightWorld:GetSettings()
	return self.Settings
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
	self.DefaultCamera:Draw()
	love.graphics.setColor(1, 1, 1, 1)
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
	self.DefaultCamera:SetPosition(x, y, z)
end

--- @description Returns camera position and scale.
--- @return number x Camera x-coordinate.
--- @return number y Camera y-coordinate.
--- @return number z Camera scale.
function LightWorld:GetPosition()
	return self.DefaultCamera:GetPosition()
end

--- @description Advances the shared scene once and refreshes every registered camera.
--- @param dt number? Elapsed time in seconds; omitted dt skips particle simulation.
--- @return nil
function LightWorld:Update(dt)
	local frameMetrics = newFrameMetrics(self.FrameMetrics.Frame + 1)
	for Index, Transform in pairs(self.BodyTracks) do
		Transform:Update()
	end

	for Index, Body in pairs(self.Bodies:GetArray()) do
		Body:Update()
	end

	Shadows.insertionSort(self.Bodies:GetArray())
	self:UpdateShapeBounds()

	for _, Camera in ipairs(self.Cameras) do
		Camera:BeginFrame(frameMetrics.Frame)
		Camera:UpdateTransform()
	end

	local sharedStart = love.timer.getTime()
	for Index, Light in pairs(self.Lights) do
		Light:Update(dt)
	end; love.graphics.setCanvas()
	frameMetrics.SharedUpdateMs = (love.timer.getTime() - sharedStart) * 1000

	for Index, Star in pairs(self.Stars) do
		Star:UpdateViews()
	end; love.graphics.setCanvas()

	for Index, Room in pairs(self.Rooms) do
		Room:Update()
	end; love.graphics.setCanvas()

	for _, Camera in ipairs(self.Cameras) do
		Camera:Compose()
	end
	self.Changed = false
	self.UpdateCanvas, self.UpdateStars = nil, nil

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
	love.graphics.setBlendMode("alpha", "alphamultiply")
	love.graphics.origin()
	for _, Light in pairs(self.Lights) do sampleFrameWork(frameMetrics, Light) end
	for _, Camera in ipairs(self.Cameras) do
		local metrics = assert(Camera.PendingFrameMetrics, "Camera metrics must be started before sampling")
		for _, Star in pairs(self.Stars) do
			sampleFrameWork(metrics, Star:GetView(Camera))
		end
		Camera:EndFrame()
	end
	self.FrameMetrics = frameMetrics
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
