# Focused Android signing + Google OAuth

The previous project signed `release` with the local debug keystore. That is unsafe for Google Sign-In because debug keystores are machine-specific. A release built on another computer can therefore have a different SHA-1/SHA-256 and fail OAuth even though the package name is unchanged.

## Required release setup

1. Create/choose one stable upload/release keystore and keep it private.
2. Copy `key.properties.example` to `key.properties` and point it to that keystore.
3. Run `./gradlew signingReport` (or `gradlew.bat signingReport` on Windows).
4. Add the release SHA-1 and SHA-256 to Firebase Console → Project settings → Android app `com.example.focused`.
5. Add each development machine's DEBUG SHA-1/SHA-256 too if debug builds need Google Sign-In.
6. Download a fresh `google-services.json` after changing Firebase Android/OAuth configuration and replace `android/app/google-services.json`.

The currently bundled `google-services.json` contains one Android OAuth certificate SHA-1:

`CE:EE:4E:0D:BD:B1:CA:5A:62:9F:22:20:18:B8:36:98:77:7E:3F:4F`

It also contains a Web OAuth client (`client_type: 3`), which the Google Sign-In plugin can use as the server client configuration.

## Important

A phone is not identified by a SHA fingerprint. The SHA identifies the APK signing certificate. The same correctly signed APK can be installed and authenticated on many Android devices.
