# Description

Construction Planner changes the behavior of how ghost entities are built to give the player more control over planning and building their factory.  With the mod, construction bots will no longer be automatically dispatched to build ghosts; instead, the player must use the new Construction Planner selection tool to approve construction of the ghosts; only then will bots be dispatched.

Why use Construction Planner?

- Plan ahead and stamp out your entire factory ahead of time as ghosts, and approve sections only as needed, so your construction bots won't prematurely build power lines, belts, etc.
- Mouse slipped and that blueprint stamp is off by a tile?  No need to rush - the bots haven't been dispatched yet; there's plenty of time to fix it
- Plenty of time to make those blueprint tweaks for the inputs and outputs, too; the bots will wait until you give it the thumbs-up
- Plan out an entire perimeter defense, without worrying about the bots getting ahead of you.  Then, strategically prioritize construction of the defenses in key locations first.
- Stamp out a huge solar field and approve it in chunks, so the bots won't accidentally build solar panels and accumulators where there's no power yet

## Features

- Ghost entities are no longer built automatically by construction bots; instead, they must first be approved by the player
    - Exception: ghosts created when an entity is destroyed don't require approval and will be rebuilt as usual
- Use the Construction Planner tool (in the shortcut bar) to approve and unapprove ghosts for construction
- Use the auto-approve mod setting to save time when you just want everything to be approved as soon as you stamp it

## Known Limitations

- The upgrade planner doesn't yet work on unapproved ghosts
- Blueprinting and deconstruction of unapproved ghosts works, but the selection border will look a little strange
- If an approved ghost becomes unapproved, any construction bots already en route won't turn around until they reach the build site (compare this to when a ghost is deconstructed, in which case the bots turn around immediately)

# Roadmap

Please see the [Github project README](https://github.com/ceresward/factorio-constructionplanner) for the development roadmap

# How It Works

Please see the [Github project README](https://github.com/ceresward/factorio-constructionplanner) for technical information about how the mod works
