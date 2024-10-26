-- Mod-specific general utility functions

-- local function entity_debug_string(entity)
--   return entity.type .. " of " .. entity.force.name .. " @ " .. serpent.line(entity.position)
-- end

local function position_string(position)
  local result = tostring(position.x) .. ":" .. tostring(position.y)
  -- game.print("Position string: " .. serpent.line(position) .. " --> " .. result)
  return result
end

-- Remap an associative array using a mapping function of form: (oldKey, oldVal) => (newKey, newVal)
local function remap(array, fnMap)
  local result = {}
  for oldKey, oldVal in pairs(array or {}) do
    local newKey, newVal = fnMap(oldKey, oldVal)
    if newKey ~= nil then
      result[newKey] = newVal
    end
  end
  return result
end

-- Filter an associative array using a predicate function of form: (oldKey, oldVal) => isInclude
local function filter(array, fnPredicate)
  return remap(array, function(oldKey, oldVal)
    if fnPredicate(oldKey, oldVal) then
      return oldKey, oldVal
    end
    return nil, nil
  end)
end

return {
  position_string = position_string,
  remap = remap,
  filter = filter
}