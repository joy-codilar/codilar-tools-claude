---
name: react-native
description: "React Native conventions for Codilar commerce apps - Expo vs bare, navigation, state, platform differences, secure storage, performance, native dependency rules, and jest/RTL/e2e testing. Use whenever changing a React Native app (together with headless-backends for Magento/Shopify/Akinon backends)."
user-invocable: false
---

# React Native

## First, detect the setup
- **Expo** (managed / prebuild, `app.json` / `app.config.*`, maybe expo-router) or **bare** RN (`ios/`, `android/`)?
- Navigation (React Navigation or expo-router), state (Redux Toolkit / Zustand / React Query), API client, styling (StyleSheet / NativeWind / styled-components), i18n. Reuse what's there.
- The backend is in `delivery.json` → `components[].backend`. Load `headless-backends` for commerce API specifics.

## Rules
- **Native dependencies:** adding or upgrading anything that needs `pod install`, Gradle changes or a new Expo dev build is a *plan-level decision*. Flag it and don't do it silently. Prefer pure-JS solutions or already-installed modules.
- Platform differences: use `Platform.select` or `.ios.tsx` / `.android.tsx` files. Test both layouts mentally, and explicitly list anything platform-specific in the MR.
- Tokens and credentials go in secure storage (`expo-secure-store` / Keychain / Keystore), **never AsyncStorage**. No secrets in the JS bundle. Config comes through the project's env mechanism (`react-native-config`, `expo-constants`, EAS env).
- Lists: `FlatList`/`FlashList` with `keyExtractor` and memoised renderItem. No `.map()` over long lists in a ScrollView.
- Avoid unnecessary re-renders: `useMemo`/`useCallback` where it matters. Keep heavy work off the JS thread.
- Images: cached image component if the project has one. Give explicit sizes.
- Accessibility: `accessibilityLabel` / `accessibilityRole` on touchables. Respect the font scale.
- Handle offline, slow-network and loading/error states for every new API-driven screen.
- Deep links and push: if the ticket touches them, update the linking config and document test URLs.

## Testing
- jest + `@testing-library/react-native` for components, hooks and reducers/stores. Mock native modules the way the project's `jest.setup` does.
- `npx tsc --noEmit`, `npm run lint`, `npm test`.
- E2E: if Detox/Maestro flows exist, add or update one for the changed flow. Running them needs a simulator, so if one isn't available, list the manual test steps for QA instead (iOS + Android).
