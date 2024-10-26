local approvableTypes = require('data.approvablePrototypes')

-- TODO: deepcopy eligible prototypes and create shadow variants for unapproved ghost purposes
--   - Figure out what properties to alter to make things go more smoothly (placeable_by?  others?)
local shadowPrototypes = {}
for _, approvableType in pairs(approvableTypes) do
  local rawTypes = data.raw[approvableType]
  if rawTypes then
    for _, approvablePrototype in pairs(rawTypes) do
      local shadowPrototype = table.deepcopy(approvablePrototype)
      shadowPrototype.name = shadowPrototype.name..'-unapproved'
      -- Note: unfortunately it's not practically possible to copy the localised names and descriptions.  The localised values simply
      --       aren't available in the prototype stage, and while it is possible to retrieve them at runtime, there is no way to
      --       inject the values into the prototypes at that point.  Maybe the ghost entity itself could have its name manipulated
      --       at runtime, but most likely, I'll just have to settle for using some approximation of the name based on the actual
      --       prototype name.
      shadowPrototype.localised_name = shadowPrototype.name..' (Unapproved)'
      shadowPrototype.placeable_by = nil
      table.insert(shadowPrototypes, shadowPrototype)
    end
  end
end

data.extend(shadowPrototypes)