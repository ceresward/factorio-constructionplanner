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

data:extend{
    constructionPlanner,
    giveConstructionPlanner
}
