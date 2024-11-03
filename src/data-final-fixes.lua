-- General notes about some of the weird quirks about how this all works:
-- 1. Entity prototypes are deep-copied from originals and modified so they can be used as the inner prototype for
--    unapproved ghosts.
-- 2. Item prototypes also need to be deep-copied and modified, because apparently only entities that are the target
--    of an item's place_result are allowed to be set as the inner target of a ghost (I guess ghosts have to be
--    "buildable" using some item, any item...)
-- 3. The entity and item prototypes can be set to 'hidden=true', but for whatever reason, this breaks fast-replace.
--    Entities like this cannot be fast-replaced
-- 4. If an item prototype is not set to 'hidden=true', then the item will show up in logistic filters, quickbars, etc.
--    The only other way to avoid this is to create a recipe that has the item as its 'main product' and is disabled.
--    It is sort of nonsense but I guess items without a recipe always show up, but items with one or more recipes only
--    show up if at least one of those recipes is enabled.
-- To summarize:  there seem to be a lot of assumptions being made about stuff being buildable by the player.  Entities
-- can only be a ghost if they are placeable by an item, items show up in logistic request filters unless they are hidden
-- or locked behind a disabled recipe, and entities are not eligible for fast replace unless the item used to replace
-- them is not hidden.  Maybe I could get some of these restrictions lifted through mod API requests, but it might
-- be hard to convince Wube that it's worth the effort.

local unapprovedIconOverlay = {
  icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/unapproved-overlay-x32.png",
  icon_size = 32,
  scale = 1
}

-- Overall plan:
-- 1. Create deep copies of item prototypes with a 'place_result'.  Modify the copies to place unapproved entities
--     instead; also modify any prototype properties as needed to make the item hidden from view.
-- 2. Scan through the list of entity prototypes and create deep copies of each entity that was the target of an item
--    prototype's 'place_result' in step 1.  Modify the copies to behave as unapproved entities instead; also modify
--    any prototype properties as needed to make the entity hidden from view.
-- 3. Add both the unapproved item prototypes and unapproved entity prototypes to the data table

---@type data.RecipePrototype[]
local stupidRecipeThings = {}
local unapprovedIconPrototypes = {}
local placeResultsMap = {}
for itemType, _ in pairs(defines.prototypes['item']) do
  local itemPrototypes = data.raw[itemType]
  if itemPrototypes then
    for _, itemPrototype in pairs(itemPrototypes) do
      if itemPrototype.place_result then
        -- Deep-copy the original prototype and add the copy to the list.  Modify the prototype as needed.
        local unapprovedPrototype = table.deepcopy(itemPrototype)
        table.insert(unapprovedIconPrototypes, unapprovedPrototype)
    
        unapprovedPrototype.name = unapprovedPrototype.name..'-unapproved'
        -- Override flags to ensure the item is always hidden
        unapprovedPrototype.flags = {"hide-from-bonus-gui", "hide-from-fuel-tooltip", "primary-place-result"}
        -- unapprovedPrototype.hidden = true
    
        -- Note: when place_result is specified, the item name will be copied from the entity if localised_name is nil
        --       (as noted in place_result docs)
        unapprovedPrototype.localised_name = nil
        unapprovedPrototype.localised_description = nil
        -- TODO: check if anything else needs updating
    
        -- Replace the place_result with the unapproved version, saving the mapping for later use when processing entities
        placeResultsMap[itemPrototype.place_result] = itemPrototype.place_result..'-unapproved'
        unapprovedPrototype.place_result = placeResultsMap[unapprovedPrototype.place_result]

        -- Special case handling for rail planners
        if itemPrototype.type == "rail-planner" and itemPrototype.rails then
          local unapprovedRails = {}
          for _, railEntityID in pairs(itemPrototype.rails) do
            placeResultsMap[railEntityID] = railEntityID..'-unapproved'
            table.insert(unapprovedRails, placeResultsMap[railEntityID])
          end
          unapprovedPrototype.rails = unapprovedRails
        end
    
        unapprovedPrototype.subgroup = "unapproved-entities-subgroup"
    
        -- Add unapproved checkmark icon layer on top of the original prototype icon(s).  The original icon may be defined
        -- using either an IconData array or filename+size.  Convert the original icon to an IconData array, if it isn't
        -- already, then add the unapproved checkmark icon as a new layer.
        -- Note:  the main icon is mandatory.  The dark background icon is optional.  The logic is defined accordingly.
        unapprovedPrototype.dark_background_icons = unapprovedPrototype.dark_background_icons
          or (unapprovedPrototype.dark_background_icon and {{
            icon = unapprovedPrototype.dark_background_icon,
            icon_size = unapprovedPrototype.dark_background_icon_size
          }})
          or nil
        unapprovedPrototype.dark_background_icon = nil
        unapprovedPrototype.dark_background_icon_size = nil
        if unapprovedPrototype.dark_background_icons then
          table.insert(unapprovedPrototype.dark_background_icons, table.deepcopy(unapprovedIconOverlay))
        end
        unapprovedPrototype.icons = unapprovedPrototype.icons or {{
          icon = unapprovedPrototype.icon,
          icon_size = unapprovedPrototype.icon_size
        }}
        unapprovedPrototype.icon = nil
        unapprovedPrototype.icon_size = nil
        table.insert(unapprovedPrototype.icons, table.deepcopy(unapprovedIconOverlay))
        
        table.insert(stupidRecipeThings, {
          type='recipe',
          name=unapprovedPrototype.name..'-recipe',
          -- icons=unapprovedPrototype.icons,
          enabled=false,
          hide_from_player_crafting=true,
          -- unlock_results=false,
          results={{type='item',name=unapprovedPrototype.name--[[@as string]],amount=1}},
          main_product=unapprovedPrototype.name--[[@as string]]
        }--[[@as data.RecipePrototype]])
      end
    end
  end
end

local unapprovedEntityPrototypes = {}
for entityType, _ in pairs(defines.prototypes['entity']) do
  local entityPrototypes = data.raw[entityType]
  for entityPrototypeName, entityPrototype in pairs(entityPrototypes or {}) do
    local unapprovedPrototypeName = placeResultsMap[entityPrototypeName]
    if unapprovedPrototypeName then
      -- Reaching here means we've found a placeable entity prototype
      -- Deep-copy the original prototype and add the copy to the list.  Modify the prototype as needed.
      local unapprovedPrototype = table.deepcopy(entityPrototype)
      table.insert(unapprovedEntityPrototypes, unapprovedPrototype)

      unapprovedPrototype.name = unapprovedPrototypeName
      -- Note: unfortunately it's not practically possible to copy the localised names and descriptions.  The localised values simply
      --       aren't available in the prototype stage, and while it is possible to retrieve them at runtime, there is no way to
      --       inject the values into the prototypes at that point.  Maybe the ghost entity itself could have its name manipulated
      --       at runtime, but most likely, I'll just have to settle for using some approximation of the name based on the actual
      --       prototype name.
      unapprovedPrototype.localised_name = entityPrototype.name..' (Unapproved)'
      unapprovedPrototype.localised_description = 'Unapproved variant of '..entityPrototype.name

      table.insert(unapprovedPrototype.flags, "not-in-made-in") 
      --unapprovedPrototype.hidden = true

      -- Note: placeable_by has to be handled properly otherwise the rail planner prototype fails to load.  It's picky like that.
      if unapprovedPrototype.placeable_by and #unapprovedPrototype.placeable_by > 0 then     
        for _, itemToPlace in pairs(unapprovedPrototype.placeable_by) do
          itemToPlace.item = itemToPlace.item..'-unapproved'
        end
      elseif unapprovedPrototype.placeable_by and unapprovedPrototype.placeable_by.item then
        unapprovedPrototype.placeable_by.item = unapprovedPrototype.placeable_by.item..'-unapproved'
      end
      
      -- Add unapproved checkmark icon layer on top of the original prototype icon
      --   Icon is mandatory, but can be specified either as IconData array or filename+size
      --   Note:  entity prototypes don't have dark_background_icon, only item prototypes may have that
      unapprovedPrototype.icons = unapprovedPrototype.icons or {{
        icon = unapprovedPrototype.icon,
        icon_size = unapprovedPrototype.icon_size
      }}
      unapprovedPrototype.icon = nil
      unapprovedPrototype.icon_size = nil
      table.insert(unapprovedPrototype.icons, table.deepcopy(unapprovedIconOverlay))
    end
  end
end

log(serpent.block(unapprovedEntityPrototypes))
log(serpent.block(unapprovedIconPrototypes))
data.extend(unapprovedEntityPrototypes)
data.extend(unapprovedIconPrototypes)
-- data.extend(stupidRecipeThings)