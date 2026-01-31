import 'package:flutter/material.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/dashboard_screen.dart';
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
