--- Provides an ordered array-backed collection used to sort scene objects by height.
module("shadows.PriorityQueue", package.seeall)

Object = require("shadows.Object")

--- @class PriorityQueue: Object
--- @field Array table Ordered values.
--- @field Size integer Number of stored values.
PriorityQueue = setmetatable({}, Object)
PriorityQueue.__index = PriorityQueue
PriorityQueue.__type = "PriorityQueue"

--- @description Creates an empty ordered collection.
--- @return PriorityQueue queue New collection.
function PriorityQueue:new()
	local self = setmetatable({}, PriorityQueue)

	self.Array = {}
	self.Size = 0

	return self
end

--- @description Returns the collection as a brace-delimited string.
--- @return string value String representation.
function PriorityQueue:__tostring()
	local Concat = ""

	for i = 1, self.Size do
		Concat = Concat .. tostring(self.Array[i]) .. ","
	end

	return "{" .. Concat:sub(1, -2) .. "}"
end

--- @description Inserts a value while preserving ascending order.
--- @param Value any Value comparable with values already stored.
--- @return nil
function PriorityQueue:Insert(Value)
	-- Binary search the insertion position
	local Left = 1
	local Right = self.Size
	local Middle = 1

	while Left <= Right do
		Middle = math.floor((Left + Right) / 2)

		local ArrayValue = self.Array[Middle]

		if ArrayValue == Value then
			break
		elseif ArrayValue < Value then
			Left = Middle + 1

			if Left > Right then
				Middle = Middle + 1

				break
			end
		else
			Right = Middle - 1

			if Left > Right then
				break
			end
		end
	end

	for i = #self.Array, Middle, -1 do
		self.Array[i + 1] = self.Array[i]
	end

	self.Array[Middle] = Value
	self.Size = self.Size + 1
end

--- @description Finds a value and returns its index, or false when absent.
--- @param Value any Value to find.
--- @return integer|false index Index of the value, or false when absent.
function PriorityQueue:Contains(Value)
	local Left = 1
	local Right = self.Size
	local Middle = 1

	while Left <= Right do
		Middle = math.floor((Left + Right) / 2)

		local ArrayValue = self.Array[Middle]

		if ArrayValue == Value then
			return Middle
		elseif Value < ArrayValue then
			Right = Middle - 1
		elseif Value > ArrayValue then
			Left = Middle + 1
		else
			-- Linear search
			local LeftPointer = Middle - 1
			local PointerValue = self.Array[LeftPointer]

			while PointerValue and not (PointerValue < Value) do
				if PointerValue == Value then
					return LeftPointer
				end

				LeftPointer = LeftPointer - 1
				PointerValue = self.Array[LeftPointer]
			end

			local RightPointer = Middle + 1
			local PointerValue = self.Array[RightPointer]

			while PointerValue and not (PointerValue > Value) do
				if PointerValue == Value then
					return RightPointer
				end

				RightPointer = RightPointer + 1
				PointerValue = self.Array[RightPointer]
			end

			return false
		end
	end

	if self.Array[Middle] == Value then
		return Middle
	end

	return false
end

--- @description Returns the value at an index.
--- @param Index integer One-based index.
--- @return any value Value at the index, or nil when absent.
function PriorityQueue:Get(Index)
	return self.Array[Index]
end

--- @description Returns the number of stored values.
--- @return integer length Collection size.
function PriorityQueue:GetLength()
	return self.Size
end

--- @description Removes the first matching value when present.
--- @param Element any Value to remove.
--- @return nil
function PriorityQueue:Remove(Element)
	local Index = self:Contains(Element)

	if Index then
		self:RemoveAt(Index)
	end
end

--- @description Removes the value at an index when present.
--- @param Index integer One-based index.
--- @return nil
function PriorityQueue:RemoveAt(Index)
	if self.Array[Index] then
		for i = Index, self.Size do
			self.Array[i] = self.Array[i + 1]
		end

		self.Array[self.Size] = nil
		self.Size = self.Size - 1
	end
end

--- @description Returns the backing array.
--- @return table values Ordered values; mutating this table changes the collection.
function PriorityQueue:GetArray()
	return self.Array
end

return PriorityQueue
