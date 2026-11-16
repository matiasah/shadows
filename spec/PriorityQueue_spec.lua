---@module Tests ordering and identity-sensitive removal in the height-sorted collection.
---@diagnostic disable: undefined-global
package.path = "src/?.lua;src/?/init.lua;" .. package.path
local PriorityQueue = require("shadows.PriorityQueue")

describe("PriorityQueue",
    ---@description Defines ordering, duplicate-height lookup, and removal regressions.
    ---@return nil
    function()
        it("orders mixed insertions and removes the first, middle, and last entries",
            ---@description Verifies removal compacts the array and absent values leave it unchanged.
            ---@return nil
            function()
                local queue = PriorityQueue:new()
                for _, value in ipairs({ 5, -2, 8, 3, 0 }) do
                    queue:Insert(value)
                end
                assert.same({ -2, 0, 3, 5, 8 }, queue:GetArray())
                queue:Remove(-2)
                queue:Remove(3)
                queue:Remove(8)
                queue:Remove(99)
                assert.same({ 0, 5 }, queue:GetArray())
                assert.equals(2, queue:GetLength())
            end)

        it("finds distinct objects with equal ordering priority by identity",
            ---@description Exercises both sides of the equal-height linear lookup.
            ---@return nil
            function()
                local ordering = {
                    ---@description Compares object heights without equating their identities.
                    ---@param left {height: number} First object.
                    ---@param right {height: number} Second object.
                    ---@return boolean lower Whether the first height is lower.
                    __lt = function(left, right) return left.height < right.height end,
                }
                local queue, objects = PriorityQueue:new(), {}
                for index = 1, 7 do
                    objects[index] = setmetatable({ height = 1 }, ordering)
                    queue:Insert(objects[index])
                end
                for _, object in ipairs(objects) do
                    local index = queue:Contains(object)
                    assert.is_number(index)
                    assert.is_true(rawequal(object, queue:Get(index)))
                end
                assert.is_false(queue:Contains(setmetatable({ height = 1 }, ordering)))
                queue:Remove(objects[4])
                assert.is_false(queue:Contains(objects[4]))
                assert.equals(6, queue:GetLength())
            end)
    end)
