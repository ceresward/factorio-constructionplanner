-- TODO: Improved graphics for the shortcut and/or selection-tool, maybe thumbnail as well?
-- TODO: Find some way for the placeholders to have a proper selection border during BP/decon/approval selection
    -- Prototype would likely need a selection_box.  But how to work around the fact that the placeholder remains mineable?
    -- Maybe just work with the mineable placeholder, and use some sort of rendering trick to make it look like the placeholder is the real deal, instead of trying to hide it
    -- But that might not work well with wires/circuits/etc...it may be difficult/brittle to accurately fake those
    -- Also, quick-select might prove tricky...would need to be able to intercept the event on the placeholder and replace it with the real deal

local constructionPlanner = {
    type = "selection-tool",
    name = "construction-planner",
    order = "c[automated-construction]-b[construction-planner]",
    icons = {
        {icon = "__base__/graphics/icons/upgrade-planner.png", icon_size = 64, icon_mipmaps = 4},
        {icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/construction-planner-x32-white.png", icon_size = 32, scale = 0.75},
    },
    flags = {"not-stackable", "spawnable", "only-in-cursor"},
    hidden = true,
    subgroup = "other",
    stack_size = 1,
    select = {
        border_color = {71, 255, 73}, -- copied from upgrade-planner
        cursor_box_type = "copy", -- copied from upgrade-planner
        mode = {"nothing"},
        started_sound = { filename = "__core__/sound/upgrade-select-start.ogg" },
        ended_sound = { filename = "__core__/sound/upgrade-select-end.ogg" }
    },
    alt_select = {
        border_color = {239, 153, 34}, -- copied from upgrade-planner
        cursor_box_type = "copy", -- copied from upgrade-planner
        mode = {"nothing"},
        started_sound = { filename = "__core__/sound/upgrade-select-start.ogg" },
        ended_sound = { filename = "__core__/sound/upgrade-select-end.ogg" }
    },

    -- Note: the below *mostly* works for approval selection.  The problem is that I really need to be able to apply
    -- filters that differentiate between ghosts and non-ghosts, and there doesn't seem to be any good way to do that.
    -- I can implement a filter that selects the approved/unapproved ghosts, but it also selects non-ghost entities
    -- as well, which is weird.  Instead, I think it's better to just select "nothing", as above
    -- selection_mode = {"blueprint"},
    -- entity_filters = {"unapproved-ghost-placeholder"},
    -- tile_filters = {"out-of-map"}, -- forces tiles to never be included in the selection
    -- alt_selection_mode = {"blueprint"},
    -- alt_entity_filter_mode = "blacklist",
    -- -- alt_entity_type_filters = {"entity-ghost", "transport-belt"},
    -- alt_tile_filters = {"out-of-map"}, -- forces tiles to never be included in the selection
}

local giveConstructionPlannerInput = {
    type = "custom-input",
    name = "give-construction-planner",
    localised_name = nil, -- Defined in locale cfg files
    localised_description = nil, -- Defined in locale cfg files
    key_sequence = "ALT + N",
    action = "spawn-item",
    item_to_spawn = "construction-planner",
}

local giveConstructionPlannerShortcut = {
    type = "shortcut",
    name = "give-construction-planner",
    order = "b[blueprints]-g[construction-planner]",
    localised_name = nil, -- Defined in locale cfg files
    localised_description = nil, -- Defined in locale cfg files
    associated_control_input = giveConstructionPlannerInput.name,
    action = giveConstructionPlannerInput.action,
    item_to_spawn = giveConstructionPlannerInput.item_to_spawn,
    -- Note: the tech unlock is disabled until further notice, until I figure out if it's possible to detect when the
    --       shortcut isn't yet available (I don't want to auto-unapprove ghosts if the selection-tool isn't yet
    --       unlocked).  It might look a little weird for that one shortcut to appear right from the start, but it's
    --       not too likely to matter...most players will have unlocked BP tech well before exploring mods
    -- technology_to_unlock = "construction-robotics",
    style = "green",
    icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/new-construction-planner-x32-white.png",
    icon_size = 32,
    small_icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/new-construction-planner-x24-white.png",
    small_icon_size = 24
}

local toggleAutoApproveInput = {
    type = "custom-input",
    name = "toggle-auto-approve",
    localised_name = nil, -- Defined in locale cfg files
    localised_description = nil, -- Defined in locale cfg files
    key_sequence = "SHIFT + ALT + N",
    action = "lua",
}

local toggleAutoApproveShortcut = {
    type = "shortcut",
    name = "toggle-auto-approve",
    order = "a[auto-approve]",
    localised_name = nil, -- Defined in locale cfg files
    localised_description = nil, -- Defined in locale cfg files
    action = toggleAutoApproveInput.action,
    associated_control_input = toggleAutoApproveInput.name,
    -- Note: the tech unlock is disabled until further notice, until I figure out if it's possible to detect when the
    --       shortcut isn't yet available (I don't want to auto-unapprove ghosts if the selection-tool isn't yet
    --       unlocked).  It might look a little weird for that one shortcut to appear right from the start, but it's
    --       not too likely to matter...most players will have unlocked BP tech well before exploring mods
    -- technology_to_unlock = "construction-robotics",
    style = "default",
    toggleable = true,
    icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/auto-approve-x32.png",
    icon_size = 32,
    small_icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/auto-approve-x24.png",
    small_icon_size = 24
}

-- Note: this item group and subgroup help to organize the placeholder icon in the editor 'all entities' list
local unapproved_item_group = table.deepcopy(data.raw["item-group"]["other"]);
unapproved_item_group.name = "unapproved-entities"
unapproved_item_group.icons = {
    {icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/construction-planner-x32-white.png", icon_size = 32, scale = 0.75}
}
local unapproved_item_subgroup = table.deepcopy(data.raw["item-subgroup"]["other"]);
unapproved_item_subgroup.name = "unapproved-entities-subgroup"
unapproved_item_subgroup.group = "unapproved-entities"

-- Notes:
--  - placeable-off-grid is used to ensure the entity will have the exact same position coordinates as its counterpart
--  - player-creation flag is necessary for the placeholder to be contained within a ghost
--  - selection_box should not be enabled!  It allows the entity to be mined, in spite of the 'not-selectable-in-game' flag.
local unapproved_ghost_placeholder = {
    type = "simple-entity-with-owner",
    name = "unapproved-ghost-placeholder",
    flags = {"placeable-off-grid", "player-creation", "not-on-map", "hide-alt-info", "not-flammable", "not-selectable-in-game", "not-in-kill-statistics"},
    hidden = true,
    -- selection_box = {{-0.5, -0.5}, {0.5, 0.5}}, -- DO NOT ENABLE
    icons = {
        {icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/construction-planner-x32-white.png", icon_size = 32, scale = 0.75}
    },
    picture = {
      -- filename = "__base__/graphics/entity/steel-chest/steel-chest.png",
      filename = "__ConstructionPlanner__/graphics/icons/placeholder.png",
      -- priority = "extra-high",
      width = 1,
      height = 1,
      -- shift = util.by_pixel(-11, 4.5)
    }
}

-- Notes:
--  - This item is necessary for the placeholder to be contained within a ghost (probably b/c the blueprint tool needs to show the icon during selection)
--  - The icon is also used for placeholders in the editor 'all entities' list
local unapproved_ghost_placeholder_item = table.deepcopy(data.raw["item"]["simple-entity-with-owner"])
unapproved_ghost_placeholder_item.name = "unapproved-ghost-placeholder";
unapproved_ghost_placeholder_item.place_result = "unapproved-ghost-placeholder"
unapproved_ghost_placeholder_item.subgroup = "unapproved-entities-subgroup"
unapproved_ghost_placeholder_item.icons = {
    {icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/construction-planner-x32-white.png", icon_size = 32, scale = 0.75}
}


data:extend{
    constructionPlanner,
    giveConstructionPlannerInput, giveConstructionPlannerShortcut,
    toggleAutoApproveInput, toggleAutoApproveShortcut,
    unapproved_item_group, unapproved_item_subgroup,
    unapproved_ghost_placeholder, unapproved_ghost_placeholder_item
}
