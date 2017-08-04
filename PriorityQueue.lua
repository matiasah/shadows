module("shadows.PriorityQueue", package.seeall)

PriorityQueue = {}
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
	local Middle = math.floor( ( Left + Right ) * 0.5 )
	
	while Left < Right do
		
		local ArrayValue = self.Array[Middle]
		
		if Value < ArrayValue then
			
			Right = Middle - 1
			
		elseif Value > ArrayValue then
			
			Left = Middle + 1
			
		elseif ArrayValue == Value then
			
			return Middle
			
		end
		
		Middle = math.floor( ( Left + Right ) * 0.5 )
		
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
	
	return #self.Array
	
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

return PriorityQueue