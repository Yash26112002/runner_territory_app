import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RunnerTerritoryApp());
}

class RunnerTerritoryApp extends StatelessWidget {
  const RunnerTerritoryApp({super.key});

  Future<String> _getInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool(AppConstants.keyOnboardingComplete) ?? false;
    
    // For first launch, show onboarding
    // After onboarding, show login
    // If user is logged in (has token), show dashboard
    final userToken = prefs.getString(AppConstants.keyUserToken);
    
    if (!onboardingComplete) {
      return AppConstants.routeOnboarding;
    } else if (userToken == null) {
      return AppConstants.routeLogin;
    } else {
      return AppConstants.routeDashboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      onGenerateRoute: AppRoutes.generateRoute,
      home: FutureBuilder<String>(
        future: _getInitialRoute(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.backgroundGradient,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            );
          }
          
          // Navigate to the appropriate initial route
          final initialRoute = snapshot.data ?? AppConstants.routeOnboarding;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(context, initialRoute);
          });
          
          return Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}
