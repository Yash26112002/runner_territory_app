# Runner Territory App

A Flutter-based running territory app where users can track their runs, claim territories, and compete with others.

## Features

- **Authentication**: Login, Sign up, and Password recovery
- **Onboarding**: Interactive 5-slide carousel introducing app features
- **Map Integration**: Google Maps with territory visualization
- **Territory System**: Claim and compete for territories
- **Stats Tracking**: Monitor your territory, rank, and running streak
- **Social Features**: Leaderboard and social feed (coming soon)

## Prerequisites

Before running this app, ensure you have:

1. **Flutter SDK** installed (version 3.0.0 or higher)
   - Installation guide: https://docs.flutter.dev/get-started/install

2. **Google Maps API Keys**
   - Create a project in Google Cloud Console
   - Enable Google Maps SDK for Android and iOS
   - Generate API keys

## Setup Instructions

### 1. Install Flutter Dependencies

```bash
cd runner_territory_app
flutter pub get
```

### 2. Configure Google Maps API Keys

#### For Android:
Edit `android/app/src/main/AndroidManifest.xml` and add your API key:

```xml
<manifest ...>
  <application ...>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_ANDROID_API_KEY_HERE"/>
  </application>
</manifest>
```

#### For iOS:
Edit `ios/Runner/AppDelegate.swift` and add your API key:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_IOS_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 3. Run the App

```bash
# Check for issues
flutter doctor

# Run on connected device/emulator
flutter run

# Run on specific device
flutter devices
flutter run -d <device_id>
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── routes/
│   └── app_routes.dart      # Navigation routing
├── screens/
│   ├── auth/                # Authentication screens
│   │   ├── login_screen.dart
│   │   ├── signup_screen.dart
│   │   └── forgot_password_screen.dart
│   ├── onboarding/          # Onboarding carousel
│   │   └── onboarding_screen.dart
│   └── home/                # Main app screens
│       └── dashboard_screen.dart
├── widgets/                 # Reusable widgets
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   ├── social_login_button.dart
│   ├── password_strength_indicator.dart
│   ├── stats_widget.dart
│   └── bottom_nav_bar.dart
├── theme/
│   └── app_theme.dart       # App theming
└── utils/
    ├── constants.dart       # App constants
    └── validators.dart      # Form validators
```

## Current Status

### ✅ Completed Features
- Login screen with email/password and social login UI
- Sign-up screen with profile photo upload and validation
- Forgot password screen with success states
- Onboarding carousel with 5 slides
- Dashboard with Google Maps integration
- Territory visualization with polygons
- Stats widget with glassmorphism effect
- Bottom navigation bar
- Location tracking and permissions

### 🚧 Coming Soon
- Backend API integration
- Firebase authentication for social login
- Real-time territory updates
- Running tracking functionality
- Leaderboard
- Social feed
- Profile management

## Notes

- **Mock Data**: The app currently uses mock data for territories and stats
- **Social Login**: Google and Apple login buttons are UI-only; Firebase configuration needed for functionality
- **Territory Data**: Backend integration required for real territory management
- **Fonts**: The app uses Inter font family (not included; will fall back to system font)

## Troubleshooting

### Flutter not found
Install Flutter SDK from https://docs.flutter.dev/get-started/install

### Google Maps not showing
- Verify API keys are correctly configured
- Ensure Google Maps SDK is enabled in Google Cloud Console
- Check that billing is enabled for your Google Cloud project

### Location permission issues
- For iOS: Add location usage descriptions in `Info.plist`
- For Android: Permissions are already configured in `AndroidManifest.xml`

## License

This project is for educational purposes.
