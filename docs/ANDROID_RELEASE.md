# Android release signing

Application ID: **`nz.churchcorner.toylibrary`**. Do not change it after testers or Play users
have installed the app: Android treats a new ID as a different app.

Every APK/AAB shared with testers must be signed with the **release (upload) key** below,
never with debug keys. A signature change forces every tester to uninstall and reinstall.

## 1. Create the key (once)

PowerShell (needs Java / Android Studio's `keytool`):

```powershell
mkdir $env:USERPROFILE\keys
keytool -genkey -v -keystore $env:USERPROFILE\keys\toy-library-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Back up `toy-library-upload.jks` **and its password** outside this computer (password manager +
cloud/USB). Without them the app can never be updated. Never commit the file.

## 2. Point the build at the key

Copy `mobile/android/key.properties.example` to `mobile/android/key.properties` (git-ignored)
and fill in the passwords and the path to the `.jks` (use forward slashes on Windows).

## 3. Firebase (push notifications)

The package name changed, so Firebase needs a matching Android app:

1. Firebase console → Project settings → **Add app → Android** → package name
   `nz.churchcorner.toylibrary`.
2. Download the new `google-services.json` into `mobile/android/app/` (replace the old one).

Without this the build fails (`No matching client found for package name`).

## 4. Build

Bump the number after `+` in `mobile/pubspec.yaml` `version:` for every build you share.

```powershell
cd mobile
flutter clean
flutter build apk --release --split-per-abi --dart-define-from-file=env/production.json
```

Share `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (~35 MB).

Verify the signature (should show your own name, **not** `CN=Android Debug`):

```powershell
keytool -printcert -jarfile build\app\outputs\flutter-apk\app-arm64-v8a-release.apk
```

## Moving pilot users to Google Play later

Build an AAB (`flutter build appbundle ...`). On first upload enable **Play App Signing** and
choose to **use your existing key** (upload this same key as the app signing key). Pilot
installs then update from Play without reinstalling.

## Note for existing pilot installs

Builds made before this change used `com.example.toy_library_mobile` + debug keys. Anyone who
installed those must uninstall the old app once; the new one appears as a separate app.
