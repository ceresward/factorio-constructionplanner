local approvalBadges = {}

local badgeScale = 2

-- TODO: consider replacing 'draw_text' with 'draw_sprite' and a better icon? (maybe Unicode hammer or hammer-and-wrench?)
-- Unicode marks, for convenience:
--   Useable:  ✘ ✔
--   Not useable:  🛠

-----------------------------------------------------------
--  Public functions
-----------------------------------------------------------

function approvalBadges.getOrCreate(entity)
  if not global.approvalBadges then
    global.approvalBadges = {}
  end
  if not global.approvalBadges[entity.unit_number] then
    global.approvalBadges[entity.unit_number] = rendering.draw_text {
      text = "",
      -- text = "██",  -- Can be used for checking text bounding box / alignment
      surface = entity.surface,
      target = entity,
      -- 5/16 ratio is techically closer to center, but it kinda looks better at 1/4
      --target_offset = {0, -badgeScale*5/16},
      target_offset = {0, -badgeScale/4},
      color = {0.5, 0.5, 0.5},
      -- players = {playerIndex},
      alignment = "center",
      scale = badgeScale,
    }
  end
  return global.approvalBadges[entity.unit_number]
end

function approvalBadges.showApproved(badgeId)
  if badgeId and rendering.is_valid(badgeId) then
    rendering.set_text(badgeId, "✔")
    rendering.set_color(badgeId, {0.0, 0.8, 0.0, 0.6})
    rendering.set_visible(badgeId, true)
  end
end

function approvalBadges.showUnapproved(badgeId)
  if badgeId and rendering.is_valid(badgeId) then
    rendering.set_text(badgeId, "✔")
    rendering.set_color(badgeId, {0.5, 0.5, 0.5, 0.4})
    rendering.set_visible(badgeId, true)
  end
end

function approvalBadges.hide(badgeId)
  if badgeId and rendering.is_valid(badgeId) then
    rendering.set_text(badgeId, "")
    rendering.set_visible(badgeId, false)
  end
end

-----------------------------------------------------------
--  Private functions
-----------------------------------------------------------



-----------------------------------------------------------

return approvalBadges