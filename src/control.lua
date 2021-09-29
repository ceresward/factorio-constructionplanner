-- Current design plan (save this until I have a good 'How it works' section in the README/modpage):
-- 1. Use a friendly force to hold the unapproved entities, as I'm currently doing
--    -  Advantage of this strategy is that it *should* preserve entity config and connections (inventories, filters, wire connections, etc.)
--    -  Preserving config and connections is possible in theory with generated placeholders, but would necessarily be very complex and brittle due to API constraints
--    -  TODO: will undo/redo still work as expected?  (i.e. will both the placeholder entities and unapproved entities be cleared when undoing a stamp?)
--       -  Betting it won't work out-of-the-box, but I expect there should be an event I can listen to so I can fix up things
-- 2. Create 'placeholder' entities - invisible entities that are positioned over the unapproved ghosts and can be selected by selection-tools
--    -  TODO: what to do about placeholder entity right-click?  (i.e. 'mining')?  Since the friendly force is also mineable...
--       -  It might be possible to make the placeholders non-mineable.  Ideally, they should only be interactable via the selection-tools
--    -  Placeholders should be destroyed whenever the unapproved entity is destroyed, and vice-versa
--       -  Events on_pre_ghost_deconstructed + on_player_mined_entity combined should cover the normal circumstancs...are there others though?
-- 3. Blueprint/copy:  do JIT replacement of the placeholder entities in the BP w/ the entities from the unapproved force
--    -  Idea is to generate a BP of the same area from the unapproved force, then swap those entities in for the placeholders in the original BP
--    -  Swap: should be okay to simply remove all placeholder entities from the original BP, then add in all entities from the generated BP
-- 4. Deconstruction:  two potential options
--    -  Option A:  listen to deconstruction events, and replicate the event in the same area on the unapproved force
--       -  TODO: Will the listener trigger though for mod-generated deconstruction events?
--    -  Option B:  listen to on_pre_ghost_deconstructed and replay the deconstruction onto the unapproved force entity
--    -  Even though in theory it's impossible to deconstruct the unapproved ghost entities, should probably sync on it anyways, to be safe (can test from editor)
--       (i.e. listen for unapproved ghost deconstruction events, and remove the linked placeholder entity)
-- 5. Upgrade planner:  likely won't be supported at first; I believe it's theoretically possible but difficult to implement
--    -  Would likely need a full-mirror placeholder tree that properly links upgrade paths to parallel the original upgrade paths
--    -  Might be able to get away with a simplified version, i.e. 'upgradeable-placeholder'
--    -  Also might work to listen to upgrade events and replay the upgrade on the same area for the unapproved force
--    -  Not sure how (if at all) 'customized' upgrade planners could be supported...the custom planner won't have upgrade rules for the placeholders
--       -  Might be possible to do JIT modification of the planner rule-set when the player puts it in their cursor...would be tricky though
-- 6. Modded selection-tools:  not sure if they can be supported; not worrying about for 1.0

-- TODO: implement new design
--   Done: placeholder prototypes, placeholder creation, placeholder removal, deconstruction linkage (both ways to be sure), blueprint JIT replacement
--   TBD:  approval tool selection filters, placeholder appearance, misc TODOs
-- TODO: test tile ghost behavior
-- TODO: disable approval-related features until approval tool is unlocked (don't move ghosts to unapproved force, and don't show the approval badge)
  -- Or maybe approval tool should be unlocked from start-of-game?
-- TODO: update README.md, changelog, etc. in prep for 1.0 release
-- TODO: flesh out post-1.0 roadmap.  Ideas:
  -- Replace 'draw_text' with 'draw_sprite' and a better icon? (maybe hammer or hammer-and-wrench?)
  -- Improved graphics for the shortcut and/or selection-tool, maybe thumbnail as well
  -- Use "on_entity_changed_force", if Wube decides to add it
  -- Forces library?
  -- More efficient force-based logic?  (regex = slow)
  -- Mod preferences...ideas:
    -- Whether entities should start out approved or unapproved when first built (default unapproved)
    -- Allow building of unapproved entities when there are no remaining approved entities to build (within a given logistic network?)
    -- Allow building of unapproved entities of a given type if there are enough spare resources of that type + available construction bots (within a given logistic network)
    -- Unlock at start of game, or with construction bots
  -- Find some way for the placeholders to have a proper selection border during BP/decon/approval selection
    -- Prototype would likely need a selection_box.  But how to work around the fact that the placeholder remains mineable?
    -- Maybe just work with the mineable placeholder, and use some sort of rendering trick to make it look like the placeholder is the real deal, instead of trying to hide it
    -- But that might not work well with wires/circuits/etc...it may be difficult/brittle to accurately fake those
    -- Also, quick-select might prove tricky...would need to be able to intercept the event on the placeholder and replace it with the real deal
-- TODO: note limitations
  -- TBD (new plan works around blueprinting/deconstruction, but maybe other limitations?)
-- TODO: release 1.0
-- TODO: make mod API request in forums (not very hopeful but why not try...)
  -- Would like a flag to mark a force as 'ally' or something like that...with the idea being that blueprints, copy/cut/paste, upgrade planner, decon planner, etc. would all work on allied force entities the same as though they were on the player's force
  -- It would follow to share logistics too...but this would mess up my mods!  Not sure yet how to approach that.
    -- Maybe suggest a flag name of 'share_blueprints' or something like that.  Or maybe just suggest 'friend' ought to imply selection-tool functionality (it lets you manually deconstruct already, after all)

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
    result[fnNewKey(key, value)] = value
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

      local badgeId = approvalBadges.getOrCreate(entity);
      approvalBadges.showApproved(badgeId)
    end
  end
end

function unapprove_entities(entities)
  local unapprovedForceCache = {}

  for _, entity in pairs(entities) do
    if not is_unapproved_ghost_force_name(entity.force.name) then
      local unapproved_force = unapprovedForceCache[entity.force.name]
      if not unapproved_force then
        unapproved_force = get_or_create_unapproved_ghost_force(entity.force)
        unapprovedForceCache[entity.force.name] = unapproved_force
      end
      if (entity.force ~= unapproved_force) then
        entity.force = unapproved_force

        local badgeId = approvalBadges.getOrCreate(entity);
        approvalBadges.showUnapproved(badgeId)

        create_placeholder_for(entity)
      end
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
    local base_force = event.created_entity.force
    unapprove_entities({event.created_entity})
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
