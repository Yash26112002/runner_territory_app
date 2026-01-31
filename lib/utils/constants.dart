import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'Runner Territory';
  static const String appTagline = 'Mark Your Territory. Run Your World.';
  
  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  
  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);
  
  // Validation
  static const int minPasswordLength = 8;
  static const int minAge = 13;
  
  // SharedPreferences Keys
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyUserToken = 'user_token';
  static const String keyUserId = 'user_id';
  
  // Routes
  static const String routeOnboarding = '/onboarding';
  static const String routeLogin = '/login';
  static const String routeSignup = '/signup';
  static const String routeForgotPassword = '/forgot-password';
  static const String routeDashboard = '/dashboard';
  static const String routeProfile = '/profile';
  static const String routeTerritories = '/territories';
  static const String routeLeaderboard = '/leaderboard';
  static const String routeSocial = '/social';
  
  // Map Settings
  static const double defaultMapZoom = 15.0;
  static const double territoryOpacity = 0.5;
  
  // Territory Colors (for different users)
  static const List<Color> territoryColors = [
    Color(0xFF4A90E2), // Blue
    Color(0xFF9B59B6), // Purple
    Color(0xFF2ECC71), // Green
    Color(0xFFF39C12), // Yellow
    Color(0xFFE74C3C), // Red
    Color(0xFF1ABC9C), // Turquoise
    Color(0xFFE67E22), // Orange
    Color(0xFF3498DB), // Light Blue
  ];
}
