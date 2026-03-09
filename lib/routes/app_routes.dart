import 'package:flutter/material.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/home/active_run_screen.dart';
import '../screens/home/run_summary_screen.dart';
import '../screens/home/territory_explorer_screen.dart';
import '../screens/home/challenges_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../utils/constants.dart';

class AppRoutes {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppConstants.routeOnboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        );

      case AppConstants.routeLogin:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      case AppConstants.routeSignup:
        return MaterialPageRoute(
          builder: (_) => const SignupScreen(),
        );

      case AppConstants.routeForgotPassword:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
        );

      case AppConstants.routeDashboard:
        return MaterialPageRoute(
          builder: (_) => const DashboardScreen(),
        );

      case AppConstants.routeActiveRun:
        return MaterialPageRoute(
          builder: (_) => const ActiveRunScreen(),
        );

      case AppConstants.routeRunSummary:
        {
          final Map<String, dynamic> runArgs =
              (settings.arguments as Map<String, dynamic>?) ?? {};
          return MaterialPageRoute(
            builder: (_) => RunSummaryScreen(runData: runArgs),
          );
        }

      case AppConstants.routeTerritoryExplorer:
        return MaterialPageRoute(
          builder: (_) => const TerritoryExplorerScreen(),
        );

      case AppConstants.routeChallenges:
        return MaterialPageRoute(
          builder: (_) => const ChallengesScreen(),
        );

      case AppConstants.routeSettings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
