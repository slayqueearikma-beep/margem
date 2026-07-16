# Mobile app setup

## Prerequisites

- Flutter 3.16+
- Android Studio / Xcode
- Google Maps API key with Maps SDK enabled
- Firebase project (for auth + FCM in production)

## Google Maps

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```

### iOS

Add to `ios/Runner/AppDelegate.swift` or `Info.plist`:

```xml
<key>GMSApiKey</key>
<string>YOUR_GOOGLE_MAPS_API_KEY</string>
```

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Use your machine IP instead of `10.0.2.2` on a physical device.

## Firebase (production auth)

1. Create a Firebase project
2. Add Android and iOS apps
3. Download `google-services.json` and `GoogleService-Info.plist`
4. Run `flutterfire configure` to generate `firebase_options.dart`
5. Set `AUTH_DEV_BYPASS=false` on the backend and configure `FIREBASE_CREDENTIALS_PATH`
