# Production Release Checklist (Google Play + Android)

Use this checklist before submitting to Play Console. It includes the most common policy and permission items that can trigger rejections or removals.

## Target SDK + Release Format

- [ ] Confirm your `targetSdkVersion` meets Google Play’s current requirement. As of August 31, 2025, new apps and updates must target Android 15 (API 35). Check the official requirement page for any newer dates or levels.
- [ ] Publish with an Android App Bundle (AAB). New apps must use AAB on Google Play.
- [ ] Enroll in Play App Signing (mandatory for new apps).

## Permissions (Manifest + Runtime)

- [ ] Declare only the minimum permissions needed; avoid requesting permissions that aren’t critical to core functionality.
- [ ] Request runtime permissions only at the moment a user triggers the feature, and handle denial gracefully.
- [ ] Verify every dependency/SDK and the permissions it introduces.

## Sensitive / Restricted Permissions (Play Console Declarations)

- [ ] If you request background location, ensure it’s a core, user-expected feature; otherwise remove `ACCESS_BACKGROUND_LOCATION` and related code.
- [ ] If you request broad photo/video access (`READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO`), complete the required Play Console declaration and justify the core use case; otherwise use the system photo picker and remove the permission.
- [ ] If you request `MANAGE_EXTERNAL_STORAGE` (“All files access”), pass the access review and show users how to enable it in system settings.
- [ ] If you use `QUERY_ALL_PACKAGES`, complete the declaration and ensure it’s essential to core functionality.
- [ ] If you use Accessibility APIs, complete the declaration and implement clear in-app disclosure + affirmative consent (unless you are a true accessibility tool with `isAccessibilityTool=true`).

## Data Safety + Privacy Policy

- [ ] Complete the Data safety form for the app (all Play-published apps must do this).
- [ ] Provide a privacy policy URL in Play Console and a privacy policy link or text inside the app. It must be public, non-geofenced, and include required disclosures.
- [ ] Ensure Data safety disclosures match the privacy policy and actual data practices.

## App Access for Review

- [ ] If any part of the app is behind login, provide test credentials and instructions in Play Console -> App content -> App access. Credentials must be reusable and always valid.

## Payments + Ads

- [ ] If you sell digital goods or services in-app, use Google Play Billing unless an exception applies.
- [ ] If you use the Advertising ID, follow the policy rules and disclose usage in your privacy policy.

## Target Audience + Store Listing

- [ ] Accurately set "Target audience and content" in Play Console; don’t misrepresent.
- [ ] Make sure store listing visuals/text match your declared audience and avoid elements that unintentionally target children.
- [ ] If your target audience includes children, comply with Families policy requirements (ads, data practices, permissions).

---

## Keystore Recovery Plan (Android)

Use this section to avoid release-blocking issues if you lose keystore credentials.

- [ ] Follow `docs/runbook/android_signing_guide.md` to generate and configure the upload keystore.
- [ ] Enable Play App Signing in Play Console. This allows you to reset the *upload key* if needed.
- [ ] Store the keystore file (`.jks`) and passwords in a password manager or secure vault.
- [ ] Keep an offline backup copy of the keystore (encrypted).
- [ ] If you lose the keystore or passwords and are **not** using Play App Signing, you will not be able to publish updates to the existing app package name.

### If the upload key is lost (Play App Signing enabled)

1. Go to Play Console -> App -> App Integrity.
2. Request an upload key reset.
3. Generate a new upload key and register it in Play Console.

---

## Keystore Exposure Response Plan (Android)

If you suspect the keystore or key passwords were exposed:

1. Immediately revoke or rotate the **upload key** in Play Console (if Play App Signing is enabled).
2. Rotate credentials in your password manager or vault.
3. Audit CI/CD logs, artifact storage, and developer machines for accidental copies.
4. If the **app signing key** itself was exposed (rare when using Play App Signing), contact Google Play support immediately.

---

## iOS Signing Key Exposure Plan

If you suspect your iOS signing certificates or provisioning profiles were exposed:

1. Revoke the affected certificates in Apple Developer -> Certificates, Identifiers & Profiles.
2. Generate new certificates and provisioning profiles.
3. Update CI/CD secrets and any local keychains that referenced the old certs.
4. Rebuild and re-upload the app with the new signing assets.

---

## iOS Signing Guide

- [ ] Follow `docs/runbook/ios_signing_guide.md` for certificate, profile, and App Store Connect steps.

---

## App Branding Guide

- [ ] Follow `docs/runbook/app_branding_guide.md` to change app name, package/bundle ID, icons, and splash screen.
