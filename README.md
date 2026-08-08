# 4chan Monitor — Android app (Flutter)

Companion app for the server-side monitor. Feed with inline images/video, search
over the whole archive, a mode toggle (All vs EE/Emily), and Firebase push so
EE/Emily alerts reach your phone even when the app is closed.

## What you need
- **Flutter SDK** + **Android Studio** (with an Android device or emulator).
- The server API token (set in `/etc/4chan-monitor.env` on the server as
  `MONITOR_API_TOKEN`). You paste this into the app's Settings on first launch.
- A **Firebase project** (only needed for push — the app works without it for
  feed/search/settings).

## 1. Create the project skeleton, then drop these files in
```bash
flutter create fourchan_monitor
cd fourchan_monitor
# then copy this repo's pubspec.yaml and the whole lib/ folder over the generated ones
flutter pub get
```

## 2. Allow the app to reach the server over HTTP  (REQUIRED)
The API is `http://` (not https), and Android 9+ blocks cleartext by default.
In `android/app/src/main/AndroidManifest.xml`, add to the `<application ...>` tag:
```xml
<application
    android:usesCleartextTraffic="true"
    ... >
```
(Or, better long-term: put the API behind HTTPS and skip this. Ask and I'll set
up Caddy on the server.)

## 3. Min SDK
`video_player` + Firebase need a recent min SDK. In `android/app/build.gradle`
(or `build.gradle.kts`), set:
```
minSdkVersion 23   // or: minSdk = 23
```
Set `applicationId` to match the package you register in Firebase, e.g.
`com.chris.fourchanmonitor`.

## 4. Firebase (for push notifications)
1. console.firebase.google.com → your project → **Add app → Android**, using the
   **same** `applicationId` as above.
2. Download **`google-services.json`** → put it in `android/app/`.
3. Add the Google Services Gradle plugin:
   - `android/settings.gradle` (plugins block):
     `id "com.google.gms.google-services" version "4.4.2" apply false`
   - `android/app/build.gradle` (top plugins block):
     `id "com.google.gms.google-services"`
4. That's the app side. The **server** side (sending the push) uses the
   service-account JSON — hand that to me and I'll wire it into the monitor.

Notifications permission (Android 13+) is requested at runtime by the app.

## 5. Run
```bash
flutter run          # on a connected device/emulator
# or build an installable APK:
flutter build apk --release   # -> build/app/outputs/flutter-apk/app-release.apk
```

## First launch
Open **Settings**, confirm the **Server URL** (`http://2.24.129.131:8787`), paste
the **API token**, tap **Save & connect**. The Feed and Search should populate.
The mode switch mirrors the Telegram /all and /quiet.

## Notes
- Feed images/videos load from 4chan's CDN, so media from threads that have since
  404'd won't display (the text + link remain). Persisting media would mean the
  server storing image files — a later add if you want a permanent gallery.
- Push requires steps 4 + the server-side service account. Until then, the app is
  fully usable for feed/search/settings.
