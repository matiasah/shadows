local Shadows = ...
local Circle = debug.getregistry()["CircleShape"]

function Circle:Draw(Body)
	local x, y = Body.Body:getWorldPoint(self:getPoint())
	love.graphics.circle("fill", x, y, self:getRadius())
end

function Circle:GetPosition(Body)
	return Body.Body:getWorldPoint(self:getPoint())
end

function Circle:GetRadius()
	return self:getRadius()
end

function Circle:GenerateShadows(Shapes, Body, UsePenumbra, Light)
	local x, y = self:GetPosition(Body)
	local Radius = self:getRadius()

	local Distance = math.sqrt((x - Light.x)^2 + (y - Light.y)^2)
	if Distance > Radius then
		local Heading = math.atan2(Light.x - x, y - Light.y) + math.pi/2
		local Offset = math.atan(Radius / Distance)
		local BorderDistance = Distance * math.cos(Offset)
		
		local Length = Light.Radius
		if Body.z < Light.z then
			Length = Body.z / math.atan2(Light.z, BorderDistance)
		end
		
		local Polygon = {type = "polygon"}
		table.insert(Polygon, Light.x + math.cos(Heading + Offset) * BorderDistance)
		table.insert(Polygon, Light.y + math.sin(Heading + Offset) * BorderDistance)
		table.insert(Polygon, Light.x + math.cos(Heading - Offset) * BorderDistance)
		table.insert(Polygon, Light.y + math.sin(Heading - Offset) * BorderDistance)
		
		if UsePenumbra then
		
			if Light.z <= Body.z then
				local PenumbraAngle = math.atan(Light.SizeRadius / Light.Radius)
				local Penumbra = {type = "arc", Soft = true}
				Penumbra[1] = Polygon[1]
				Penumbra[2] = Polygon[2]
				Penumbra[3] = Length
				Penumbra[4] = Heading + Offset + PenumbraAngle
				Penumbra[5] = Heading + Offset
				table.insert(Shapes, Penumbra)
				
				local Penumbra = {type = "arc", Soft = true}
				Penumbra[1] = Polygon[3]
				Penumbra[2] = Polygon[4]
				Penumbra[3] = Length
				Penumbra[4] = Heading - Offset - PenumbraAngle
				if Penumbra[4] > math.pi then
					Penumbra[4] = Penumbra[4] - math.pi * 2
				end
				Penumbra[5] = Penumbra[4] + PenumbraAngle
				table.insert(Shapes, Penumbra)
			end
			
		end

		table.insert(Polygon, Polygon[3] + math.cos(Heading - Offset) * Length)
		table.insert(Polygon, Polygon[4] + math.sin(Heading - Offset) * Length)
		table.insert(Polygon, Polygon[1] + math.cos(Heading + Offset) * Length)
		table.insert(Polygon, Polygon[2] + math.sin(Heading + Offset) * Length)
		table.insert(Shapes, Polygon)
		
		if Light.z > Body.z then
			local Circle = {type = "circle"}
			Circle[1] = Light.x + math.cos(Heading) * (Length + Distance)
			Circle[2] = Light.y + math.sin(Heading) * (Length + Distance)
			Circle[3] = math.sqrt((Polygon[5] - Circle[1])^2 + (Polygon[6] - Circle[2])^2)
			
			table.insert(Shapes, Circle)
		end
		
	end
end