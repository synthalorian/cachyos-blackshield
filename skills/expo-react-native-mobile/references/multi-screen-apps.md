# Multi-Screen Expo Apps — Architecture Patterns

## Navigation Pattern for 5+ Screen Apps

Use Stack as the root navigator, with a Tab navigator nested inside. This enables:
- **Deep linking** to complex screens (ClassBuilder, ThemePicker, Ascension)
- **Tab navigation** for the main flow (Home, Lore, Journal, More)
- **Consistent header** across all screens

```tsx
const Stack = createStackNavigator()
const Tab = createBottomTabNavigator()

// Root navigator
<NavigationContainer>
  <Stack.Navigator screenOptions={{ headerShown: true }}>
    <Stack.Screen name="MainTabs" component={TabNavigator} options={{ headerShown: false }} />
    <Stack.Screen name="ClassBuilder" component={ClassBuilderScreen} options={{ title: 'Class Builder' }} />
    <Stack.Screen name="ThemePicker" component={ThemePickerScreen} options={{ title: 'Choose Theme' }} />
    <Stack.Screen name="Ascension" component={AscensionScreen} options={{ title: 'Ascension' }} />
  </Stack.Navigator>
</NavigationContainer>

// Tab navigator (rendered inside Stack)
const TabNavigator = () => (
  <Tab.Navigator screenOptions={{ headerShown: false }}>
    <Tab.Screen name="home" component={HomeScreen} />
    <Tab.Screen name="lore" component={LorekeeperScreen} />
    <Tab.Screen name="class" component={ClassBuilderScreen} />
    <Tab.Screen name="journal" component={JournalScreen} />
    <Tab.Screen name="more" component={MoreScreen} />
  </Tab.Navigator>
)
```

## Quick Link Navigation

Home screen quick links must account for both tab and stack navigation:
```tsx
// Tab-based features → navigate to MainTabs (resets to home tab)
navigation?.navigate('MainTabs')

// Stack-based features → navigate to the screen name
navigation?.navigate('ClassBuilder')
navigation?.navigate('Ascension')
```

## Icon Mapping Pattern

Don't store icon names on data objects. Use a top-level lookup:
```tsx
const ION_MAP: Record<string, string> = {
  warrior: 'swords',
  paladin: 'shield-outline',
  hunter: 'ellipse-outline',
  rogue: 'cut-outline',
  priest: 'medkit-outline',
  deathknight: 'skull-outline',
  shaman: 'water-outline',
  mage: 'flame-outline',
  warlock: 'sparkles-outline',
  druid: 'leaf-outline',
}

// Usage
<Ionicons name={ION_MAP[item.key] as any} size={20} color={item.color} />
```

This avoids:
- Duplicate icon definitions in class/spec data
- Hard-to-maintain icon ↔ data coupling
- TypeScript errors from dynamic string → icon mapping

## Dynamic Color Lookups

Never use dynamic indexing into theme objects:
```tsx
// WRONG
const color = theme[key.toLowerCase()] // TS error: no index signature

// RIGHT
const factionColors: Record<string, string> = {
  Alliance: theme.alliance,
  Horde: theme.horde,
}
const color = factionColors[key]
```

Same pattern for rarity colors, status colors, etc.

## Session Context

This pattern was developed for **Open Warcraft** (`/home/synth/projects/open-warcraft`), a multi-section companion app with 7 screens: Home, Lorekeeper, Class Builder, Ascension, Journal, Warband, and More. The app uses React Navigation with Stack + Tab nesting, 6 themes, and dynamic icon/color lookups.
