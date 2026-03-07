# Runner Territory App — Complete Project Structure

> **What is this app?** A gamified running app where you physically run outdoors to *claim map territories*. Your GPS route creates a polygon on a shared Google Map. Other runners can *overtake* your territory by running through it. It uses Flutter (cross-platform), Firebase (auth + database), and Google Maps.

---

## Full Annotated File Tree

```
runner_territory_app/                         ← Root of the Flutter project
│
├── 📄 pubspec.yaml                           ← The project's "package.json". Declares
│                                               app name, version, all dependencies
│                                               (Firebase, Google Maps, Provider, etc.)
│                                               and registers fonts & asset folders.
│
├── 📄 pubspec.lock                           ← Auto-generated. Locks exact dependency
│                                               versions so every dev gets the same packages.
│
├── 📄 analysis_options.yaml                  ← Dart linter config. Enforces code style
│                                               rules (e.g., avoid unused variables).
│
├── 📄 devtools_options.yaml                  ← Flutter DevTools settings for debugging
│                                               (performance profiling, widget inspector).
│
├── 📄 runner_territory_app.iml               ← IntelliJ/Android Studio project module
│                                               descriptor (IDE-specific, safe to ignore).
│
├── 📄 README.md                              ← Project overview documentation.
│
├── 📄 SETUP_GUIDE.md                         ← Step-by-step guide for setting up the
│                                               project locally (Firebase config, API keys).
│
├── 📄 flutter_01/02/03.png                   ← Screenshots of the app UI (likely used
│                                               in README for visual reference).
│
├── 📄 .gitignore                             ← Tells Git which files to ignore
│                                               (build outputs, secrets, IDE files).
│
├── 📄 .flutter-plugins-dependencies          ← Auto-generated map of all native plugin
│                                               dependencies used by Flutter packages.
│
├── 📄 .metadata                              ← Flutter tool metadata about project
│                                               version and migration history.
│
│
├── 📁 lib/                                   ← ★ ALL YOUR DART/FLUTTER CODE LIVES HERE ★
│   │                                           This is the heart of the application.
│   │
│   ├── 📄 main.dart                          ← APP ENTRY POINT. Initialises Firebase,
│   │                                           reads SharedPreferences to decide where
│   │                                           to send the user (Onboarding → Login →
│   │                                           Dashboard), wraps app in Provider, and
│   │                                           applies the global theme.
│   │
│   ├── 📁 models/                            ← Data model classes (plain Dart objects
│   │   │                                       that represent real-world entities).
│   │   └── 📄 app_models.dart                ← Defines 4 core data shapes:
│   │                                           • UserProfile  – uid, name, photo,
│   │                                             totalDistance, territoriesOwned, streak
│   │                                           • Territory    – id, ownerId, ownerName,
│   │                                             areaSqKm, polygonPoints (LatLng list),
│   │                                             createdAt
│   │                                           • RunHistory   – id, userId, distanceKm,
│   │                                             timeSeconds, date
│   │                                           • FeedPost     – id, userId, userName,
│   │                                             actionText, likes, comments, timestamp
│   │                                           Each class has fromMap() (Firestore→object)
│   │                                           and toMap() (object→Firestore) methods.
│   │
│   ├── 📁 providers/                         ← State management using Provider package.
│   │   │                                       Providers hold app-wide state and notify
│   │   │                                       widgets when something changes.
│   │   └── 📄 auth_notifier.dart             ← AuthNotifier (ChangeNotifier). The
│   │                                           single source of truth for auth state.
│   │                                           Exposes: login(), signup(), logout(),
│   │                                           sendPasswordReset(). Manages AuthStatus
│   │                                           enum (idle/loading/success/error) and
│   │                                           persists the user token to SharedPreferences
│   │                                           so the app remembers login between launches.
│   │
│   ├── 📁 routes/                            ← Navigation / routing configuration.
│   │   └── 📄 app_routes.dart                ← Central route registry. Contains
│   │                                           AppRoutes.generateRoute() — a switch
│   │                                           statement that maps route name strings
│   │                                           (e.g., '/dashboard') to their Screen
│   │                                           widgets. This is used by MaterialApp's
│   │                                           onGenerateRoute.
│   │
│   ├── 📁 screens/                           ← All full-page UI screens.
│   │   │
│   │   ├── 📁 onboarding/                    ← First-time user experience flow.
│   │   │   └── 📄 onboarding_screen.dart     ← A multi-page carousel (using
│   │   │                                       carousel_slider) shown only on first
│   │   │                                       launch. Explains the app concept with
│   │   │                                       slides + page indicator dots. On finish,
│   │   │                                       sets 'onboarding_complete' in
│   │   │                                       SharedPreferences and navigates to Login.
│   │   │
│   │   ├── 📁 auth/                          ← Authentication screens.
│   │   │   ├── 📄 login_screen.dart          ← Email + password sign-in form. Uses
│   │   │   │                                   AuthNotifier to call Firebase Auth.
│   │   │   │                                   On success → Dashboard. Has link to
│   │   │   │                                   Signup and ForgotPassword.
│   │   │   │
│   │   │   ├── 📄 signup_screen.dart         ← New user registration form. Collects
│   │   │   │                                   name, username, email, password, optional
│   │   │   │                                   phone. Uses password strength indicator
│   │   │   │                                   widget. On success → creates UserProfile
│   │   │   │                                   in Firestore via DatabaseService.
│   │   │   │
│   │   │   └── 📄 forgot_password_screen.dart← Enter email → sends Firebase password
│   │   │                                       reset email. Shows success confirmation.
│   │   │
│   │   └── 📁 home/                          ← All post-login screens (main app).
│   │       │
│   │       ├── 📄 dashboard_screen.dart      ← ★ MAIN HOME SCREEN. Uses IndexedStack
│   │       │                                   to host 5 tabs without rebuilding them:
│   │       │                                   [0] Map view with all territories as
│   │       │                                       coloured polygons. Orange = yours,
│   │       │                                       Blue = others. Tap polygon → bottom
│   │       │                                       sheet shows territory details.
│   │       │                                   [1] TerritoriesScreen
│   │       │                                   [2] LeaderboardScreen
│   │       │                                   [3] SocialScreen
│   │       │                                   [4] ProfileScreen
│   │       │                                   Floating "Start Run" button (animates/
│   │       │                                   pulses) navigates to ActiveRunScreen.
│   │       │                                   Map controls: center-on-me, satellite/
│   │       │                                   normal toggle. Stats strip at top shows
│   │       │                                   territories owned, rank, streak.
│   │       │
│   │       ├── 📄 active_run_screen.dart     ← ★ CORE FEATURE. Full-screen run tracker.
│   │       │                                   • Dark-styled Google Map with custom
│   │       │                                     JSON map style (night mode).
│   │       │                                   • Live cyan polyline drawn as you run.
│   │       │                                   • Orange polygon preview of territory
│   │       │                                     you'll claim.
│   │       │                                   • Glassmorphism stats card: timer,
│   │       │                                     distance (km), pace (/km), calories,
│   │       │                                     area (km²).
│   │       │                                   • GPS quality indicator (green/yellow/red).
│   │       │                                   • Pause/Resume/Stop controls + audio toggle.
│   │       │                                   • Screen lock feature (long press unlock).
│   │       │                                   • WakelockPlus keeps screen on during run.
│   │       │                                   • Plays whistle sound on start, cheer on
│   │       │                                     each km milestone.
│   │       │                                   On stop → saves RunHistory to Firestore,
│   │       │                                   calls TerritoryLogicService to claim/
│   │       │                                   overtake territory, posts to social feed,
│   │       │                                   then navigates to RunSummaryScreen.
│   │       │
│   │       ├── 📄 run_summary_screen.dart    ← Post-run celebration screen. Shows
│   │       │                                   distance, time, pace, calories, map of
│   │       │                                   the route. If a territory was claimed,
│   │       │                                   fires a confetti animation. Share button
│   │       │                                   lets user share run stats via share_plus.
│   │       │
│   │       ├── 📄 territories_screen.dart    ← Tab 1. Lists all territories the current
│   │       │                                   user owns with fl_chart bar charts showing
│   │       │                                   stats. Filter chips: All/Safe/Contested/
│   │       │                                   At Risk/New. Sort by area or date.
│   │       │                                   Toggle between list and grid view.
│   │       │
│   │       ├── 📄 territory_explorer_screen.dart ← Full-screen map to browse ALL
│   │       │                                   territories globally. Layer filters:
│   │       │                                   All / Mine / Top 100 / Heatmap.
│   │       │                                   Tap any territory polygon to see details.
│   │       │
│   │       ├── 📄 leaderboard_screen.dart    ← Tab 2. Global rankings. Streams
│   │       │                                   UserProfile list from Firestore ordered
│   │       │                                   by totalDistance descending. Shows rank,
│   │       │                                   avatar, name, distance, territories.
│   │       │                                   Uses shimmer loading skeleton while data
│   │       │                                   loads. Current user row is highlighted.
│   │       │
│   │       ├── 📄 social_screen.dart         ← Tab 3. Community activity feed. Streams
│   │       │                                   FeedPost list from Firestore (latest 50).
│   │       │                                   Shows who ran, claimed territories, etc.
│   │       │                                   Uses shimmer loading. Like/comment counts.
│   │       │
│   │       └── 📄 profile_screen.dart        ← Tab 4. Current user's profile. Shows
│   │                                           display name, avatar, total distance,
│   │                                           territories owned, running streak.
│   │                                           Logout button calls AuthNotifier.logout().
│   │
│   ├── 📁 services/                          ← Business logic & external integrations.
│   │   │                                       Services are plain Dart classes (not widgets).
│   │   │
│   │   ├── 📄 auth_service.dart              ← Thin wrapper around FirebaseAuth.
│   │   │                                       Methods: signUpWithEmailPassword(),
│   │   │                                       signInWithEmailPassword(),
│   │   │                                       sendPasswordResetEmail(), signOut().
│   │   │                                       Also exposes currentUser and userChanges
│   │   │                                       stream. AuthNotifier calls this.
│   │   │
│   │   ├── 📄 database_service.dart          ← All Firestore reads/writes in one place.
│   │   │                                       Collections: users, territories, runs, feed.
│   │   │                                       Key methods:
│   │   │                                       • createUserProfile() / getUser() /
│   │   │                                         streamUser() / streamLeaderboard()
│   │   │                                       • claimTerritory() / overWriteTerritoryOwner()
│   │   │                                         / streamGlobalTerritories() /
│   │   │                                         streamUserTerritories()
│   │   │                                       • saveRun() / createFeedPost() / streamFeed()
│   │   │                                       Uses atomic FieldValue.increment() to update
│   │   │                                       territory counts.
│   │   │
│   │   ├── 📄 run_tracking_service.dart      ← GPS tracking engine using Geolocator.
│   │   │                                       Starts a position stream (updates every 3m).
│   │   │                                       Accumulates route points (List<LatLng>).
│   │   │                                       Calculates cumulative distance (metres).
│   │   │                                       Exposes 4 broadcast streams:
│   │   │                                       • routeStream   → full list of GPS points
│   │   │                                       • distanceStream → total metres so far
│   │   │                                       • serviceStatusStream → GPS on/off events
│   │   │                                       • accuracyStream → GPS accuracy in metres
│   │   │                                       Also: pauseRun() / resumeRun() / stopRun().
│   │   │
│   │   ├── 📄 territory_logic_service.dart   ← Core game logic for territory claiming.
│   │   │                                       generateTerritoryFromRun():
│   │   │                                       1. Rejects runs < 5 points or < 0.1 km.
│   │   │                                       2. Builds a bounding box from min/max
│   │   │                                          lat/lng of the route.
│   │   │                                       3. Calculates area using Haversine formula.
│   │   │                                       4. Checks all existing territories for
│   │   │                                          bounding box overlap (AABB collision).
│   │   │                                       5. If overlap → overtake the existing
│   │   │                                          territory (update owner in Firestore).
│   │   │                                       6. If no overlap → create new territory.
│   │   │
│   │   └── 📄 sound_service.dart             ← Singleton audio player using audioplayers.
│   │                                           playStartWhistle() → plays whistle.mp3
│   │                                           playCheer()        → plays cheer.mp3
│   │                                           (Files expected in assets/sounds/).
│   │
│   ├── 📁 theme/                             ← Visual design system.
│   │   └── 📄 app_theme.dart                 ← Centralised theme configuration.
│   │                                           Defines:
│   │                                           • Color constants (primaryOrange #FF6B35,
│   │                                             secondaryBlue, successGreen, errorRed…)
│   │                                           • primaryGradient & backgroundGradient
│   │                                           • lightTheme (ThemeData): AppBar, Input
│   │                                             fields, Buttons, full TextTheme using
│   │                                             the Inter font family, Material3 enabled.
│   │
│   ├── 📁 utils/                             ← Utility classes with no UI.
│   │   ├── 📄 constants.dart                 ← AppConstants class. Single source of truth
│   │   │                                       for all magic strings and numbers:
│   │   │                                       • Route names ('/dashboard', '/login'…)
│   │   │                                       • SharedPreferences keys
│   │   │                                       • Padding/radius/animation duration values
│   │   │                                       • Map settings (defaultMapZoom = 15.0)
│   │   │                                       • Territory color palette (8 colors)
│   │   │
│   │   └── 📄 validators.dart                ← Form validation helper functions.
│   │                                           Used by login/signup forms to validate
│   │                                           email format, password length, etc.
│   │
│   └── 📁 widgets/                           ← Reusable UI components (used across
│       │                                       multiple screens).
│       │
│       ├── 📄 bottom_nav_bar.dart            ← Custom BottomNavigationBar with 5 tabs:
│       │                                       Map, Territories, Leaderboard, Social,
│       │                                       Profile. Used by DashboardScreen.
│       │
│       ├── 📄 custom_button.dart             ← Styled ElevatedButton with gradient
│       │                                       background. Used across auth screens.
│       │
│       ├── 📄 custom_text_field.dart         ← Styled TextField with label, hint, icon,
│       │                                       and error display. Used in auth forms.
│       │
│       ├── 📄 password_strength_indicator.dart ← Visual bar that shows password strength
│       │                                       (Weak/Medium/Strong) as user types.
│       │                                       Used in signup_screen.
│       │
│       ├── 📄 shimmer_loading.dart           ← Skeleton loading placeholder using the
│       │                                       shimmer package. Shows an animated grey
│       │                                       shimmer effect while data is loading from
│       │                                       Firestore (used in Leaderboard, Social).
│       │
│       ├── 📄 social_login_button.dart       ← UI button for social auth providers
│       │                                       (Google, Apple sign-in style buttons).
│       │                                       Note: backend not yet wired up.
│       │
│       └── 📄 stats_widget.dart             ← Small horizontal stats strip shown at
│                                               top of Dashboard map. Displays territories
│                                               owned, current rank, running streak.
│
│
├── 📁 assets/                                ← Static files bundled with the app.
│   ├── 📁 fonts/                             ← Custom font files.
│   │   ├── Inter-Regular.ttf                 ← Weight 400 – body text
│   │   ├── Inter-Medium.ttf                  ← Weight 500
│   │   ├── Inter-SemiBold.ttf                ← Weight 600 – button labels, headings
│   │   └── Inter-Bold.ttf                    ← Weight 700 – large display text
│   │
│   ├── 📁 icons/                             ← Custom SVG/PNG icon files.
│   │   └── .gitkeep                          ← Empty placeholder (no icons added yet).
│   │
│   ├── 📁 images/                            ← Image assets (onboarding illustrations, etc.)
│   │   └── .gitkeep                          ← Empty placeholder (no images added yet).
│   │
│   └── 📁 sounds/                            ← Audio files for SoundService.
│       └── .gitkeep                          ← Placeholder. Expects whistle.mp3 & cheer.mp3
│                                               to be added here.
│
│
├── 📁 android/                               ← Android-specific native project.
│   ├── 📄 build.gradle.kts                   ← Root Gradle build file. Configures
│   │                                           Android Gradle plugin version and
│   │                                           Google Services plugin.
│   ├── 📄 settings.gradle.kts                ← Declares the project name and includes
│   │                                           the :app subproject.
│   ├── 📄 gradle.properties                  ← JVM & AndroidX settings.
│   ├── 📄 gradlew / gradlew.bat              ← Gradle wrapper scripts to build Android.
│   ├── 📄 local.properties                   ← Local machine paths (SDK path).
│   │                                           NOT committed to git (contains secrets).
│   │
│   ├── 📁 gradle/wrapper/                    ← Pins exact Gradle version used.
│   │   └── gradle-wrapper.properties         ← Points to Gradle 8.x distribution URL.
│   │
│   └── 📁 app/                               ← The actual Android app module.
│       ├── 📄 build.gradle.kts               ← App-level Gradle config. Sets:
│       │                                       applicationId, minSdk, targetSdk,
│       │                                       versionCode, applies Google Services
│       │                                       plugin for Firebase.
│       ├── 📄 google-services.json           ← ★ Firebase config for Android.
│       │                                       Contains project ID, API keys, app ID.
│       │                                       Required for Firebase to work on Android.
│       │
│       └── 📁 src/
│           ├── 📁 main/
│           │   ├── 📄 AndroidManifest.xml    ← Declares app permissions (INTERNET,
│           │   │                               ACCESS_FINE_LOCATION, etc.), the app's
│           │   │                               entry activity, and metadata.
│           │   ├── 📁 kotlin/com/runner/territory_app/
│           │   │   └── 📄 MainActivity.kt    ← Android entry point. Extends
│           │   │                               FlutterActivity. Flutter renders inside it.
│           │   ├── 📁 kotlin/com/upskill/runner_territory_app/
│           │   │   └── 📄 MainActivity.kt    ← Duplicate (likely from package rename).
│           │   ├── 📁 java/io/flutter/plugins/
│           │   │   └── GeneratedPluginRegistrant.java ← Auto-generated. Registers all
│           │   │                               Flutter plugins with Android native layer.
│           │   └── 📁 res/                   ← Android resources.
│           │       ├── drawable/             ← Launch screen background (white).
│           │       ├── drawable-v21/         ← Launch screen for Android 5.0+ (supports
│           │       │                           vector drawables and gradients).
│           │       ├── mipmap-hdpi/          ← App launcher icon at 72×72px density.
│           │       ├── mipmap-mdpi/          ← App launcher icon at 48×48px density.
│           │       ├── mipmap-xhdpi/         ← App launcher icon at 96×96px density.
│           │       ├── mipmap-xxhdpi/        ← App launcher icon at 144×144px density.
│           │       ├── mipmap-xxxhdpi/       ← App launcher icon at 192×192px density.
│           │       ├── values/styles.xml     ← Light theme styles for splash screen.
│           │       └── values-night/styles.xml ← Dark theme styles for splash screen.
│           │
│           ├── 📁 debug/AndroidManifest.xml  ← Extra permissions for debug builds
│           │                                   (e.g., allows cleartext HTTP traffic).
│           └── 📁 profile/AndroidManifest.xml← Profile/performance build manifest.
│
│
├── 📁 ios/                                   ← iOS-specific native project.
│   ├── 📁 Flutter/                           ← Flutter iOS engine config.
│   │   ├── AppFrameworkInfo.plist            ← Flutter framework version info.
│   │   ├── Debug.xcconfig / Release.xcconfig ← Build config files for Flutter engine.
│   │   └── Generated.xcconfig                ← Auto-generated Flutter settings.
│   │
│   ├── 📁 Runner/                            ← Main iOS app target.
│   │   ├── 📄 AppDelegate.swift              ← iOS entry point. Initialises Flutter
│   │   │                                       engine and Firebase on iOS.
│   │   ├── 📄 Info.plist                     ← iOS app metadata: bundle ID, version,
│   │   │                                       privacy usage descriptions (location!),
│   │   │                                       background modes for GPS.
│   │   ├── 📁 Assets.xcassets/AppIcon/       ← App icon in all required iOS sizes
│   │   │                                       (20pt to 1024pt @1x/2x/3x).
│   │   ├── 📁 Assets.xcassets/LaunchImage/   ← Launch (splash) screen image.
│   │   └── 📁 Base.lproj/                    ← Storyboard files for launch screen UI.
│   │
│   ├── 📄 Runner.xcodeproj/project.pbxproj   ← Xcode project file. Defines build phases,
│   │                                           file references, and targets.
│   ├── 📄 Runner.xcworkspace/                ← Workspace that combines the Runner Xcode
│   │                                           project with CocoaPods (native plugins).
│   └── 📁 RunnerTests/RunnerTests.swift      ← iOS unit test placeholder.
│
│
├── 📁 web/                                   ← Web platform support files.
│   ├── 📄 index.html                         ← Root HTML page that bootstraps Flutter Web.
│   ├── 📄 manifest.json                      ← PWA manifest (app name, icons, theme color).
│   ├── 📄 favicon.png                        ← Browser tab icon.
│   └── 📁 icons/                             ← PWA icons in 192px and 512px (maskable).
│
│
├── 📁 linux/                                 ← Linux desktop platform support.
│   ├── 📄 CMakeLists.txt                     ← CMake build configuration for Linux app.
│   └── 📁 runner/                            ← Linux native runner code (C++).
│       ├── main.cc                           ← Linux entry point.
│       ├── my_application.cc/.h              ← GTK application window setup.
│       └── CMakeLists.txt                    ← Build rules for the Linux runner.
│
│
├── 📁 macos/                                 ← macOS desktop platform support.
│   ├── 📁 Runner/AppDelegate.swift           ← macOS app delegate, initialises Flutter.
│   ├── 📁 Runner/MainFlutterWindow.swift     ← Creates the macOS window hosting Flutter.
│   ├── 📁 Runner/Configs/                    ← Debug/Release/AppInfo xcconfig files.
│   ├── 📄 Runner.xcodeproj/                  ← macOS Xcode project.
│   └── 📄 Runner.xcworkspace/                ← macOS workspace with CocoaPods.
│
│
├── 📁 windows/                               ← Windows desktop platform support.
│   ├── 📄 CMakeLists.txt                     ← CMake build for Windows app.
│   └── 📁 runner/                            ← Windows native runner (C++/Win32).
│       ├── main.cpp                          ← Windows entry point.
│       ├── flutter_window.cpp/.h             ← Win32 window that hosts Flutter engine.
│       ├── win32_window.cpp/.h               ← Base Win32 window class.
│       ├── utils.cpp/.h                      ← Utility functions (UTF-16 conversion).
│       ├── Runner.rc                          ← Windows resource file (version info).
│       ├── runner.exe.manifest               ← Windows app manifest (DPI awareness, etc.)
│       └── resources/app_icon.ico            ← Windows taskbar/title bar icon.
│
│
├── 📁 test/                                  ← Automated tests.
│   └── 📄 widget_test.dart                   ← Default Flutter widget test placeholder.
│                                               Tests that the root widget renders without
│                                               crashing. (Mostly a starting template.)
│
│
└── 📁 .idea/                                 ← Android Studio / IntelliJ IDE settings.
    ├── libraries/                            ← IDE-resolved library paths (Dart SDK,
    │   ├── Dart_Packages.xml                   Flutter plugins, Kotlin runtime).
    │   ├── Dart_SDK.xml
    │   ├── Flutter_Plugins.xml
    │   └── KotlinJavaRuntime.xml
    ├── 📄 modules.xml                        ← Lists all IDE modules in the project.
    ├── 📄 workspace.xml                      ← Stores IDE layout, open files, tool windows.
    ├── 📄 misc.xml                           ← SDK version settings for the project.
    ├── 📄 vcs.xml                            ← Version control (Git) root mapping.
    └── 📁 runConfigurations/
        └── main_dart.xml                     ← "Run" button config pointing to lib/main.dart
```

---

## How the App Works — End-to-End Flow

```
First Launch
    └─► OnboardingScreen (carousel, 3 slides)
            └─► LoginScreen / SignupScreen
                    └─► Firebase Auth creates/verifies user
                            └─► UserProfile written to Firestore
                                    └─► DashboardScreen (5 tabs)

DashboardScreen Tab 0 (Map)
    ├─► Streams all Territory polygons from Firestore (live, real-time)
    └─► "Start Run" button ──► ActiveRunScreen
            ├─► RunTrackingService streams GPS positions
            ├─► Live polyline + territory preview drawn on dark map
            ├─► Timer, pace, calories, area calculated live
            └─► Stop ──► TerritoryLogicService.generateTerritoryFromRun()
                            ├─► Creates bounding box polygon from route
                            ├─► Checks for overlaps with existing territories
                            ├─► Claims new OR overtakes existing territory in Firestore
                            └─► RunSummaryScreen (confetti if territory claimed!)
```

---

## Key Dependencies Summary

| Package | Purpose |
|---|---|
| `firebase_auth` | User sign-up, login, password reset |
| `cloud_firestore` | Real-time database for users, territories, runs, feed |
| `google_maps_flutter` | Map rendering, polygons, polylines |
| `geolocator` | GPS position streaming during runs |
| `provider` | App-wide state management (AuthNotifier) |
| `shared_preferences` | Persist login token & onboarding flag locally |
| `fl_chart` | Bar charts on the Territories screen |
| `confetti` | Confetti burst on territory claim in RunSummary |
| `audioplayers` | Whistle & cheer sounds during runs |
| `shimmer` | Skeleton loading on Leaderboard & Social |
| `wakelock_plus` | Keeps screen on during active run |
| `share_plus` | Share run stats to other apps |
| `latlong2` | Geo-math utilities |
| `carousel_slider` + `smooth_page_indicator` | Onboarding slides |
