# factorio-constructionplanner
Source repository for the Factorio mod Construction Planner

## Description

Construction Planner is a mod for the video game [Factorio](https://factorio.com/).  It changes the behavior of how ghost entities are built to give the player more control over planning and building their factory.  With the mod, construction bots will no longer be automatically dispatched to build ghosts; instead, the player must use the new Construction Planner selection tool to approve construction of the ghosts; only then will bots be dispatched.

Why use Construction Planner?

- Plan ahead and stamp out your entire factory ahead of time as ghosts, and approved sections only as needed, so your construction bots won't prematurely build power lines, belts, etc.
- Mouse slipped and that blueprint stamp is off by a tile?  No need to rush - the bots haven't been dispatched yet; there's plenty of time to fix it
- Plenty of time to make those blueprint tweaks for the inputs and outputs, too; the bots will wait until you give it the thumbs-up
- Plan out an entire perimeter defense, without worrying about the bots getting ahead of you.  Then, strategically prioritize construction of the defenses in key locations first.
- Stamp out a huge solar field and approve it in chunks, so the bots won't accidentally build solar panels and accumulators where there's no power yet

![Approval Screenshot](/screenshots/03%20-%20approval.png)

Additional information about mod features and limitations can be found on the [Factorio mod portal page](https://mods.factorio.com/mod/ConstructionPlanner)

## Roadmap

### 1.1
- [ ] Ignore destroyed entity ghosts when approving/unapproving ghosts using the Construction Planner tool
- [ ] Support for entity filters when using the approval tool (similar to the deconstruction planner)
- [ ] Toggle switch to allow/disallow building of unapproved ghosts if there are no approved ghosts left to build

### Unscheduled
- [ ] Option to require approval for tile ghosts as well
- [ ] Support use of the upgrade planner on unapproved ghosts
- [ ] Improved graphics and icons
- [ ] Undo support (if the mod API allows for it)
- [ ] Improve visual appearance when selecting unapproved ghosts using the blueprint and deconstruction tools (if the mod API allows for it)

## How It Works
- Whenever a ghost entity is built or stamped by a player, the mod immediately reassigns the entity to a special 'unapproved ghost' force that is 'mutual friends' with the player's force.  This allows the player to still see and interact with the ghosts, but prevents construction bots from being dispatched to build the ghost.
- At the same time, an invisible 'placeholder' ghost entity is created in the same exact location on the player force.  This entity is what actually gets selected when an unapproved ghost is blueprinted or deconstructed.
- When a blueprint is created that includes placeholder entities, the mod will edit the blueprint to swap out the placeholder blueprint data with the real ghost entity data.  This is done by using a hidden blueprint to capture the same exact area for the unapproved ghost force, and then using the captured blueprint data to overwrite the placeholders in the player's blueprint
- Likewise, when a placeholder entity is deconstructed or destroyed, the unapproved ghost is deconstructed or destroyed as well

## Release Notes

See https://mods.factorio.com/mod/ConstructionPlanner/changelog
