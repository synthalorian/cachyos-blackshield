#!/usr/bin/env bash
# assess-singletons.sh
# Reusable assessment script for Unity Singleton→DI migration planning.
# Run from the Unity project root (where Assets/ lives).
#
# Usage: bash /path/to/assess-singletons.sh
# Output: Compact summary of migration scope

set -e

PROJECT_ROOT="$(pwd)"
echo "=== Unity DI Migration Assessment ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Check it's a Unity project
if [ ! -d "$PROJECT_ROOT/Assets" ]; then
  echo "ERROR: No Assets/ directory found. Not a Unity project."
  exit 1
fi

# Unity version
if [ -f "$PROJECT_ROOT/ProjectSettings/ProjectVersion.txt" ]; then
  UNITY_VER=$(head -3 "$PROJECT_ROOT/ProjectSettings/ProjectVersion.txt" 2>/dev/null | tr '\n' '|')
  echo "Unity version: $UNITY_VER"
else
  echo "Unity version: (no ProjectVersion.txt)"
fi

# C# files & LOC
CS_COUNT=$(find "$PROJECT_ROOT/Assets" -name '*.cs' -type f 2>/dev/null | wc -l)
LOC=$(find "$PROJECT_ROOT/Assets" -name '*.cs' -type f -exec cat {} + 2>/dev/null | wc -l)
echo "C# files: $CS_COUNT"
echo "Total LOC: $LOC"
echo ""

# Singleton Instance properties
INSTANCE_COUNT=$(grep -rn "public static.*Instance\b.*{ get; private set; }" "$PROJECT_ROOT/Assets" --include="*.cs" 2>/dev/null | grep -v "///\|AssetDatabase\|EditorGUI\|EditorGUILayout\|RefactoringPlan" | awk -F: '{print $1}' | sort -u | wc -l)
INSTANCE_REF=$(grep -rn "\.Instance\b" "$PROJECT_ROOT/Assets" --include="*.cs" 2>/dev/null | grep -v "///\|Debug\.\|Time\.\|Input\.\|Vector3\|Quaternion\|Color\|Mathf\|Object\.\|Camera\.\|System\.\|String\.\|Random\.\|Physics\.\|SceneManager\|Application\.\|Resources\.\|Transform\.\|Component\.\|GameObject\.\|PlayerPrefs" | wc -l)
echo "Files with static Instance property: $INSTANCE_COUNT"
echo "Approximate .Instance references: $INSTANCE_REF"
echo ""

# Singleton base class usage
SINGLETON_INHERIT=$(grep -rn ": Singleton<" "$PROJECT_ROOT/Assets" --include="*.cs" 2>/dev/null | grep -v "///\|abstract class Singleton<" | wc -l)
echo "Classes inheriting Singleton<T>: $SINGLETON_INHERIT"
echo ""

# Check for existing DI
if [ -f "$PROJECT_ROOT/Packages/manifest.json" ]; then
  DI_FOUND=$(grep -i "vcontainer\|zenject\|extenject\|di\|injection" "$PROJECT_ROOT/Packages/manifest.json" 2>/dev/null | wc -l)
  if [ "$DI_FOUND" -gt 0 ]; then
    echo "DI framework: PRESENT in packages"
    grep -i "vcontainer\|zenject\|extenject" "$PROJECT_ROOT/Packages/manifest.json" 2>/dev/null
  else
    echo "DI framework: NOT FOUND"
  fi
else
  echo "Packages: (no manifest.json)"
fi

echo ""

# Scenes
SCENE_COUNT=$(find "$PROJECT_ROOT/Assets" -name '*.unity' -type f 2>/dev/null | wc -l)
echo "Scene files: $SCENE_COUNT"

# Tests
TEST_COUNT=$(find "$PROJECT_ROOT/Assets" -name '*Test*.cs' -o -name '*test*.cs' 2>/dev/null | wc -l)
echo "Test files: $TEST_COUNT"
echo ""

# Event system pattern
GAME_EVENTS_FILE=$(find "$PROJECT_ROOT/Assets" -name 'GameEvents.cs' -type f 2>/dev/null | head -1)
if [ -n "$GAME_EVENTS_FILE" ]; then
  STRING_EVENTS=$(grep -c "AddListener(\"" "$GAME_EVENTS_FILE" 2>/dev/null || echo 0)
  TYPED_EVENTS=$(grep -c "event Action<" "$GAME_EVENTS_FILE" 2>/dev/null || echo 0)
  if [ "$STRING_EVENTS" -gt 0 ] && [ "$TYPED_EVENTS" -gt 0 ]; then
    echo "Event pattern: MIXED (string-based + typed)"
  elif [ "$STRING_EVENTS" -gt 0 ]; then
    echo "Event pattern: STRING-BASED (name-keyed dictionary)"
  elif [ "$TYPED_EVENTS" -gt 0 ]; then
    echo "Event pattern: TYPED (static event Action<...>)"
  fi
  echo "  GameEvents.cs: $STRING_EVENTS string listeners, $TYPED_EVENTS typed events"
else
  # Check for raw per-class events
  RAW_EVENT_COUNT=$(grep -rn "event Action<" "$PROJECT_ROOT/Assets" --include="*.cs" 2>/dev/null | grep -v "///\\|interface\|IEventBus\|Publish<\|Subscribe<" | wc -l)
  echo "Event pattern: RAW PER-CLASS (no centralized event bus)"
  echo "  Raw event Action<> declarations: ~$RAW_EVENT_COUNT"
fi
echo ""

# Directory structure
echo "Top directories by file count:"
for dir in "$PROJECT_ROOT/Assets/Scripts"/*/; do
  if [ -d "$dir" ]; then
    count=$(find "$dir" -name '*.cs' -type f 2>/dev/null | wc -l)
    basename "$dir" | xargs -I{} echo "  $count  {}"
  fi
done 2>/dev/null | sort -rn | head -15

echo ""
echo "=== Assessment Complete ==="
