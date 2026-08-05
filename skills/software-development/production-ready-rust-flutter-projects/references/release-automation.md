## GitHub Release Automation with Builds

When shipping personal projects with attached binaries:

```bash
# Create release
gh release create v0.1.0 --title "..." --notes "..."

# Upload / update APK (use --clobber to replace)
gh release upload v0.1.0 path/to/app-release.apk --clobber
```

Common pattern:
- Build APK with `flutter build apk --release`
- Embed custom icon in `mipmap-*` folders before building
- Use `--clobber` when iterating on the same release

This keeps releases up to date without creating duplicate tags.