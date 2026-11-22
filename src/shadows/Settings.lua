---@module Stores validated per-world rendering quality settings shared by scene lights.

---@class Settings
---@field private World LightWorld World whose rendering buffers use these settings.
---@field private Quality string Active quality preset name.
---@field private ShadowScale number Shadow-canvas resolution scale from 0 to 1.
---@field private ShadowMSAA integer Multisample count for projected shadow edges.
---@field private PenumbraScale number Penumbra-buffer resolution scale from 0 to 1.
---@field private __index Settings Instance method lookup.
local Settings = {}
Settings.__index = Settings

---@type table<string, table>
local QualityPresets = {
    low = { ShadowScale = 0.5, ShadowMSAA = 0, PenumbraScale = 0.5 },
    medium = { ShadowScale = 0.75, ShadowMSAA = 2, PenumbraScale = 0.75 },
    high = { ShadowScale = 1, ShadowMSAA = 4, PenumbraScale = 1 },
}

---@description Creates the high-quality settings shared by a light world.
---@param World LightWorld World that owns this settings instance.
---@return Settings settings New per-world settings.
function Settings:new(World)
    return setmetatable({
        World = World,
        Quality = "high",
        ShadowScale = QualityPresets.high.ShadowScale,
        ShadowMSAA = QualityPresets.high.ShadowMSAA,
        PenumbraScale = QualityPresets.high.PenumbraScale,
    }, Settings)
end

---@description Applies a preset and optional setting overrides.
---@param Preset string Preset name: "low", "medium", or "high".
---@param Overrides table? Optional ShadowScale, ShadowMSAA, and PenumbraScale overrides.
---@return Settings settings This settings object, for chaining.
function Settings:SetQuality(Preset, Overrides)
    local preset = QualityPresets[Preset]
    assert(preset, "Preset must be 'low', 'medium', or 'high'")
    assert(Overrides == nil or type(Overrides) == "table", "Overrides must be a table")

    local settings = {
        ShadowScale = preset.ShadowScale,
        ShadowMSAA = preset.ShadowMSAA,
        PenumbraScale = preset.PenumbraScale,
    }
    if Overrides then
        for name, value in pairs(Overrides) do
            assert(settings[name] ~= nil, "Unknown quality setting: " .. tostring(name))
            settings[name] = value
        end
    end

    assert(type(settings.ShadowScale) == "number" and settings.ShadowScale > 0
        and settings.ShadowScale <= 1 and settings.ShadowScale < math.huge,
        "ShadowScale must be a finite number greater than 0 and at most 1")
    assert(type(settings.ShadowMSAA) == "number" and settings.ShadowMSAA >= 0
        and settings.ShadowMSAA < math.huge and settings.ShadowMSAA % 1 == 0,
        "ShadowMSAA must be a finite nonnegative integer")
    assert(type(settings.PenumbraScale) == "number" and settings.PenumbraScale > 0
        and settings.PenumbraScale <= 1 and settings.PenumbraScale < math.huge,
        "PenumbraScale must be a finite number greater than 0 and at most 1")

    local changed = self.ShadowScale ~= settings.ShadowScale
        or self.ShadowMSAA ~= settings.ShadowMSAA
        or self.PenumbraScale ~= settings.PenumbraScale
    self.Quality = Preset
    self.ShadowScale = settings.ShadowScale
    self.ShadowMSAA = settings.ShadowMSAA
    self.PenumbraScale = settings.PenumbraScale
    if changed then
        self.World:OnQualityChanged()
    end

    return self
end

---@description Returns the preset and effective rendering values.
---@return string preset Active preset name.
---@return number shadowScale Shadow-canvas resolution scale.
---@return integer shadowMSAA Projected-shadow MSAA sample count.
---@return number penumbraScale Penumbra-buffer resolution scale.
function Settings:GetQuality()
    return self.Quality, self.ShadowScale, self.ShadowMSAA, self.PenumbraScale
end

return Settings
