-- Implementation of the approval module that manages approval state using shadow prototypes.
-- This is the new, experimental way of tracking approval state; approvalByForce is the legacy method

-- TODO: figure out how to do migrations, if necessary
-- TODO: investigate possibility of swapping item prototype held in cursor to try and avoid weird issues with dragging
--       power poles and belts

local approvalBadges = require('control.approvalBadges')

-----------------------------------------------------------
--  Internal implementation
-----------------------------------------------------------

-- Build name conversion lookup tables
local unapprovedToApprovedNames = {}
local approvedToUnapprovedNames = {}
for name, _ in pairs(prototypes.entity) do
  local unapprovedName = name..'-unapproved'
  if prototypes.entity[unapprovedName] then
    unapprovedToApprovedNames[unapprovedName] = name
    approvedToUnapprovedNames[name] = unapprovedName
  end
end
helpers.write_file('constructionplanner-prototypes.txt', serpent.block(unapprovedToApprovedNames), false)
helpers.write_file('constructionplanner-prototypes.txt', serpent.block(approvedToUnapprovedNames), true)

-- Build list of crafting-machine entity prototypes to make it easier to lookup later if a given ghost might have recipes
local craftingMachines = prototypes.get_entity_filtered {{filter="crafting-machine"}}

---@param entity_proto_name string entity prototype name
local function isUnapprovedName(entity_proto_name)
  return unapprovedToApprovedNames[entity_proto_name] ~= nil
end

local function isApprovedName(entity_proto_name)
  return approvedToUnapprovedNames[entity_proto_name] ~= nil
end

---@param entity LuaEntity
---@return boolean
local function isUnapproved(entity)
  return entity and entity.type == "entity-ghost" and isUnapprovedName(entity.ghost_name)
end

---@param entity LuaEntity
---@return boolean
local function isApproved(entity)
  return entity and entity.type == "entity-ghost" and isApprovedName(entity.ghost_name)
end

---Update approval badge status for the given entity based on its current approval state
---@param entity any
local function updateApprovalBadge(entity)
  local badgeId = approvalBadges.getOrCreate(entity);
  if isApproved(entity) then
    approvalBadges.showApproved(badgeId)
  elseif isUnapproved(entity) then
    approvalBadges.showUnapproved(badgeId)
  else
    approvalBadges.hide(badgeId)
  end
end

---Find all ghost entities for a given player+area+surface
---@param player LuaPlayer player to search
---@param surface LuaSurface surface to search
---@param area BoundingBox area to search
---@return LuaEntity[] results found entities
local function findAllGhostEntitiesIn(player, surface, area)
  return surface.find_entities_filtered {
    area = area,
    force = player.force,
    type = "entity-ghost"
  }
end

---Find all ghost entities for a given player+area+surface
---@param player LuaPlayer player to search
---@param surface LuaSurface surface to search
---@param position MapPosition location to search
---@return LuaEntity[] results found entities
local function findAllGhostEntitiesAt(player, surface, position)
  return surface.find_entities_filtered {
    position = position,
    force = player.force,
    type = "entity-ghost"
  }
end

---Swap out an existing ghost entity with a duplicate entity of a different ghost type
---@param entity LuaEntity entity with type 'entity-ghost'
---@param ghost_name string name of the entity prototype stored within the ghost
---@return LuaEntity? replacement replacement entity
local function replaceEntityGhostType(entity, ghost_name)
  -- TODO: figure out how to get these changes to not use the undo queue...or maybe use the queue, but use it
  --       properly (right now the replacements are removed on undo but the originals don't return)
  -- TODO: figure out why the unapproved prototypes aren't being considered valid for fast-replace.  Is it because
  --       they're hidden?  Something else?  If I can fix fast-replace, that would likely also fix the undo queue
  -- Note though, that not all entities are fast-replaceable... e.g. rails don't support it.  It would probably
  -- be good to use fast-replace where possible, but keep the create/destroy method as a fallback.  And fix the
  -- undo/redo for create/destroy method if possible.

  if entity.type == 'entity-ghost' then
    game.print('Replacing entity: '..serpent.line(entity.ghost_name))
    if entity.tags then
      game.print('  Tags: '..serpent.line(entity.tags))
    end
    local surface = entity.surface
    local destroy_entity_params = {
      player=entity.last_user,
      item_index=0
    }
    local create_entity_params = {
      -- General properties
      name='entity-ghost',
      position=entity.position,
      direction=entity.direction,
      quality=entity.quality,
      force=entity.force,
      player=entity.last_user,
      item_index=1,
      create_build_effect_smoke=false,

      -- 'entity-ghost'-specific properties
      inner_name = ghost_name,
      tags = entity.tags
    }
    local recipe, quality
    if craftingMachines[entity.ghost_name] then
      recipe, quality = entity.get_recipe()
    end
    entity.destroy(destroy_entity_params)
    local replacement = surface.create_entity(create_entity_params)
    if replacement then
      game.print('  --> '..serpent.line(replacement.ghost_name))
      if recipe or quality then
        replacement.set_recipe(recipe, quality)
      end
    end
    return replacement
  end
end

-----------------------------------------------------------
-- External API
-----------------------------------------------------------

---Is this entity approvable? (i.e. does an unapproved prototype exist for it)
---@param entity LuaEntity
---@return boolean
local function isApprovable(entity)
  return isUnapproved(entity)
end

---Find approved ghost entities for a given player+area+surface
---@param player LuaPlayer player to search
---@param surface LuaSurface surface to search
---@param area BoundingBox area to search
---@return LuaEntity[] results found entities
local function findApprovedGhosts(player, surface, area)
  local allGhostEntities = findAllGhostEntitiesIn(player, surface, area)
  local approvedGhostEntities = {}
  for _, ghostEntity in pairs(allGhostEntities) do
    if isApproved(ghostEntity) then
      table.insert(approvedGhostEntities, ghostEntity)
    end
  end
  return approvedGhostEntities
end

---Find unapproved ghost entities for a given player+area+surface
---@param player LuaPlayer player to search
---@param surface LuaSurface surface to search
---@param area BoundingBox area to search
---@return LuaEntity[] results found entities
local function findUnapprovedGhosts(player, surface, area)
  local allGhostEntities = findAllGhostEntitiesIn(player, surface, area)
  local unapprovedGhostEntities = {}
  for _, ghostEntity in pairs(allGhostEntities) do
    if isUnapproved(ghostEntity) then
      table.insert(unapprovedGhostEntities, ghostEntity)
    end
  end
  return unapprovedGhostEntities
end

---@param entities LuaEntity[]
local function approveAll(entities)
  game.print('Approving'..(entities and #entities)..' entities')
  for _, entity in pairs(entities) do
    if isUnapproved(entity) then
      local replacement = replaceEntityGhostType(entity, unapprovedToApprovedNames[entity.ghost_name])
      entity = replacement or entity
    end
    updateApprovalBadge(entity)
  end
end

---@param entities LuaEntity[]
local function unapproveAll(entities)
  game.print('Unapproving'..(entities and #entities)..' entities')
  for _, entity in pairs(entities) do
    if isApproved(entity) then
      local replacement = replaceEntityGhostType(entity, approvedToUnapprovedNames[entity.ghost_name])
      entity = replacement or entity
    end
    updateApprovalBadge(entity)
  end
end

---Adjust blueprint contents to replace any placeholders / unapproved entities with real entities so the blueprint
---contents will be useable.
---@param blueprint LuaItemStack blueprint that was just created
---@param force LuaForce force used to create the blueprint
---@param surface LuaSurface surface used to create the blueprint
---@param area BoundingBox area used to create the blueprint
local fixCreatedBlueprint = function(blueprint, force, surface, area)
  local blueprintEntities = blueprint and blueprint.get_blueprint_entities()
  if blueprintEntities and #blueprintEntities > 0 then
    for _, bpEntity in pairs(blueprintEntities) do
      if isUnapprovedName(bpEntity.name) then
        bpEntity.name = unapprovedToApprovedNames[bpEntity.name]
      end
    end
    blueprint.clear_blueprint()
    blueprint.set_blueprint_entities(blueprintEntities)
  end
end

---Cleans up approval state whenever an entity is about to be built or revived.  This function should be called from
---the on_pre_build handler.  Ideally the caller should pre-filter for approvable entities, but this function
---will double-check as well.
---@param event EventData.on_pre_build
local function on_pre_build(event)
  local player = game.players[event.player_index]

  local ghostEntitiesAtPosition = findAllGhostEntitiesAt(player, player.surface, event.position)
  approveAll(ghostEntitiesAtPosition)
end

---Cleans things up whenever an approvable entity is about to be revived.  This function should be called from the
---script_raised_revive event handler.
---@param entity LuaEntity entity being removed.  
local function on_pre_entity_revived(entity)
  approveAll({entity})
end

local function on_pre_entity_removed(event)
  -- do nothing
end

-- NOTE: this interface should be kept in sync with `approvalByForce` until it becomes a proven method
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