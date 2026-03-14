# App Branding Guide (Name, Package ID, Icon, Splash)

This guide covers changing the app name, package/bundle ID, app icon, and splash screen.

## 1) Package Name / Bundle Identifier

Set this **before** releasing to stores.

### Android

- Update `applicationId` in `android/app/build.gradle`.
- Update `namespace` in `android/app/build.gradle` to match the package.
- If you have any Android-specific package references, update them to the new package name:
  - `android/app/src/main/AndroidManifest.xml` (package-related entries if present).
  - Any Kotlin/Java package declarations under `android/app/src/main/kotlin/`.

### iOS

- Set the **Bundle Identifier** in Xcode (`ios/Runner.xcworkspace`).
- Ensure it matches the App ID in Apple Developer.

### Flutter/Dart (optional if you reference package name explicitly)

- Search for old package IDs and update any hardcoded references.
- Update any OAuth redirect URIs or deep link schemes that depend on the package/bundle ID.

### After Release Warning

- Changing package/bundle ID **after** release creates a **new app** in stores.
- Existing users will not receive updates from the new ID.

---

## Option: Use `change_app_package_name` (Recommended)

This project already includes the `change_app_package_name` dev dependency in `pubspec.yaml`.
You can use it to update Android + iOS identifiers in one step.

1. Run (you run):

```bash
flutter pub run change_app_package_name:main com.yourcompany.yourapp
```

2. Re-open Xcode and verify:

- Bundle Identifier is correct.
- Signing settings still point to the right Team and profiles.

3. Search the repo for the old package ID and update any remaining references
(OAuth redirect URIs, deep links, backend allowlists, etc.).

---

## Post-Change Verification Checklist

Run through this after changing the package/bundle ID:

- [ ] Android `android/app/build.gradle` has the new `applicationId` and `namespace`.
- [ ] Android `android/app/src/main/AndroidManifest.xml` does not reference the old package.
- [ ] iOS `ios/Runner.xcworkspace` bundle identifier is updated.
- [ ] Firebase configs are updated for the new IDs:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- [ ] OAuth / social login callback URLs updated (Google, Facebook, etc.).
- [ ] Deep links / app links updated and verified.
- [ ] Backend allowlists (if any) updated to the new IDs.

## 2) App Display Name

### Android

- Update `app_name` in `android/app/src/main/res/values/strings.xml`.

### iOS

- Update `CFBundleDisplayName` in `ios/Runner/Info.plist`.

## 3) App Icon

This project uses `flutter_launcher_icons` (see `pubspec.yaml`).

1. Add a config to `pubspec.yaml` (example):

```yaml
flutter_icons:
  android: true
  ios: true
  image_path: "assets/icons/app_icon.png"
```

2. Run (you run):

```bash
flutter pub run flutter_launcher_icons
```

## 4) Splash Screen

This project uses `flutter_native_splash` (see `pubspec.yaml`).

1. Add a config to `pubspec.yaml` (example):

```yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: assets/icons/splash.png
  android: true
  ios: true
```

2. Run (you run):

```bash
flutter pub run flutter_native_splash:create
```

## Notes

- Changing package/bundle ID after release creates a **new app** in stores.
- Keep icon/splash assets in `assets/icons/` or another consistent folder.
