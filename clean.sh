#!/bin/bash

appdata_fixed=$(echo $APPDATA | tr '\\' '/')

mod_name="ConstructionPlanner"
factorio_mods="${appdata_fixed}/Factorio/mods"

set -x
rm -r ${factorio_mods}/${mod_name}_*