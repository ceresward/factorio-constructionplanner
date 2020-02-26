-- Note: retyping to 'selection-tool' is the easiest way to prevent the item from actually marking ghosts for
-- deconstruction.  Unfortunately that also means losing the filter functionality of the deconstruction planner.  Only
-- way around this would be to use the 'deconstruction-item' type and somehow find a way to capture the deconstructed
-- ghosts and restore them same-tick as approved entities.  Even then, it may not be possible to customize entity
-- selection properly when the item is 'deconstruction-item' type...for the mod to work, it needs to be able to select
-- entities on a separate force, and in Friend Blueprints that wasn't possible with the built-in blueprint type...
local constructionPlanner = table.deepcopy(data.raw["deconstruction-item"]["deconstruction-planner"])
constructionPlanner.type = "selection-tool"
constructionPlanner.icon = "__ConstructionPlanner__/graphics/icons/construction-planner.png"
constructionPlanner.name = "construction-planner"
constructionPlanner.selection_color = {1, 0.5, 0}
constructionPlanner.alt_selection_color = {0.5, 0.25, 0}
constructionPlanner.selection_cursor_box_type = "copy"
constructionPlanner.alt_selection_cursor_box_type = "not-allowed"

local giveConstructionPlanner = table.deepcopy(data.raw["shortcut"]["give-deconstruction-planner"])
giveConstructionPlanner.name = "give-construction-planner"
giveConstructionPlanner.localised_name = nil
giveConstructionPlanner.icon.filename = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/new-construction-planner-x32-white.png";
giveConstructionPlanner.small_icon.filename = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/new-construction-planner-x24.png";
giveConstructionPlanner.disabled_small_icon.filename = "__ConstructionPlanner__/graphics/icons/shortcut-toolbar/mip/new-construction-planner-x24-white.png";
giveConstructionPlanner.item_to_create = "construction-planner"
giveConstructionPlanner.style = "green",

data:extend{
    constructionPlanner,
    giveConstructionPlanner
}
