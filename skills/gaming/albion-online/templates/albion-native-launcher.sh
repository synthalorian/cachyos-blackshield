#!/bin/bash
# albion-native.sh — pin Albion prefs to a target res and launch (no gamescope).
# Use when the desktop itself runs the target mode (e.g. via EDID override).
# The Albion launcher reads Unity PlayerPrefs and injects -screen args from
# them, and the game rewrites prefs from its own settings UI — so pin right
# before launch, every launch. Adjust W/H to taste.
#
# Steam launch options: /home/synth/bin/albion-native.sh %command% -screen-width 2560 -screen-height 800

PREFS="$HOME/.config/unity3d/Sandbox Interactive GmbH/Albion Online Client/prefs"

if [ -f "$PREFS" ]; then
  sed -i \
    -e 's|\(<pref name="Screenmanager Resolution Width" type="int">\)[0-9]*|\12560|' \
    -e 's|\(<pref name="Screenmanager Resolution Height" type="int">\)[0-9]*|\1800|' \
    -e 's|\(<pref name="Screenmanager Resolution Use Native" type="int">\)[0-9]*|\11|' \
    "$PREFS"
fi

exec gamemoderun "$@"
