# iOS Signing Guide (Certificates, Profiles, App Store Connect)

This guide covers signing setup and the steps needed before an App Store release.

## 1) Apple Developer Setup (you do in Apple Developer Portal)

- [ ] Enroll in the Apple Developer Program.
- [ ] Create an **App ID** (bundle identifier).
- [ ] Create **Distribution** certificates.
- [ ] Create **App Store** provisioning profiles for the app.

## 2) Configure Xcode Project (you do)

- [ ] Open `ios/Runner.xcworkspace` in Xcode.
- [ ] Set the **Bundle Identifier** to match your App ID.
- [ ] Enable **Automatically manage signing** or select the correct profiles.
- [ ] Choose the correct **Team**.

## 3) Firebase (if used)

- [ ] Add `ios/Runner/GoogleService-Info.plist` from Firebase Console.
- [ ] Ensure it is **not committed** to the repo.

## 4) Build the Release (you run)

```bash
flutter build ipa
```

## 5) Upload to App Store Connect (you do)

- [ ] Use Xcode Archive or Transporter to upload.
- [ ] Complete App Store Connect metadata and submit for review.

## Notes

- If you revoke a distribution certificate, you must generate a new one and re-sign.
- Keep certificates and profiles stored securely.
