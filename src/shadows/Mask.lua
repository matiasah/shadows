---@module Provides unsigned 32-bit light and occluder group masks.
local bit = require("bit")

---@class Mask
---@field ALL integer All 32 groups, represented as the unsigned value 4294967295.
local Mask = { ALL = 4294967295 }

---@description Validates an unsigned 32-bit mask without silently truncating invalid values.
---@param value integer Mask in the inclusive range 0 through ALL.
---@return integer mask Validated mask.
function Mask.validate(value)
    assert(type(value) == "number" and value >= 0 and value <= Mask.ALL and value % 1 == 0,
        "Masks must be unsigned 32-bit integers")
    return value
end

---@description Returns the bit for a zero-based group index.
---@param index integer Group index from 0 through 31.
---@return integer mask Unsigned single-group mask.
function Mask.group(index)
    assert(type(index) == "number" and index >= 0 and index <= 31 and index % 1 == 0,
        "Mask group indices must be integers from 0 through 31")
    return 2 ^ index
end

---@description Combines masks while preserving unsigned values, including the highest bit.
---@param ... integer Masks to combine; no arguments produces 0.
---@return integer mask Unsigned union of all supplied masks.
function Mask.combine(...)
    local result = 0
    for i = 1, select("#", ...) do result = bit.bor(result, Mask.validate((select(i, ...)))) end
    return result < 0 and result + 4294967296 or result
end

---@description Tests whether two validated masks share at least one group.
---@param first integer First unsigned mask.
---@param second integer Second unsigned mask.
---@return boolean matches Whether at least one bit overlaps.
function Mask.matches(first, second)
    return bit.band(Mask.validate(first), Mask.validate(second)) ~= 0
end

return Mask
