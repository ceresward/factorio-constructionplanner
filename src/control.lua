-- Ideas for future enhancement:
  -- Use "on_entity_changed_force", if Wube decides to add it
  -- Forces library?
  -- More efficient force-based logic?  (regex = slow)
  -- Mod preferences...ideas:
    -- Whether entities should start out approved or unapproved when first built (default unapproved)
    -- Allow building of unapproved entities when there are no remaining approved entities to build (within a given logistic network?)
    -- Allow building of unapproved entities of a given type if there are enough spare resources of that type + available construction bots (within a given logistic network)

-- Note: there is no "on_entity_changed_force" event, so I'll have to just update badges as I change the forces in my
--       mod, and hope that other mods don't mess around with the forces too much.  For /editor force changes during
--       testing, I can use a console command + remote interface to manually force a badge rescan.

local approvalBadges = require("control.approvalBadges")

FORCE_REGEX = "(.+)%.unapproved_ghosts"
function is_unapproved_ghost_force_name(force_name)
  return string.match(force_name, FORCE_REGEX) ~= nil
end

function to_unapproved_ghost_force_name(base_force_name)
  return base_force_name .. ".unapproved_ghosts"
end

function parse_base_force_name(force_name)
  local base_name = string.match(force_name, FORCE_REGEX)
  if base_name then
      return base_name
  else
      return force_name
  end
end

function entity_debug_string(entity)
  return entity.type .. " of " .. entity.force.name .. " @ " .. serpent.line(entity.position)
end

function first_match_or_nil(table)
  if table_size(table) == 0 then
    return nil
  else 
    return table[1]
  end
end

function position_string(position)
  local result = tostring(position.x) .. ":" .. tostring(position.y)
  -- game.print("Position string: " .. serpent.line(position) .. " --> " .. result)
  return result
end

-- Maps a list of elements by some property of that element
function reassociate(array, fnNewKey)
  local result = {}
  for key, value in pairs(array or {}) do
    local newKey = fnNewKey(key, value)
    if newKey ~= nil then
      result[newKey] = value
    end
  end
  return result
end

DIPLOMACY_SYNC_IN_PROGRESS = false
function syncAllDiplomacy(srcForce, destForce)
  -- game.print("Starting diplomacy sync from " .. srcForce.name .. " to " .. destForce.name .. "...")
  DIPLOMACY_SYNC_IN_PROGRESS = true
  for _, force in pairs(game.forces) do
    if (force ~= srcForce and force ~= destForce) then
      destForce.set_friend(force, srcForce.get_friend(force))
      destForce.set_cease_fire(force, srcForce.get_cease_fire(force))
    end
  end
  DIPLOMACY_SYNC_IN_PROGRESS = false
  -- game.print("Diplomacy sync complete")
end

FORCE_CREATION_IN_PROGRESS = false
function get_or_create_unapproved_ghost_force(base_force)
  local unapproved_ghost_force_name = to_unapproved_ghost_force_name(base_force.name)
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

function get_script_blueprint()
  if not global.blueprintInventory then
    local blueprintInventory = game.create_inventory(1)
    blueprintInventory.insert({ name="blueprint"})
    global.blueprintInventory = blueprintInventory
  end
  return global.blueprintInventory[1]
end

function to_blueprint_entity(entity)
  local bp = get_script_blueprint()
  bp.clear_blueprint()
  bp.create_blueprint {
    surface = entity.surface,
    force = entity.force,
    area = {{entity.position.x, entity.position.y}, {entity.position.x, entity.position.y}},
    always_include_tiles = false
  }
  -- game.print("to_blueprint_entity: BlueprintEntity = " .. serpent.line(bp.get_blueprint_entities()))
  return first_match_or_nil(bp.get_blueprint_entities())
end

function is_placeholder(entity)
  return entity.type == "entity-ghost" and entity.ghost_name == "unapproved-ghost-placeholder"
end

function is_bp_placeholder(entity)
  return entity.name == "unapproved-ghost-placeholder"
end

function create_placeholder_for(unapproved_entity)
  -- Note: the placeholder has to be a ghost, otherwise it will overwrite the unapproved entity, and mess up the deconstruction planner interaction
  local placeholder = unapproved_entity.surface.create_entity {
    name = "entity-ghost",
    position = unapproved_entity.position,
    force = parse_base_force_name(unapproved_entity.force.name),
    inner_name = "unapproved-ghost-placeholder"
  }
  -- game.print("Unapproved entity: " .. entity_debug_string(event.created_entity))
  -- game.print("Placeholder: " .. entity_debug_string(placeholder))
  return placeholder
end

function remove_placeholder_for(unapproved_entity)
  -- Note: this search works only because the placeholder will be at the *same exact position* as the unapproved entity
  local placeholders = unapproved_entity.surface.find_entities_filtered {
    position = unapproved_entity.position,
    force = parse_base_force_name(unapproved_entity.force.name),
    ghost_name = "unapproved-ghost-placeholder"
  }

  -- Only one placeholder is expected, but if multiple are discovered for whatever reason, just remove them all
  for _, placeholder in pairs(placeholders) do
    placeholder.destroy()
  end
end

function get_unapproved_ghost_bp_entities(surface, force, area)
  local bp = get_script_blueprint()
  bp.clear_blueprint()
  bp.create_blueprint {
    surface = surface,
    force = force,
    area = area,
    always_include_tiles = false
  }
  return bp.get_blueprint_entities()
end

function remove_unapproved_ghost_for(placeholder)
  local unapproved_ghosts = placeholder.surface.find_entities_filtered {
    position = placeholder.position,
    force = to_unapproved_ghost_force_name(placeholder.force.name),
    name = "entity-ghost"
  }

  -- Only one placeholder is expected, but if multiple are discovered for whatever reason, just remove them all
  for _, unapproved_ghost in pairs(unapproved_ghosts) do
    unapproved_ghost.destroy()
  end
end

function is_auto_approve(player)
  return settings.get_player_settings(player)["constructionPlanner-auto-approve"].value
end

function approve_entities(entities)
  local baseForceCache = {}

  for _, entity in pairs(entities) do
    local base_force = baseForceCache[entity.force.name]
    if not base_force then
      local base_force_name = parse_base_force_name(entity.force.name)
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

function unapprove_entities(entities)
  local unapprovedForceCache = {}

  for _, entity in pairs(entities) do
    if not is_placeholder(entity) and not is_unapproved_ghost_force_name(entity.force.name) then
      local unapproved_force = unapprovedForceCache[entity.force.name]
      if not unapproved_force then
        unapproved_force = get_or_create_unapproved_ghost_force(entity.force)
        unapprovedForceCache[entity.force.name] = unapproved_force
      end
      if (entity.force ~= unapproved_force) then
        entity.force = unapproved_force
        create_placeholder_for(entity)
      end
      local badgeId = approvalBadges.getOrCreate(entity);
      approvalBadges.showUnapproved(badgeId)
    end
  end
end


-------------------------------------------------------------------------------
--       EVENTS
-------------------------------------------------------------------------------

script.on_event(defines.events.on_force_friends_changed,
  function(event)
    if not DIPLOMACY_SYNC_IN_PROGRESS and not FORCE_CREATION_IN_PROGRESS then 
      local unapproved_ghost_force = game.forces[to_unapproved_ghost_force_name(event.force.name)]
      if unapproved_ghost_force ~= nil then
        -- game.print("Syncing friends update from " .. event.force.name .. " to " .. unapproved_ghost_force.name)
        -- game.print("  (other force = " .. event.other_force.name .. ", added = " .. tostring(event.added) .. ")")
        unapproved_ghost_force.set_friend(event.other_force, event.added)
      end
    end
  end
)

script.on_event(defines.events.on_force_cease_fire_changed,
  function(event)
    if not DIPLOMACY_SYNC_IN_PROGRESS and not FORCE_CREATION_IN_PROGRESS then 
      local unapproved_ghost_force = game.forces[to_unapproved_ghost_force_name(event.force.name)]
      if unapproved_ghost_force ~= nil then
        -- game.print("Syncing cease-fire update from " .. event.force.name .. " to " .. unapproved_ghost_force.name)
        -- game.print("  (other force = " .. event.other_force.name .. ", added = " .. tostring(event.added) .. ")")
        unapproved_ghost_force.set_cease_fire(event.other_force, event.added)
      end
    end
  end
)

script.on_event(defines.events.on_player_selected_area,
  function(event)
    if event.item == 'construction-planner' then
      local player = game.get_player(event.player_index)

      -- Filter should only match 'unapproved' ghosts (ghost entities on the selecting player's unapproved ghost force)
      local entities = event.surface.find_entities_filtered {
        area = event.area,
        force = get_or_create_unapproved_ghost_force(player.force),
        type = "entity-ghost"
      }

      if #entities > 0 then
        -- game.print("construction-planner: approving "..tostring(#entities).." entities")

        approve_entities(entities)

        -- Note:  if the devs ever add support, I can also use "utility/upgrade_selection_started" at selection start
        player.play_sound { path = "utility/upgrade_selection_ended" }
      end
    end
  end
)

script.on_event(defines.events.on_player_alt_selected_area,
  function(event)
    if event.item == 'construction-planner' then
        local player = game.get_player(event.player_index)

        -- Filter should only match 'approved' ghosts (ghost entities on the selecting player's base force)
        local entities = event.surface.find_entities_filtered {
          area = event.area,
          force = player.force,
          type = "entity-ghost"
        }

        if #entities > 0 then
          -- game.print("construction-planner: unapproving "..tostring(#entities).." entities")

          unapprove_entities(entities)

          -- Note:  if the devs ever add support, I can also use "utility/upgrade_selection_started" at selection start
          player.play_sound { path = "utility/upgrade_selection_ended" }
        end
    end
  end
)

script.on_event(defines.events.on_built_entity,
  function(event)
    -- game.print("construction-planner: detected new ghost entity " .. entity_debug_string(event.created_entity)")
    
    local player = game.players[event.player_index]
    if not is_auto_approve(player) then
      unapprove_entities({event.created_entity})
    else
      approve_entities({event.created_entity})
    end

    -- TODO: ask on the forums if is_shortcut_available can be made available for all mod-defined shortcuts
    --       (but first ask in Discord if there's another way that I'm just missing)
    -- if player.is_shortcut_available("give-construction-planner") and not is_auto_approve(player) then
    --   unapprove_entities({event.created_entity})
    -- else
    --   approve_entities({event.created_entity})
    -- end
  end,
  {{ filter="type", type="entity-ghost"}}
)

script.on_event(defines.events.on_player_setup_blueprint,
  function(event)
    -- Note: this event fires not just for blueprints, but for copy operations as well
    -- game.print("construction-planner: on_player_setup_blueprint, event=" .. serpent.block(event));

    local player = game.players[event.player_index]

    local adjust_blueprint = function(blueprint)
      local blueprintEntities = blueprint.get_blueprint_entities()
      if not blueprintEntities then
        return
      end

      local placeholder_found = false
      local adjustedBlueprintEntities = {}
      local unapprovedBlueprintEntitiesMap = nil
      for _, blueprintEntity in pairs(blueprintEntities) do
        if is_bp_placeholder(blueprintEntity) then
          placeholder_found = true

          if not unapprovedBlueprintEntitiesMap then
            local force_name = to_unapproved_ghost_force_name(player.force.name)
            local unapprovedBlueprintEntities = get_unapproved_ghost_bp_entities(event.surface, force_name, event.area)
            unapprovedBlueprintEntitiesMap = reassociate(unapprovedBlueprintEntities,
              function(_, blueprintEntity)
                return position_string(blueprintEntity.position)
              end
            )
          end

          local replacement = unapprovedBlueprintEntitiesMap[position_string(blueprintEntity.position)]
          if replacement then
            replacement.entity_number = blueprintEntity.entity_number
            table.insert(adjustedBlueprintEntities, replacement)
          end
        else
          table.insert(adjustedBlueprintEntities, blueprintEntity)
        end
      end

      if placeholder_found then 
        -- game.print("Placeholders detected; adjusting blueprint")
        blueprint.clear_blueprint()
        blueprint.set_blueprint_entities(adjustedBlueprintEntities)
      end
    end
    
    if (player.blueprint_to_setup.valid_for_read) then
      adjust_blueprint(player.blueprint_to_setup)
    end
    if (player.is_cursor_blueprint()) then
      adjust_blueprint(player.cursor_stack)
    end
  end
)

script.on_event(defines.events.on_pre_ghost_deconstructed,
  function(event)
    -- game.print("construction-planner: on_pre_ghost_deconstructed, event=" .. serpent.block(event));
    local entity = event.ghost

    -- If a placeholder was deconstructed, find and remove the unapproved entity as well
    -- If an unapproved entity was deconstructed (somehow), find and remove the placeholder as well
    if is_placeholder(entity) then
      remove_unapproved_ghost_for(entity)
    elseif (is_unapproved_ghost_force_name(entity.force.name)) then
        remove_placeholder_for(entity)
    end
  end
)

-- Note: this includes when the player right-clicks on ghost entities 
script.on_event(defines.events.on_player_mined_entity,
  function(event)
    -- game.print("construction-planner: on_player_mined_entity, event=" .. serpent.block(event));
    local entity = event.entity
    
    -- If an unapproved entity was mined, find and remove the placeholder as well
    if (is_unapproved_ghost_force_name(entity.force.name)) then
      -- game.print("Unapproved ghost mined: " .. entity_debug_string(entity))
      remove_placeholder_for(entity)
    end
  end,
  {{filter="type", type="entity-ghost"}}
)

-------------------------------------------------------------------------------
--       REMOTE INTERFACES (comment out when not debugging)
-------------------------------------------------------------------------------

-- -- /c remote.call("constructionplanner","badgeScan")
-- remote.add_interface("constructionplanner", {
--   badgeScan = function()
--     ghostEntities = game.player.surface.find_entities_filtered {
--       type = "entity-ghost"
--     }
--     game.print("construction-planner: scanning badges for  "..tostring(#ghostEntities).." ghost entities")
--     for _, entity in pairs(ghostEntities) do
--       local badgeId = approvalBadges.getOrCreate(entity);
--       if is_unapproved_ghost_force_name(entity.force.name) then
--         approvalBadges.showUnapproved(badgeId)
--       else
--         approvalBadges.showApproved(badgeId)
--       end
--     end
--   end
-- })
