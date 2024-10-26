-- Module for encapsulating logic related to managing force-based approval state


-----------------------------------------------------------
--  Internal implementation
-----------------------------------------------------------

local UNAPPROVED_FORCE_REGEX = "(.+)%.unapproved_ghosts"
local FORCE_CREATION_IN_PROGRESS = false

local function syncAllDiplomacy(srcForce, destForce)
  -- game.print("Starting diplomacy sync from " .. srcForce.name .. " to " .. destForce.name .. "...")
  for _, force in pairs(game.forces) do
    if (force ~= srcForce and force ~= destForce) then
      destForce.set_friend(force, srcForce.get_friend(force))
      destForce.set_cease_fire(force, srcForce.get_cease_fire(force))
    end
  end
  -- game.print("Diplomacy sync complete")
end


-----------------------------------------------------------
-- External API
-----------------------------------------------------------

---Return the base force name for the given force.  For unapproved force, this is the force name without
---the '.unapproved_ghosts' suffix.  For all other forces, the name is returned unchanged.
---@param force_name string name of the force to parse
---@return string base_force_name base force name.  
local function parse_base_force_name(force_name)
  local base_name = string.match(force_name, UNAPPROVED_FORCE_REGEX)
  if base_name then
      return base_name
  else
      return force_name
  end
end

---Determines whether or not the given force is an unapproved ghost force
---@param force string|LuaForce force object or name of the force
---@return boolean is_unapproved_force true if the force is an unapproved ghost force, false otherwise
local function is_unapproved_force(force)
  local force_name = (type(force) == 'string') and force or force.name
  return string.match(force_name, UNAPPROVED_FORCE_REGEX) ~= nil
end

local function get_unapproved_force_name(base_force_name)
  return base_force_name .. ".unapproved_ghosts"
end

local function get_or_create_unapproved_force(base_force)
  local unapproved_ghost_force_name = get_unapproved_force_name(base_force.name)
  if not game.forces[unapproved_ghost_force_name] then
    FORCE_CREATION_IN_PROGRESS = true
    local unapproved_ghost_force = game.create_force(unapproved_ghost_force_name)
    unapproved_ghost_force.set_friend(base_force, true)
    unapproved_ghost_force.set_cease_fire(base_force, true)
    base_force.set_friend(unapproved_ghost_force, true)
    base_force.set_cease_fire(unapproved_ghost_force, true)
    syncAllDiplomacy(base_force, unapproved_ghost_force)
    FORCE_CREATION_IN_PROGRESS = false
  end
  return game.forces[unapproved_ghost_force_name]
end

local function forceCreationInProgress()
  return FORCE_CREATION_IN_PROGRESS
end

---@param event EventData.on_force_friends_changed
local function on_force_friends_changed(event)
  if not FORCE_CREATION_IN_PROGRESS then
    local unapproved_ghost_force = game.forces[get_unapproved_force_name(event.force.name)]
    if unapproved_ghost_force ~= nil then
      -- game.print("Syncing friends update from " .. event.force.name .. " to " .. unapproved_ghost_force.name)
      -- game.print("  (other force = " .. event.other_force.name .. ", added = " .. tostring(event.added) .. ")")
      unapproved_ghost_force.set_friend(event.other_force, event.added)
    end
  end
end

---@param event EventData.on_force_cease_fire_changed
local function on_force_cease_fire_changed(event)
  if not FORCE_CREATION_IN_PROGRESS then
    local unapproved_ghost_force = game.forces[get_unapproved_force_name(event.force.name)]
    if unapproved_ghost_force ~= nil then
      -- game.print("Syncing cease-fire update from " .. event.force.name .. " to " .. unapproved_ghost_force.name)
      -- game.print("  (other force = " .. event.other_force.name .. ", added = " .. tostring(event.added) .. ")")
      unapproved_ghost_force.set_cease_fire(event.other_force, event.added)
    end
  end
end

return {
  is_unapproved_force = is_unapproved_force,
  parse_base_force_name = parse_base_force_name,
  get_unapproved_force_name = get_unapproved_force_name,
  get_or_create_unapproved_force = get_or_create_unapproved_force,
  forceCreationInProgress = forceCreationInProgress,
  on_force_friends_changed = on_force_friends_changed,
  on_force_cease_fire_changed = on_force_cease_fire_changed
}