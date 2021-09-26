-- Note: the original hope was to use a deconstruction planner as the prototype, so I could benefit from the built-in
-- filtering functionality.  However, there is no pragmatic way to prevent the deconstruction behavior from actually
-- occurring, i.e. prevent the selection from actually removing the ghosts as a deconstruction planner normally does.
-- So instead, I'm forced to use a selection-tool, and accept the fact that the entity highlighting won't work unless
-- Wube adds support for it in some future update.
local constructionPlanner = {
    type = "selection-tool",
    name = "construction-planner",
    order = "c[automated-construction]-b[construction-planner]",
    icons = {
        {icon = "__ConstructionPlanner__/graphics/icons/construction-planner.png", icon_size = 64, icon_mipmaps = 4},
        {icon = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/new-construction-planner-x32-white.png", icon_size = 32, scale = 0.75},
    },
    flags = {"hidden", "not-stackable", "spawnable", "only-in-cursor"},
    subgroup = "other",
    stack_size = 1,
    selection_color = {1, 0.5, 0},
    alt_selection_color = {1, 0.5, 0},
    selection_mode = {"nothing"},
    alt_selection_mode = {"nothing"},
    selection_cursor_box_type = "copy",
    alt_selection_cursor_box_type = "copy",
}

local giveConstructionPlanner = {
    type = "shortcut",
    name = "give-construction-planner",
    order = "b[blueprints]-g[construction-planner]",
    action = "spawn-item",
    localised_name = nil,
    associated_control_input = "give-construction-planner",
    technology_to_unlock = "construction-robotics",
    item_to_spawn = "construction-planner",
    style = "green",
    icon = {
        filename = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/new-construction-planner-x32-white.png",
        priority = "extra-high-no-scale",
        size = 32,
        scale = 0.5,
        mipmap_count = 2,
        flags = {"gui-icon"}
    },
    small_icon = {
        filename = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/new-construction-planner-x24-white.png",
        priority = "extra-high-no-scale",
        size = 24,
        scale = 0.5,
        mipmap_count = 2,
        flags = {"gui-icon"}
    },
    disabled_small_icon = {
        filename = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/new-construction-planner-x24-white.png",
        priority = "extra-high-no-scale",
        size = 24,
        scale = 0.5,
        mipmap_count = 2,
        flags = {"gui-icon"}
    }
}

-- TODO: create proper item group/subgroup with icon, descriptions, etc.
local unapproved_item_group = table.deepcopy(data.raw["item-group"]["other"]);
unapproved_item_group.name = "unapproved-entities"
local unapproved_item_subgroup = table.deepcopy(data.raw["item-subgroup"]["other"]);
unapproved_item_subgroup.name = "unapproved-entities-subgroup"
unapproved_item_subgroup.group = "unapproved-entities"

local unapproved_ghost_placeholder = {
    type = "simple-entity-with-owner",
    name = "unapproved-ghost-placeholder",
    flags = {"player-creation", "not-on-map", "hidden", "hide-alt-info", "not-flammable", "not-selectable-in-game", "not-in-kill-statistics"},
    icon = "__base__/graphics/icons/steel-chest.png",
    icon_size = 64, icon_mipmaps = 4,
    picture = {
      filename = "__base__/graphics/entity/steel-chest/steel-chest.png",
      priority = "extra-high",
      width = 32,
      height = 40,
      shift = util.by_pixel(-11, 4.5)
    }
}

local unapproved_ghost_placeholder_item = table.deepcopy(data.raw["item"]["simple-entity-with-owner"])
unapproved_ghost_placeholder_item.name = "unapproved-ghost-placeholder";
unapproved_ghost_placeholder_item.place_result = "unapproved-ghost-placeholder"
unapproved_ghost_placeholder_item.subgroup = "unapproved-entities-subgroup"


data:extend{
    constructionPlanner, giveConstructionPlanner,
    unapproved_item_group, unapproved_item_subgroup,
    unapproved_ghost_placeholder, unapproved_ghost_placeholder_item
}
