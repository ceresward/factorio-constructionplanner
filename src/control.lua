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

local forces = require("control.forces")
-- local approval = require("control.approvalByForce")
local approval = require("control.approvalByPrototype")

local SETTING_AUTO_APPROVE = "constructionPlanner-auto-approve"

local function is_auto_approve(player)
  return settings.get_player_settings(player)[SETTING_AUTO_APPROVE].value == true
end

local function toggle_auto_approve(player)
  local modSetting = settings.get_player_settings(player)[SETTING_AUTO_APPROVE]
  modSetting.value = not modSetting.value
  settings.get_player_settings(player)[SETTING_AUTO_APPROVE] = modSetting
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

      local entities = approval.findUnapprovedGhosts(player, event.surface, event.area)
      if #entities > 0 then
        -- game.print("construction-planner: approving "..tostring(#entities).." entities")
        approval.approveAll(entities)
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
        local entities = approval.findApprovedGhosts(player, event.surface, event.area)
        if #entities > 0 then
          -- game.print("construction-planner: unapproving "..tostring(#entities).." entities")
           approval.unapproveAll(entities)
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
       approval.unapproveAll({event.entity})
    else
      approval.approveAll({event.entity})
    end
  end,
  {{ filter="type", type="entity-ghost"}}
)

script.on_event(defines.events.on_player_setup_blueprint,
  function(event)
    -- Whenever a player creates a new blueprint, the blueprint contents need to be adjusted so the blueprint contains
    -- only real entities and no placeholder/shadow entities.
    -- Note: this event fires not just for blueprints, but for copy operations as well
    -- game.print("construction-planner: on_player_setup_blueprint, event=" .. serpent.block(event));

    local player = game.players[event.player_index]

    -- Adjust the blueprint_to_setup, if valid (scenario: create new blueprint)
    if (player.blueprint_to_setup and player.blueprint_to_setup.valid_for_read) then
      approval.fixCreatedBlueprint(player.blueprint_to_setup, player.force--[[@as LuaForce]], event.surface, event.area)
    end
    -- Adjust the cursor blueprint, if valid (scenario: copy operation)
    if (player.is_cursor_blueprint() and player.cursor_stack and player.cursor_stack.valid_for_read) then
      approval.fixCreatedBlueprint(player.cursor_stack, player.force--[[@as LuaForce]], event.surface, event.area)
    end
  end
)

script.on_event(defines.events.on_pre_build, approval.on_pre_build)

script.on_event(defines.events.on_pre_ghost_deconstructed,
  function(event)
    -- game.print("construction-planner: on_pre_ghost_deconstructed for ghost " .. entity_debug_string(event.ghost));
    approval.on_pre_entity_removed(event.ghost)
  end
)

-- Note: this includes when the player right-clicks on ghost entities 
script.on_event(defines.events.on_player_mined_entity,
  function(event)
    -- game.print("construction-planner: on_player_mined_entity, event=" .. serpent.block(event));
    approval.on_pre_entity_removed(event.entity)
  end,
  {{filter="type", type="entity-ghost"}}
)

script.on_event(defines.events.script_raised_revive,
  function(event)
    -- game.print("construction-planner: " .. event.name .. " for " .. entity_debug_string(event.entity))
    -- Note: this bit of code is to check whenever a script raises a revive event, if the revived entity somehow got
    --       placed on the unapproved ghost force by accident, and if so, resolve the issue by reassigning the entity to
    --       the main player force.  This is to resolve a compatibility issue between this mod and the Creative Mod mod,
    --       as well as potentially other mods too (the mod does have to use the raise_* flag however)
    approval.on_pre_entity_revived(event.entity)
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
