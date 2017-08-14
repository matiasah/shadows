module("shadows.PriorityQueue", package.seeall)

Object = require("shadows.Object")

PriorityQueue = setmetatable( {}, Object )
PriorityQueue.__index = PriorityQueue
PriorityQueue.__type = "PriorityQueue"

function PriorityQueue:new()
	
	local self = setmetatable( {}, PriorityQueue )
	
	self.Array = {}
	self.Size = 0
	
	return self
	
end

function PriorityQueue:__tostring()
	
	local Concat = ""
	
	for i = 1, self.Size do
		
		Concat = Concat .. tostring(self.Array[i]) .. ","
		
	end
	
	return "{" .. Concat:sub(1, -2) .. "}"
	
end

function PriorityQueue:Insert(Value)
	-- Binary search the insertion position
	local Left = 1
	local Right = self.Size
	local Middle = 1
	
	while Left <= Right do
		
		Middle = math.floor( ( Left + Right ) / 2 )
		
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

function PriorityQueue:Contains(Value)
	
	local Left = 1
	local Right = self.Size
	local Middle = 1
	
	while Left <= Right do
		
		Middle = math.floor( ( Left + Right ) / 2 )
		
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
			
			while PointerValue and not ( PointerValue < Value ) do
				
				if PointerValue == Value then
					
					return LeftPointer
					
				end
				
				LeftPointer = LeftPointer - 1
				PointerValue = self.Array[LeftPointer]
				
			end
			
			local RightPointer = Middle + 1
			local PointerValue = self.Array[RightPointer]
			
			while PointerValue and not ( PointerValue > Value ) do
				
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

function PriorityQueue:Get(Index)
	
	return self.Array[Index]
	
end

function PriorityQueue:GetLength()
	
	return self.Size
	
end

function PriorityQueue:Remove(Element)
	
	local Index = self:Contains(Element)
	
	if Index then
		
		self:RemoveAt(Index)
		
	end
	
end

function PriorityQueue:RemoveAt(Index)
	
	if self.Array[Index] then
		
		for i = Index, self.Size do
			
			self.Array[i] = self.Array[i + 1]
			
		end
		
		self.Array[self.Size] = nil
		self.Size = self.Size - 1
		
	end
	
end

function PriorityQueue:GetArray()
	
	return self.Array
	
end

return PriorityQueue