-- TODO: consider replacing 'draw_text' with 'draw_sprite' and a better icon? (maybe Unicode hammer or hammer-and-wrench?)
-- Unicode marks, for convenience:
--   Useable:  ✘ ✔
--   Not useable:  🛠

-----------------------------------------------------------
--  Internal implementation
-----------------------------------------------------------

local BADGE_TEXT = "✔"
local BADGE_SCALE = 2
local COLOR_UNAPPROVED = {0.5, 0.5, 0.5, 0.4}
local COLOR_APPROVED = {0.0, 0.8, 0.0, 0.6}
local TARGET_OFFSET = {0, -BADGE_SCALE/4}  -- 5/16 ratio is techically closer to center, but it looks better at 1/4

-----------------------------------------------------------
-- External API
-----------------------------------------------------------

local approvalBadges = {}
function approvalBadges.getOrCreate(entity)
  if not storage.approvalBadges then
    storage.approvalBadges = {}
  end
  if not storage.approvalBadges[entity.unit_number] then
    storage.approvalBadges[entity.unit_number] = rendering.draw_text {
      text = "",
      -- text = "██",  -- Can be used for checking text bounding box / alignment
      surface = entity.surface,
      -- target = entity,
      -- target = {entity=entity, offset=TARGET_OFFSET},
      target = {entity=entity, offset={0, 0.5}},
      color = COLOR_UNAPPROVED,
      -- players = {playerIndex},
      alignment = "center",
      vertical_alignment = "middle",
      scale = BADGE_SCALE,
    }.id
  end
  return storage.approvalBadges[entity.unit_number]
end

function approvalBadges.showApproved(badgeId)
  local badge = badgeId and rendering.get_object_by_id(badgeId)
  if badge and badge.valid then
    badge.text = BADGE_TEXT
    badge.color = COLOR_APPROVED
    badge.visible = true
  end
end

function approvalBadges.showUnapproved(badgeId)
  local badge = badgeId and rendering.get_object_by_id(badgeId)
  if badge and badge.valid then
    badge.text = BADGE_TEXT
    badge.color = COLOR_UNAPPROVED
    badge.visible = true
  end
end

function approvalBadges.hide(badgeId)
  local badge = badgeId and rendering.get_object_by_id(badgeId)
  if badge and badge.valid then
    badge.text = ""
    badge.visible = false
  end
end

return approvalBadges