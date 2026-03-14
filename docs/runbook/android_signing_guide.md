# Android Signing Guide (Upload Key + Play App Signing)

This guide covers generating the upload key, where to store it, and how to configure Gradle.

## 1) Generate the Upload Keystore (you run)

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep the **store password**, **key password**, and **alias** safe.

## 2) Move the Keystore Into the App

Recommended location:

- `android/app/upload-keystore.jks`

## 3) Create `android/key.properties` (do not commit)

Create the file with:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFileupload-keystore.jks
```

## 4) Verify Gradle Uses the Keystore

This repo already loads `android/key.properties` and uses it for the **release** build when present.

## 5) Build the Release (you run)

```bash
flutter build appbundle
```

## 6) Enable Play App Signing

In Play Console:

1. Go to **App Integrity**
2. Enroll in **Play App Signing**
3. Upload your **upload key certificate**

## Notes

- If you lose the keystore or passwords and are **not** using Play App Signing, you cannot update the existing app.
- Never commit `android/key.properties` or your `.jks` file.
