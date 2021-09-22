

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
    -- TODO: is tech sync necessary?  (I'm thinking not, b/c it's just ghosts...but could be wrong)
    -- syncAllTechToChannel(base_force, channel)
    FORCE_CREATION_IN_PROGRESS = false
  end
  return game.forces[unapproved_ghost_force_name]
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
      entity.force = base_force
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
        -- game.print("test")

        if event.item == 'construction-planner' then
            local player = game.get_player(event.player_index)

            -- TODO: fix the filtering to match only ghosts on the 'non-approved' list for the player (and maybe also the player's friends/allies?)
            local entities = event.surface.find_entities_filtered {
                area = event.area,
                force = get_or_create_unapproved_ghost_force(player.force)
            }

            if #entities > 0 then
                -- TODO: comment this out once everything is working
                game.print("construction-planner: approving "..tostring(#entities).." entities")

                -- TODO: implement logic to actually change the entity force and mark it as approved
                approve_entities(entities)

                -- Note:  if the devs ever add support, I can also use "utility/upgrade_selection_started" at selection start
                player.play_sound { path = "utility/upgrade_selection_ended" }
            end
        end
    end
)