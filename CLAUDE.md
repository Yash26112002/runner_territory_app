# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run the app
flutter run
flutter run -d <device_id>   # target a specific device
flutter devices              # list available devices

# Analyze / lint
flutter analyze

# Run tests
flutter test
flutter test test/widget_test.dart  # single test file

# Build
flutter build apk            # Android release APK
flutter build ios            # iOS release (requires Mac + Xcode)
```

## Architecture

This is a **Flutter + Firebase** gamified running app. Users run outdoors, GPS routes create territory polygons on a shared Google Map, and runners can overtake each other's territory.

### State Management
- **Provider** is the sole state management solution — only `AuthNotifier` (`lib/providers/auth_notifier.dart`) is registered as a global provider.
- `AuthNotifier` (ChangeNotifier) is the single source of truth for auth state, wrapping `AuthService` and persisting the user token to `SharedPreferences`.

### Navigation
- Named routes only, configured in `lib/routes/app_routes.dart` via `AppRoutes.generateRoute()`.
- All route name strings are constants in `lib/utils/constants.dart` (`AppConstants.route*`).
- Initial route is determined at startup in `main.dart` based on `SharedPreferences`: onboarding → login → dashboard.

### Service Layer (`lib/services/`)
Services are plain Dart classes (no Flutter dependencies) that handle all external integrations:

| Service | Responsibility |
|---|---|
| `auth_service.dart` | Thin wrapper around `FirebaseAuth` |
| `database_service.dart` | All Firestore reads/writes (collections: `users`, `territories`, `runs`, `feed`) |
| `run_tracking_service.dart` | GPS position streaming via Geolocator; exposes `routeStream`, `distanceStream`, `serviceStatusStream`, `accuracyStream` |
| `territory_logic_service.dart` | Core game logic: builds bounding-box polygon from GPS route, detects AABB overlaps with existing territories, claims or overtakes in Firestore |
| `sound_service.dart` | Singleton audioplayers wrapper for `whistle.mp3` / `cheer.mp3` in `assets/sounds/` |

### Key Data Flow
```
ActiveRunScreen
  └─ RunTrackingService (GPS stream)
       └─ On stop: TerritoryLogicService.generateTerritoryFromRun()
                     └─ DatabaseService.claimTerritory() / overWriteTerritoryOwner()
                           └─ RunSummaryScreen (confetti if territory claimed)
```

### Data Models (`lib/models/app_models.dart`)
Four models with `fromMap()` / `toMap()` for Firestore serialization:
- `UserProfile` — uid, name, photo, totalDistance, territoriesOwned, streak
- `Territory` — id, ownerId, ownerName, areaSqKm, polygonPoints (LatLng list), createdAt
- `RunHistory` — id, userId, distanceKm, timeSeconds, date
- `FeedPost` — id, userId, userName, actionText, likes, comments, timestamp

### Dashboard Structure
`DashboardScreen` uses an `IndexedStack` to host 5 persistent tabs (avoids rebuilds):
- Tab 0: Google Map with live-streamed territory polygons (orange = yours, blue = others)
- Tab 1: `TerritoriesScreen` — user's owned territories with fl_chart bar charts
- Tab 2: `LeaderboardScreen` — Firestore stream ordered by `totalDistance`
- Tab 3: `SocialScreen` — Firestore stream of latest 50 `FeedPost`s
- Tab 4: `ProfileScreen`

### Theme & Constants
- All colors, gradients, and `TextTheme` defined in `lib/theme/app_theme.dart`. Primary color is `#FF6B35` (orange). Inter font family.
- All magic strings/numbers (route names, SharedPreferences keys, map zoom, padding values, territory color palette) are in `lib/utils/constants.dart` under `AppConstants`.

## Firebase Setup
- Android: `android/app/google-services.json` (already present)
- iOS: requires `GoogleService-Info.plist` in `ios/Runner/`
- Google Maps API key: set in `android/app/src/main/AndroidManifest.xml` (Android) and `ios/Runner/AppDelegate.swift` (iOS)

## Missing Assets
`assets/sounds/` expects `whistle.mp3` and `cheer.mp3` — `SoundService` will fail silently without them.
