-- Implementation of the approval module that manages approval state using the unapproval force.
-- This is the legacy way of tracking approval state; approvalByPrototype is preferred but experimental.

local modutil = require('control.modutil')
local approvalBadges = require('control.approvalBadges')
local forces = require('control.forces')

-----------------------------------------------------------
--  Internal implementation
-----------------------------------------------------------

local function is_placeholder(entity)
  return entity.type == "entity-ghost" and entity.ghost_name == "unapproved-ghost-placeholder"
end

local function is_bp_placeholder(entity)
  return entity.name == "unapproved-ghost-placeholder"
end

local function create_placeholder_for(unapproved_entity)
  -- Note: the placeholder has to be a ghost, otherwise it will overwrite the unapproved entity, and mess up the deconstruction planner interaction
  local placeholder = unapproved_entity.surface.create_entity {
    name = "entity-ghost",
    position = unapproved_entity.position,
    force = forces.parse_base_force_name(unapproved_entity.force.name),
    inner_name = "unapproved-ghost-placeholder"
  }
  -- game.print("Unapproved entity: " .. entity_debug_string(event.created_entity))
  -- game.print("Placeholder: " .. entity_debug_string(placeholder))
  return placeholder
end

local function remove_placeholder_for(unapproved_entity)
  -- Note: this search works only because the placeholder will be at the *same exact position* as the unapproved entity
  local placeholders = unapproved_entity.surface.find_entities_filtered {
    position = unapproved_entity.position,
    force = forces.parse_base_force_name(unapproved_entity.force.name),
    ghost_name = "unapproved-ghost-placeholder"
  }

  -- Only one placeholder is expected, but if multiple are discovered for whatever reason, just remove them all
  for _, placeholder in pairs(placeholders) do
    placeholder.destroy()
  end
end

local function remove_unapproved_ghost_for(placeholder)
  local unapproved_ghosts = placeholder.surface.find_entities_filtered {
    position = placeholder.position,
    force = forces.get_unapproved_force_name(placeholder.force.name),
    name = "entity-ghost"
  }

  -- Only one placeholder is expected, but if multiple are discovered for whatever reason, just remove them all
  for _, unapproved_ghost in pairs(unapproved_ghosts) do
    unapproved_ghost.destroy()
  end
end


-----------------------------------------------------------
-- External API
-----------------------------------------------------------

---Is this entity approvable?
---@param entity LuaEntity
---@return boolean
local function isApprovable(entity)
  return entity and entity.type == "entity-ghost" and not is_placeholder(entity)
end

---Find approved ghost entities for a given player+area+surface
---@param player LuaPlayer player to search
---@param surface LuaSurface surface to search
---@param area BoundingBox area to search
---@return LuaEntity[] results found entities
local function findApprovedGhosts(player, surface, area)
  return surface.find_entities_filtered {
    area = area,
    force = player.force,
    type = "entity-ghost"
  }
end

---Find unapproved ghost entities for a given player+area+surface
---@param player LuaPlayer player to search
---@param surface LuaSurface surface to search
---@param area BoundingBox area to search
---@return LuaEntity[] results found entities
local function findUnapprovedGhosts(player, surface, area)
  return surface.find_entities_filtered {
    area = area,
    force = forces.get_or_create_unapproved_force(player.force),
    type = "entity-ghost"
  }
end

---@param entities LuaEntity[]
local function approveAll(entities)
  local baseForceCache = {}

  for _, entity in pairs(entities) do
    if isApprovable(entity) then
      local base_force = baseForceCache[entity.force.name]
      if not base_force then
        local base_force_name = forces.parse_base_force_name(entity.force.name)
        base_force = game.forces[base_force_name]
        baseForceCache[entity.force.name] = base_force
      end
      if (entity.force ~= base_force) then
        remove_placeholder_for(entity)
        entity.force = base_force
      end
      local badgeId = approvalBadges.getOrCreate(entity);
      approvalBadges.showApproved(badgeId)
    end
  end
end

---@param entities LuaEntity[]
local function unapproveAll(entities)
  local unapprovedForceCache = {}

  for _, entity in pairs(entities) do
    if isApprovable(entity) then
      if not forces.is_unapproved_force(entity.force--[[@as LuaForce]]) then
        local unapproved_force = unapprovedForceCache[entity.force.name]
        if not unapproved_force then
          unapproved_force = forces.get_or_create_unapproved_force(entity.force)
          unapprovedForceCache[entity.force.name] = unapproved_force
        end
        if (entity.force ~= unapproved_force) then
          entity.force = unapproved_force
          create_placeholder_for(entity)
        end
      end
      local badgeId = approvalBadges.getOrCreate(entity);
      approvalBadges.showUnapproved(badgeId)
    end
  end
end

---Adjust blueprint contents to replace any placeholders / unapproved entities with real entities so the blueprint
---contents will be useable.
---@param blueprint LuaItemStack blueprint that was just created
---@param force LuaForce force used to create the blueprint
---@param surface LuaSurface surface used to create the blueprint
---@param area BoundingBox area used to create the blueprint
local fixCreatedBlueprint = function(blueprint, force, surface, area)
  ---Scan for unapproved entities in a given surface area, returning the results as BlueprintEntity[]
  ---@param force LuaForce
  ---@param surface LuaSurface
  ---@param area BoundingBox
  local function getUnapprovedBlueprintEntities(force, surface, area)
    local force_name = forces.get_unapproved_force_name(force.name)
    local bp = modutil.get_script_blueprint()
    bp.clear_blueprint()
    bp.create_blueprint {
      force = force_name,
      surface = surface,
      area = area,
      always_include_tiles = false
    }
    return bp.get_blueprint_entities()
  end

  local blueprintEntities = blueprint.get_blueprint_entities()
  if blueprintEntities and #blueprintEntities > 0 then
    local placeholderEntities = modutil.filter(blueprintEntities, function(id, blueprintEntity)
      return is_bp_placeholder(blueprintEntity)
    end)
    
    if placeholderEntities and #placeholderEntities > 0 then
      local unapprovedEntities = getUnapprovedBlueprintEntities(force, surface, area)

      local unapprovedEntitiesByPosition = modutil.remap(unapprovedEntities, function(id, blueprintEntity)
        return modutil.position_string(blueprintEntity.position), blueprintEntity
      end)

      local replacementEntities = modutil.remap(placeholderEntities, function(id, placeholderEntity)
        local replacementEntity = unapprovedEntitiesByPosition[modutil.position_string(placeholderEntity.position)]
        if replacementEntity then
          replacementEntity.entity_number = placeholderEntity.entity_number
          return id, replacementEntity
        else
          return id, nil
        end
      end)

      -- Fix up the circuit connections
      -- game.print("Fixing up circuit connections on " .. tostring(#replacementEntities) .. " replacement entities")
      for id, replacementEntity in pairs(replacementEntities) do
        if replacementEntity.connections then
          for _, connection in pairs(replacementEntity.connections) do
            for color, connectedEntityRefs in pairs(connection) do
              for _, connectedEntityRef in pairs(connectedEntityRefs) do
                local replacement_id = unapprovedEntities[connectedEntityRef.entity_id].entity_number
                connectedEntityRef.entity_id = replacement_id
              end
            end
          end
        end
      end

      -- Apply the replacement entities
      for id, replacementEntity in pairs(replacementEntities) do
        blueprintEntities[id] = replacementEntity
      end

      -- Uncomment for debugging only
      -- game.print("Blueprint updated to replace placeholders")
      -- for id, blueprintEntity in pairs(blueprintEntities) do
      --   game.print("blueprintEntities[" .. id .. "] = " .. serpent.line(blueprintEntity))
      -- end

      blueprint.clear_blueprint()
      blueprint.set_blueprint_entities(blueprintEntities)
    end
  end
end

---Cleans up approval state whenever an entity is about to be built or revived.  This function should be called from
---the on_pre_build handler.  Ideally the caller should pre-filter for approvable entities, but this function
---will double-check as well.
---@param event EventData.on_pre_build
local function on_pre_build(event)
  -- If the player is about to build an entity in the same exact position as an unapproved ghost, approve the ghost
  -- before the build happens.  This restores the ghost to the main force so that any special logic like recipe
  -- preservation will be handled properly when the entity gets built.
  local player = game.players[event.player_index]
  local unapproved_ghost_force_name = forces.get_unapproved_force_name(player.force.name)
  if game.forces[unapproved_ghost_force_name] then
    local unapproved_ghosts = player.surface.find_entities_filtered {
      position = event.position,
      force = forces.get_unapproved_force_name(player.force.name),
      name = "entity-ghost"
    }

    if #unapproved_ghosts > 0 then
      -- game.print("Approving " .. #unapproved_ghosts .. " ghosts on pre-build")
      approveAll(unapproved_ghosts)
    end
  end
end

---Cleans things up whenever an approvable entity is about to be removed (deconstructed, mined, etc.)  This function
---should be called from to the handler of any relevant event.  Ideally the caller should pre-filter for approvable
---entities, but this method will double-check as well.
---@param entity LuaEntity entity being removed.  
local function on_pre_entity_removed(entity)
  -- If a placeholder is being removed, find and remove the unapproved entity as well
  -- If an unapproved entity is being removed (somehow), find and remove the matching placeholder as well
  if is_placeholder(entity) then
    remove_unapproved_ghost_for(entity)
  elseif (forces.is_unapproved_force(entity.force--[[@as LuaForce]])) then
      remove_placeholder_for(entity)
  end
end

---Cleans things up whenever an approvable entity is about to be revived.  This function should be called from the
---script_raised_revive event handler.
---@param entity LuaEntity entity being removed.  
local function on_pre_entity_revived(entity)
  -- If the entity is on the unapprove ghost force, move it back to the player force before it gets built/revived
  local base_force_name = forces.parse_base_force_name(entity.force.name)
  if (entity.force.name ~= base_force_name) then
    remove_placeholder_for(entity)
    entity.force = base_force_name
  end
end

return {
  isApprovable = isApprovable,
  findApprovedGhosts = findApprovedGhosts,
  findUnapprovedGhosts = findUnapprovedGhosts,
  approveAll = approveAll,
  unapproveAll = unapproveAll,
  fixCreatedBlueprint = fixCreatedBlueprint,
  on_pre_build = on_pre_build,
  on_pre_entity_removed = on_pre_entity_removed,
  on_pre_entity_revived = on_pre_entity_revived
}