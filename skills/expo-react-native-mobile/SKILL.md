---
name: expo-react-native-mobile
description: >
  Scaffold, build, and debug Expo + React Native mobile apps. Covers project
  setup, dependency alignment, navigation, theming, screen implementation,
  and the common TypeScript/runtime pitfalls that trip up mobile builds.
version: 1.0.0
author: synthclaw
category: software-development
tags: [expo, react-native, mobile, typescript, cross-platform, scaffolding, debugging]
---

# Expo + React Native Mobile

Use this skill when building **Expo + React Native mobile apps** — from scaffolding a new project to debugging TypeScript errors, navigation wiring, and platform-specific gotchas.

Load when the user says things like:
- "Let's build a mobile app"
- "Set up an Expo project"
- "Make it work on both iOS and Android"
- "React Native / Expo help"

## Quick Reference

### Project Scaffolding

```bash
cd /home/synth/projects
npx create-expo-app@latest <app-name> -t blank-typescript
cd <app-name>
npx expo install <packages>
```

### Dependency Alignment (CRITICAL STEP)

After installing packages, ALWAYS run:

```bash
npx expo install --fix
```

This aligns all Expo-linked packages to the correct versions for your SDK. Skipping this causes cryptic runtime errors that waste 20+ minutes.

### Common Pitfalls

1. **Config plugins break the dev server** — If a package (like `expo-status-bar`) complains about config plugins, remove it from the `"plugins"` array in `app.json`. Keep the `import` — it works fine at runtime; the plugin registration is what breaks.

2. **`@expo/vector-icons` doesn't export a generic `Icon` component** — Use `Ionicons` directly: `import { Ionicons } from '@expo/vector-icons'`. Named icon strings (e.g., `'home-outline'`) must be typed as `as any` when the string comes from a variable (array data, not hardcoded).

3. **Theme types with index signatures** — Dynamic theme color access (`theme[rarity]`) fails because TypeScript doesn't allow string-indexed union types. Use a lookup object: `const map: Record<string, string> = { epic: theme.epic as unknown as string }`.

4. **Expo entry point** — Use `src/index.ts` with `registerRootComponent(App)` pointing to `src/App.tsx`. Set `"main": "./src/index.ts"` in package.json. Don't use `app/` directory routing unless you're using `expo-router`.

5. **`tsconfig.json`** — Use `"extends": "expo/tsconfig.base"` with `"skipLibCheck": true` and `"include": ["src/**/*.ts", "src/**/*.tsx"]`. This suppresses node_modules type errors from conflicting packages.

6. **Screen import paths** — Screens live in `src/screens/`. Import from `../ThemeContext` (not `../src/ThemeContext`) since `src/` is the base path.
7. **Node v25 ESM + @expo/vector-icons** — Node v25's native ESM resolver can't handle `@expo/vector-icons`'s bare imports (e.g., `import ... from './createIconSet'` without `.js` extension). Metro bundler handles this fine via its own resolver, so the app runs correctly. If you need to `require()` the package from Node (e.g., in scripts), downgrade to `@expo/vector-icons@14.x`. Don't let the `require()` failure scare you — it's irrelevant for the actual Metro runtime.
8. **Navigation architecture for multi-screen apps** — Use `Stack.Navigator` as the root for deep-linkable screens (e.g., `ClassBuilder`, `Ascension`, `ThemePicker`), and nest a `Tab.Navigator` inside as the `MainTabs` screen. This lets quick links navigate to stack screens while tabs handle the main flow. Pass `navigation` prop to screens that need deep navigation: `{ navigation }: any`.

## Core Workflow

### Step 1: Scaffold

```bash
npx create-expo-app@latest <name> -t blank-typescript
cd <name>
npx expo install @react-navigation/native @react-navigation/bottom-tabs \
  @react-navigation/stack react-native-screens react-native-safe-area-context \
  react-native-gesture-handler expo-status-bar @expo/vector-icons
```

### Step 2: Align Dependencies

```bash
npx expo install --fix
```

### Step 3: Set Up Structure

```
src/
├── App.tsx              — Root navigator
├── ThemeContext.tsx     — Theme provider + ThemeKey type
├── theme.ts             — Theme palette definitions
├── screens/
│   ├── HomeScreen.tsx
│   ├── LorekeeperScreen.tsx
│   └── ...
└── index.ts             — Entry point (registerRootComponent)
```

### Step 4: Implement Screens

Each screen:
- Imports `useTheme` from `../ThemeContext`
- Imports `Ionicons` from `@expo/vector-icons` (not generic `Icon`)
- Uses `navigation` prop typed as `any` for simplicity
- Wraps content in `<ScrollView>` or `<View>` with theme colors
- Uses `StyleSheet.create` for layout

### Step 5: Verify

```bash
npx tsc --noEmit --skipLibCheck  # Check for TS errors (grep -v node_modules)
npx expo start --clear            # Clear cache, run dev server
```

### Step 6: Multi-Screen App Structure (if applicable)

For apps with 5+ screens, use this navigation pattern:

```tsx
// App.tsx — Root
<NavigationContainer>
  <Stack.Navigator>
    <Stack.Screen name="MainTabs" component={TabNavigator} options={{ headerShown: false }} />
    <Stack.Screen name="ClassBuilder" component={ClassBuilderScreen} />
    <Stack.Screen name="ThemePicker" component={ThemePickerScreen} />
    <Stack.Screen name="Ascension" component={AscensionScreen} />
  </Stack.Navigator>
</NavigationContainer>

// TabNavigator — Inside Stack
const TabNavigator = () => (
  <Tab.Navigator>
    <Tab.Screen name="home" component={HomeScreen} />
    <Tab.Screen name="lore" component={LorekeeperScreen} />
    <Tab.Screen name="class" component={ClassBuilderScreen} />
    <Tab.Screen name="journal" component={JournalScreen} />
    <Tab.Screen name="more" component={MoreScreen} />
  </Tab.Navigator>
)
```

This allows deep links to stack screens (`navigation.navigate('ClassBuilder')`) while the tabs handle the main flow. Home screen quick links should navigate to the stack screen for deep features and to `MainTabs` for tab-based features.

## Theming Pattern

### Theme Definition (`theme.ts`)

```typescript
export type ThemeKey = 'warcraft-classic' | 'synthwave-vapor'

export type ThemeColors = {
  bg: string; bgSecondary: string; bgTertiary: string;
  border: string; text: string; textSecondary: string; textMuted: string;
  cardBg: string;
  accent: string; success: string; warning: string; danger: string;
  // Faction colors
  alliance: string; horde: string;
  // Rarity colors
  common: string; uncommon: string; rare: string; epic: string; legendary: string;
}
```

### Theme Context (`ThemeContext.tsx`)

Export `ThemeKey` type so screens can reference it:
```typescript
export { type ThemeKey } from './theme'
```

### Dynamic Icon Names (Ionicons)

When icon names come from data arrays, cast with `as any`:
```tsx
<Ionicons name={item.icon as any} size={20} color={item.color} />
```

## Reference Files

- **`references/expo-react-native-pitfalls.md`** — Detailed debugging notes from sessions: config plugin errors, Ionicons type issues, theme index signature workarounds, version mismatch resolution, entry point setup.
- **`references/multi-screen-apps.md`** — Navigation patterns for 5+ screen apps: Stack + Tab nesting, icon mapping, dynamic color lookups, Quick Link navigation. Load when building complex multi-section apps.

## Pitfalls

- **Don't list `expo-status-bar` or other packages in `app.json` plugins** unless they have a real config plugin file. The plugin system tries to import from node_modules and fails.
- **Don't use generic `<Icon name={...}>` from `@expo/vector-icons`** — it doesn't export a named `Icon` component. Use `Ionicons`, `MaterialIcons`, etc. directly.
- **Don't skip `npx expo install --fix`** after installing any Expo-linked package. This is the #1 cause of "it works on my machine" mobile app bugs.
- **Don't forget the `tsconfig.json` `skipLibCheck`** — Expo templates have conflicting type definitions in node_modules. Skip library checking to avoid noise.
- **Don't use `../src/ThemeContext`** — screens are already in `src/screens/`, so the import path is `../ThemeContext`.
- **Dynamic string → icon name mappings** always need `as any` casting because TypeScript doesn't allow arbitrary string indexing into the Ionicons icon set type.
- **Dynamic theme color access** (e.g., `theme[rarity]`) fails with union types. Use an explicit lookup object with `as unknown as string` casts.
- **Dynamic faction/theme color access** (e.g., `theme[key.toLowerCase()]` where key is `'Alliance' | 'Horde'`) — same issue. Always use an explicit `Record<string, string>` lookup: `const factionColors: Record<string, string> = { Alliance: theme.alliance, Horde: theme.horde }`.
- **Expo dev server hangs** — if it starts but doesn't show the QR/code screen, check port conflicts: `lsof -i :8081` and kill existing processes.
- **Class icon aliases** — Don't store icon names directly on class objects (e.g., `{ name: 'Warrior', icon: 'swords' }`). Use a top-level `ION_MAP: Record<string, string>` lookup: `const ION_MAP = { warrior: 'swords', paladin: 'shield-outline', ... }`. This avoids duplicate definitions and keeps the map in one place.
- **Variable icon names always need `as any`** — Whether from class objects, data arrays, or route params, any dynamic string passed to `<Ionicons name={...}>` needs `as any` casting.
- **Stack + Tab navigation pattern** — Use `Stack.Navigator` as root, with a `Tab.Navigator` rendered inside a `MainTabs` stack screen. This enables deep linking to tab screens (e.g., `ClassBuilder`) while tabs handle the main bottom nav flow.

## Relation to Other Skills

- **Complements `spike`** — use `spike` to validate mobile tech choices (e.g., "Can Expo do offline-first with SQLite?") before scaffolding the real app.
- **After `spike` validates mobile** — this skill takes the prototype and builds the full app.
- **Before `subagent-driven-development`** — use this to scaffold the project structure, then dispatch subagents per screen.

## Remember
Remember
```
Scaffold → Align (expo install --fix) → Structure → Build → Verify
Config plugins: remove if they break
Icon: Ionicons, not generic Icon
Theme: lookup objects, not dynamic index
tsconfig: skipLibCheck = true
Entry point: src/index.ts with registerRootComponent
Node v25: @expo/vector-icons require() fails, but Metro runtime is fine
Navigation: Stack root + Tab nest for 5+ screen apps
Icons: ION_MAP lookup, not embedded on data objects
Colors: Record<string, string> lookups, not dynamic theme indexing
```

Further Reading
- **`references/expo-react-native-pitfalls.md`** — Session-specific debugging notes: config plugin errors, Ionicons type hell, theme index signature workarounds, version alignment. Load when debugging Expo/React Native issues.

**A well-structured Expo project compiles clean and runs immediately.** Don't let version mismatches or config plugins eat your day — fix them first.