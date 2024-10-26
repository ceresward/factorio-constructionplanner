
local approvalBadges = require('control.approvalBadges')
local forces = require('control.forces')

-- /c remote.call("constructionplanner","badgeScan")
local function badgeScan()
  local ghostEntities = game.player.surface.find_entities_filtered {
    type = "entity-ghost"
  }
  game.print("construction-planner: scanning badges for  "..tostring(#ghostEntities).." ghost entities")
  for _, entity in pairs(ghostEntities) do
    local badgeId = approvalBadges.getOrCreate(entity);
    if forces.is_unapproved_force(entity.force--[[@as LuaForce]]) then
      approvalBadges.showUnapproved(badgeId)
    else
      approvalBadges.showApproved(badgeId)
    end
  end
end

-- /c remote.call("constructionplanner","listUnapprovedPrototypes")
local function listUnapprovedPrototypes()
  local unapprovedPrototypeNames = {}
  for name, _ in pairs(prototypes.entity) do
    local suffix = string.sub(name, -11)
    if suffix == '-unapproved' then
      table.insert(unapprovedPrototypeNames, name)
    end
  end
  table.sort(unapprovedPrototypeNames)
  local filename = 'constructionplanner-prototypes-list.txt'
  game.print('Found '..#unapprovedPrototypeNames..' unapproved prototypes.  Writing list to file '..filename)
  helpers.write_file(filename, serpent.block(unapprovedPrototypeNames))
end

-- /c remote.call("constructionplanner","listPlaceableEntities")
local function listPlaceableEntities()
  local placeableItemsSet = {}
  for name, proto in pairs(prototypes.item) do
    if proto.place_result and proto.place_result.name then
      placeableItemsSet[proto.place_result.name] = proto.place_result.name
    end
  end
  local placeableItems = {}
  for name, _ in pairs(placeableItemsSet) do
    table.insert(placeableItems, name)
  end
  table.sort(placeableItems)
  local filename = 'constructionplanner-placeable-items-list.txt'
  game.print('Found '..#placeableItems..' placeable entities.  Writing list to file '..filename)
  helpers.write_file(filename, serpent.block(placeableItems))
end

return {
  badgeScan = badgeScan,
  listUnapprovedPrototypes = listUnapprovedPrototypes,
  listPlaceableEntities = listPlaceableEntities
}