## Android App Icon Embedding (Release APK)

When using a custom high-resolution PNG as the launcher icon:

1. Copy the icon to all density folders:
   ```bash
   cp gridos.png android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png
   cp gridos.png android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
   cp gridos.png android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
   cp gridos.png android/app/src/main/res/mipmap-hdpi/ic_launcher.png
   cp gridos.png android/app/src/main/res/mipmap-mdpi/ic_launcher.png
   ```

2. Rebuild the release APK:
   ```bash
   flutter build apk --release
   ```

3. The icon will now appear as the installed app icon (not just an asset).

Note: Placing the icon only in `assets/` is insufficient for launcher icons.