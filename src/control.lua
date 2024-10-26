-- Ideas for future enhancement:
  -- Use "on_entity_changed_force", if Wube decides to add it
  -- Forces library?
  -- More efficient force identification logic?  (regex = slow)
  -- Ideas for additional mod settings:
    -- Allow building of unapproved entities when there are no remaining approved entities to build (within a given logistic network?)
    -- Allow building of unapproved entities of a given type if there are enough spare resources of that type + available construction bots (within a given logistic network)

-- Note: there is no "on_entity_changed_force" event, so I'll have to just update badges as I change the forces in my
--       mod, and hope that other mods don't mess around with the forces too much.  For /editor force changes during
--       testing, I can use a console command + remote interface to manually force a badge rescan.

--  TODO: investigate item-request-proxy and whether or not there might be any issues related to that (i.e. are assembler module requests remembered?)
--  TODO: resolve bugs
--    1. Placeholder ghost deconstruction can be brought back via undo
--      - There isn't a way to hook into undo events that I can tell.  I'll have to find another way.
--      - Option A: remove the placeholder during on_pre_ghost_deconstructed and hope that effectively 'cancels' the deconstruction so it won't go on the undo queue
--        - Big con here is that it will be confusing that undo doesn't work for unapproved decon when it would be expected that it does
--      - Option B: roll with the undo (it should work anyways!), and find a way to remember and 'undo' the unapproved entities that pair with the placeholders
--        - More complex, but it will be much more useful to the player
--        - Can detect player deconstruction events using on_player_deconstructed_area and save a BlueprintEntities array of the unapproved entities in that area
--        - Then use some sort of on_tick magic or similar to detect an 'undo event' for the same area, and restore the blueprint entities.
--        - Note: According to JanSharp on Discord, the undo queue has a max length of 100, so I only have to save data on the 100 most recent deconstruction events
--      - However I can probably use event on_pre_ghost_deconstructed to fix things, by approving the paired unapproved
--       ghosts and/or removing the placeholder before the decon planner can act on it
--      - Use LuaPreGhostDeconstructedEventFilter to make it more efficient
--      [X] Confirm/reproduce
--      [ ] Figure out a solution
--      [ ] Implement solution
--    2. Shift-stamping over an existing placeholder causes that ghost to become approved
--      - I think this might be related to the safety check I added to approve orphaned unapproved ghosts.  The theory is that the
--        shift-stamp removes the placeholder, but not the unapproved ghost, so the orphan check ends up approving the ghost when it
--        shouldn't have been.  But I'm not 100% convinced on the theory, there could be something else going on instead.
--    3. Stamping w/o shift gives a message 'Placeholder is in the way'
--      - Actually this is probably correct, but I should confirm how it works w/ approved/regular ghosts and ensure unapproved works the
--        same way

--  REMOTE INTERFACES (comment out when not debugging!)
--remote.add_interface("constructionplanner", require('control.remoteInterface'))

local modutil = require("control.modutil")
local approvalBadges = require("control.approvalBadges")
local forces = require("control.forces")

local SETTING_AUTO_APPROVE = "constructionPlanner-auto-approve"

local function get_script_blueprint()
  if not storage.blueprintInventory then
    local blueprintInventory = game.create_inventory(1)
    blueprintInventory.insert({ name="blueprint"})
    storage.blueprintInventory = blueprintInventory
  end
  return storage.blueprintInventory[1]
end

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

local function get_unapproved_ghost_bp_entities(surface, force, area)
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

local function is_auto_approve(player)
  return settings.get_player_settings(player)[SETTING_AUTO_APPROVE].value == true
end

local function toggle_auto_approve(player)
  local modSetting = settings.get_player_settings(player)[SETTING_AUTO_APPROVE]
  modSetting.value = not modSetting.value
  settings.get_player_settings(player)[SETTING_AUTO_APPROVE] = modSetting
end

local function is_approvable_ghost(entity)
  return entity and entity.type == "entity-ghost" and not is_placeholder(entity)
end

local function approve_entities(entities)
  local baseForceCache = {}

  for _, entity in pairs(entities) do
    if is_approvable_ghost(entity) then
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
local function unapprove_entities(entities)
  local unapprovedForceCache = {}

  for _, entity in pairs(entities) do
    if is_approvable_ghost(entity) then
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


-------------------------------------------------------------------------------
--       EVENTS
-------------------------------------------------------------------------------

-- Apply events from forces module intended to keep diplomacy in sync
script.on_event(defines.events.on_force_friends_changed, forces.on_force_friends_changed)
script.on_event(defines.events.on_force_cease_fire_changed, forces.on_force_cease_fire_changed)

script.on_event(defines.events.on_player_selected_area,
  function(event)
    if event.item == 'construction-planner' then
      local player = game.get_player(event.player_index)
      if player == nil then return end

      -- Filter should only match 'unapproved' ghosts (ghost entities on the selecting player's unapproved ghost force)
      local entities = event.surface.find_entities_filtered {
        area = event.area,
        force = forces.get_or_create_unapproved_force(player.force),
        type = "entity-ghost"
      }

      if #entities > 0 then
        -- game.print("construction-planner: approving "..tostring(#entities).." entities")

        approve_entities(entities)
      end
    end
  end
)

script.on_event(defines.events.on_player_alt_selected_area,
  function(event)
    if event.item == 'construction-planner' then
        local player = game.get_player(event.player_index)
        if player == nil then return end

        -- Filter should only match 'approved' ghosts (ghost entities on the selecting player's base force)
        local entities = event.surface.find_entities_filtered {
          area = event.area,
          force = player.force,
          type = "entity-ghost"
        }

        if #entities > 0 then
          -- game.print("construction-planner: unapproving "..tostring(#entities).." entities")

          unapprove_entities(entities)
        end
    end
  end
)

script.on_event(defines.events.on_built_entity,
  function(event)
    -- game.print("construction-planner: detected new ghost entity " .. entity_debug_string(event.created_entity))
    -- game.print("  Tags: " .. serpent.line(event.created_entity.tags))
    
    local player = game.players[event.player_index]
    if not is_auto_approve(player) then
      unapprove_entities({event.entity})
    else
      approve_entities({event.entity})
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
      if blueprintEntities and #blueprintEntities > 0 then
        local placeholderEntities = modutil.filter(blueprintEntities, function(id, blueprintEntity)
          return is_bp_placeholder(blueprintEntity)
        end)
        
        if placeholderEntities and #placeholderEntities > 0 then
          local force_name = forces.get_unapproved_force_name(player.force.name)
          local unapprovedEntities = get_unapproved_ghost_bp_entities(event.surface, force_name, event.area)

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
    -- game.print("construction-planner: on_pre_ghost_deconstructed for ghost " .. entity_debug_string(event.ghost));
    local entity = event.ghost

    -- If a placeholder was deconstructed, find and remove the unapproved entity as well
    -- If an unapproved entity was deconstructed (somehow), find and remove the placeholder as well
    if is_placeholder(entity) then
      remove_unapproved_ghost_for(entity)
    elseif (forces.is_unapproved_force(entity.force--[[@as LuaForce]])) then
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
    if (forces.is_unapproved_force(entity.force--[[@as LuaForce]])) then
      -- game.print("Unapproved ghost mined: " .. entity_debug_string(entity))
      remove_placeholder_for(entity)
    end
  end,
  {{filter="type", type="entity-ghost"}}
)

script.on_event(defines.events.on_pre_build,
  function(event)
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
        approve_entities(unapproved_ghosts)
      end
    end
  end
)

script.on_event(defines.events.script_raised_revive,
  function(event)
    -- game.print("construction-planner: " .. event.name .. " for " .. entity_debug_string(event.entity))
    -- Note: this bit of code is to check whenever a script raises a revive event, if the revived entity somehow got
    --       placed on the unapproved ghost force by accident, and if so, resolve the issue by reassigning the entity to
    --       the main player force.  This is to resolve a compatibility issue between this mod and the Creative Mod mod,
    --       as well as potentially other mods too (the mod does have to use the raise_* flag however)
    local entity = event.entity
    local base_force_name = forces.parse_base_force_name(entity.force.name)
    if (entity.force.name ~= base_force_name) then
      remove_placeholder_for(entity)
      entity.force = base_force_name
    end
  end
)

script.on_event("toggle-auto-approve",
  function(event)
    -- game.print("construction-planner: " .. event.input_name .. " (customInput)")
    toggle_auto_approve(event.player_index)
  end
)
script.on_event(defines.events.on_lua_shortcut,
  function(event)
    if (event.prototype_name == "toggle-auto-approve") then
      -- game.print("construction-planner: " .. event.prototype_name .. " (shortcut)")
      toggle_auto_approve(event.player_index)
    end
  end
)
script.on_event(defines.events.on_runtime_mod_setting_changed,
  function(event)
    -- game.print("construction-planner: " .. event.name .. " for " .. event.setting)
    if (event.setting == SETTING_AUTO_APPROVE) then
      local player = game.get_player(event.player_index)
      if player == nil then return end
      player.set_shortcut_toggled("toggle-auto-approve", is_auto_approve(player))
    end
  end
)
