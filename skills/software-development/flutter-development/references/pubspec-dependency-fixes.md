# Pubspec Dependency Fixes

## Platform interface version drift (record_linux example)

When a Flutter plugin's platform implementation (e.g., `record_linux`) lags behind its platform interface (`record_platform_interface`), the build fails with missing method implementations:

```
Error: The non-abstract class 'RecordLinux' is missing implementations for these members:
  - RecordMethodChannelPlatformInterface.startStream
```

**Fix**: Add a `dependency_override` in `pubspec.yaml` to force the platform implementation to a compatible version:

```yaml
dependency_overrides:
  record_linux: ^1.0.0
```

Then run `flutter pub get` and rebuild.

**When to use**: This happens when the main plugin package (`record`) pulls in a newer platform interface but the platform implementation hasn't caught up. Common with audio, camera, and sensor plugins that have rapid interface changes.

**Alternative**: If the override doesn't resolve it, consider removing the plugin temporarily and re-adding when the ecosystem stabilizes.

## Non-existent package versions

If `flutter pub get` fails with "doesn't match any versions", the package may not exist on pub.dev or the version was yanked:

```
Because reticulum_wave depends on flutter_usb_serial ^0.5.0 which doesn't match any versions
```

**Fix**: Search pub.dev for the correct package name. In this case, `flutter_usb_serial` doesn't exist — the working package is `usb_serial`:

```yaml
# WRONG
flutter_usb_serial: ^0.5.0

# RIGHT
usb_serial: ^0.5.2
```

Always verify package names on pub.dev before adding to pubspec.
