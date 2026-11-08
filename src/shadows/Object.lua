--- Provides the base type helpers inherited by Shädows objects.
module("shadows.Object", package.seeall)

--- @class Object
--- @field __type string Runtime type name.
Object = {}
Object.__index = Object
Object.__type = "Object"

--- @description Checks whether this object or one of its parent types has the given runtime type.
--- @param Name string Runtime type name to check.
--- @return boolean matches Whether the type is present in the metatable chain.
function Object:typeOf(Name)
	local Metatable = getmetatable(self)

	while Metatable do
		if Metatable.__type == Name then
			return true
		end

		Metatable = getmetatable(Metatable)
	end

	return false
end

--- @description Returns this object's runtime type name.
--- @return string name Runtime type name.
function Object:type()
	return self.__type
end

return Object
