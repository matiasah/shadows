---@module Tests hierarchical coordinates, rotations, and transform invalidation.
---@diagnostic disable: undefined-global
package.path = "src/?.lua;src/?/init.lua;" .. package.path
local Transform = require("shadows.Transform")

describe("Transform",
    ---@description Defines coordinate and descendant invalidation regressions.
    ---@return nil
    function()
        it("composes parent rotation, translation, and height",
            ---@description Checks a known parent-relative point and its inverse.
            ---@return nil
            function()
                local parent, child = Transform:new(), Transform:new()
                parent:SetLocalPosition(10, 20, 3)
                parent:SetLocalRotation(90)
                child:SetParent(parent)
                child:SetLocalPosition(4, 2, 5)
                local x, y, z = child:GetPosition()
                assert.near(8, x, 1e-9)
                assert.near(24, y, 1e-9)
                assert.equals(8, z)
                local lx, ly, lz = child:ToLocal(child:ToWorld(7, -3, 2))
                assert.near(7, lx, 1e-9)
                assert.near(-3, ly, 1e-9)
                assert.equals(2, lz)
            end)

        it("converts world setters into parent-relative coordinates",
            ---@description Checks world position and normalized rotation under a rotated parent.
            ---@return nil
            function()
                local parent, child = Transform:new(), Transform:new()
                parent:SetLocalPosition(10, 20, 3)
                parent:SetLocalRotation(90)
                child:SetParent(parent)
                child:SetPosition(8, 24, 8)
                child:SetRotation(-170)
                local x, y, z = child:GetLocalPosition()
                assert.near(4, x, 1e-9)
                assert.near(2, y, 1e-9)
                assert.equals(5, z)
                assert.equals(100, child:GetLocalRotation())
                assert.equals(-170, child:GetRotation())

                child:SetPosition(9, 24)
                local x, y, z = child:GetPosition()
                assert.near(9, x, 1e-9)
                assert.near(24, y, 1e-9)
                assert.equals(8, z, "Omitting world height must preserve the current world height")
            end)

        it("invalidates descendants only when a supplied coordinate changes",
            ---@description Verifies unchanged positions preserve caches and height zero is not omitted.
            ---@return nil
            function()
                local parent, child, grandchild = Transform:new(), Transform:new(), Transform:new()
                child:SetParent(parent)
                grandchild:SetParent(child)
                parent:SetLocalPosition(2, 3, 4)
                parent.HasChanged, child.HasChanged, grandchild.HasChanged = false, false, false
                assert.is_false(parent:SetLocalPosition(2, 3))
                assert.is_false(grandchild.HasChanged)
                assert.is_true(parent:SetLocalPosition(2, 3, 0))
                assert.is_true(child.HasChanged)
                assert.is_true(grandchild.HasChanged)
                assert.equals(0, parent.z)

                local nextParent = Transform:new()
                parent.HasChanged, child.HasChanged, grandchild.HasChanged = false, false, false
                child:SetParent(nextParent)
                assert.is_true(child.HasChanged)
                assert.is_true(grandchild.HasChanged)
            end)

        it("rejects invalid and cyclic parent assignments without changing the hierarchy",
            ---@description Prevents invalid ancestors and descendant cycles before detaching the current parent.
            ---@return nil
            function()
                local parent, child, grandchild = Transform:new(), Transform:new(), Transform:new()
                child:SetParent(parent)
                grandchild:SetParent(child)

                assert.is_false(pcall(parent.SetParent, parent, grandchild))
                assert.is_false(pcall(parent.SetParent, parent, parent))
                assert.is_false(pcall(child.SetParent, child, {}))
                assert.is_nil(parent:GetParent())
                assert.is_true(child:GetParent() == parent)
                assert.is_true(grandchild:GetParent() == child)
                local x, y, z = grandchild:GetPosition()
                assert.is_number(x)
                assert.is_number(y)
                assert.is_number(z)
            end)

        it("transforms polygon vertices without modifying their local coordinates",
            ---@description Compares batched vertices with known world-space coordinates.
            ---@return nil
            function()
                local parent, child = Transform:new(), Transform:new()
                parent:SetLocalPosition(10, 20, 0)
                parent:SetLocalRotation(90)
                child:SetParent(parent)
                child:SetLocalPosition(4, 2, 0)
                local points = { 0, 0, 2, 3 }
                local result = child:ToWorldPoints(points)
                assert.same({ 0, 0, 2, 3 }, points)
                for index, expected in ipairs({ 8, 24, 5, 26 }) do
                    assert.near(expected, result[index], 1e-9)
                end
            end)
    end)
