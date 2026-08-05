# Expo + React Native — Session Debugging Notes

## Config Plugin Errors (expo-status-bar)

**Error:** `PluginError: Unable to resolve a valid config plugin for expo-status-bar` + `STRIPPING_TYPES_UNSUPPORTED`

**Cause:** `expo-status-bar@55` (from `npx create-expo-app`) doesn't ship a config plugin, but the Expo template added it to `app.json` plugins. The plugin system tries to import from node_modules and fails.

**Fix:** Remove `"expo-status-bar"` from the `"plugins"` array in `app.json`. The runtime import still works fine — only the config plugin registration breaks.

```jsonc
// BEFORE (broken)
"plugins": [
  "expo-status-bar",
  ["@react-native-community/cli", { "autolinkLibraries": ["react-native-screens"] }]
]

// AFTER (fixed)
"plugins": []
```

**Lesson:** Only list config plugins for packages that actually have a plugin file. Most Expo packages work fine without plugin registration.

## Ionicons Type Hell

**Problem:** `@expo/vector-icons` exports individual icon components (`Ionicons`, `MaterialIcons`, etc.) but NOT a generic `Icon` component. Using `<Icon name="..." />` causes `Cannot find name 'Icon'`.

**Fix:** Always use named icon components:
```tsx
import { Ionicons } from '@expo/vector-icons'
<Ionicons name="home-outline" size={20} color={theme.text} />
```

**Variable icon names:** When the icon name comes from a data array (not hardcoded), TypeScript won't accept the string type. Cast with `as any`:
```tsx
<Ionicons name={link.icon as any} size={24} color={link.color} />
```

This happens because the Ionicons icon set type is a long union of ~1400 string literals, and TypeScript's control flow doesn't recognize a variable of type `string` as matching.

## Theme Index Signature Workaround

**Problem:** Dynamic theme color access (`theme[rarity]`) fails when the theme type is a union of 6+ theme shapes. TypeScript doesn't allow string-indexed access into a union type without an explicit index signature.

**Error:** `Element implicitly has an 'any' type because expression of type 'string' can't be used to index type { readonly bg: ... } | { readonly bg: ... }`

**Fix:** Use an explicit lookup object with `as unknown as` casts:
```tsx
const getRarityColor = (rarity: string) => {
  const map: Record<string, string> = {
    epic: theme.epic as unknown as string,
    rare: theme.rare as unknown as string,
    legendary: theme.legendary as unknown as string,
    uncommon: theme.uncommon as unknown as string,
    common: theme.common as unknown as string,
  }
  return map[rarity] || theme.common as unknown as string
}
```

**Alternative:** Define the theme type with a string index signature in the type definition:
```typescript
export type ThemeColors = {
  // ...all known properties...
  [key: string]: string  // allows dynamic access
}
```

## Version Mismatch Resolution

**Problem:** After `npx create-expo-app`, packages like `expo-linking`, `expo-web-browser`, `react-native-screens`, `react-native-safe-area-context`, `react-native-gesture-handler` report expected versions different from what's installed.

**Error:** `expected version: ~8.0.12` vs installed `55.0.15`

**Fix:** Run `npx expo install --fix` after installing any package. This rewrites `package.json` to use versions compatible with the Expo SDK version.

**Lesson:** Always run `npx expo install --fix` after any `npx expo install <pkg>` or `npm install <pkg>`.

## Entry Point Setup

**Correct setup for bare Expo (no expo-router):**
- Entry file: `src/index.ts`
- Content: `import { registerRootComponent } from 'expo'` + `registerRootComponent(App)`
- `package.json` main: `"./src/index.ts"`
- `tsconfig.json` include: `["src/**/*.ts", "src/**/*.tsx"]`

**Common mistake:** Using the Expo Router `app/` directory structure without actually using `expo-router`. The template is `blank-typescript`, which uses the traditional `src/` structure.

## Dev Server Hanging

**Symptom:** Metro bundler starts but the QR/code screen never appears.

**Fix:**
```bash
pkill -f "expo start"   # Kill any existing processes
lsof -i :8081            # Check for port conflicts
npx expo start --port 8082  # Try a different port
npx expo start --clear    # Clear Metro cache
```

## Screen Import Paths

Screens in `src/screens/` import from sibling directories using one-level-up paths:
```tsx
import { useTheme } from '../ThemeContext'    // Correct
import { useTheme } from '../src/ThemeContext' // Wrong — double src
```

`src/` is the base path in `tsconfig.json` (`"baseUrl": "."` + `"include": ["src/**/*"]`).
