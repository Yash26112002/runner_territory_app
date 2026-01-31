import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final CarouselController _carouselController = CarouselController();
  int _currentIndex = 0;

  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      icon: Icons.directions_run,
      title: 'Track Your Runs',
      description: 'Record your running routes with GPS precision',
      color: AppTheme.primaryOrange,
    ),
    OnboardingSlide(
      icon: Icons.map,
      title: 'Claim Your Territory',
      description: 'Every run marks the area as yours. The more you run, the more you own!',
      color: AppTheme.secondaryBlue,
    ),
    OnboardingSlide(
      icon: Icons.emoji_events,
      title: 'Compete for Territory',
      description: 'Challenge others for territory dominance. Better pace and distance wins!',
      color: AppTheme.accentPurple,
    ),
    OnboardingSlide(
      icon: Icons.leaderboard,
      title: 'Climb the Ranks',
      description: 'Compete locally and globally. Become the champion of your city!',
      color: AppTheme.warningYellow,
    ),
    OnboardingSlide(
      icon: Icons.flag,
      title: 'Ready to Run?',
      description: 'Let\'s get started and mark your first territory!',
      color: AppTheme.successGreen,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyOnboardingComplete, true);
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppConstants.routeLogin);
    }
  }

  void _skipToEnd() {
    _carouselController.animateToPage(
      _slides.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextSlide() {
    if (_currentIndex < _slides.length - 1) {
      _carouselController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip Button
              if (_currentIndex < _slides.length - 1)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton(
                      onPressed: _skipToEnd,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 56),
              
              // Carousel
              Expanded(
                child: CarouselSlider.builder(
                  carouselController: _carouselController,
                  itemCount: _slides.length,
                  options: CarouselOptions(
                    height: double.infinity,
                    viewportFraction: 1.0,
                    enableInfiniteScroll: false,
                    onPageChanged: (index, reason) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),
                  itemBuilder: (context, index, realIndex) {
                    return _buildSlide(_slides[index]);
                  },
                ),
              ),
              
              // Page Indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AnimatedSmoothIndicator(
                  activeIndex: _currentIndex,
                  count: _slides.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: Colors.white,
                    dotColor: Colors.white.withOpacity(0.3),
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                  ),
                ),
              ),
              
              // Next/Get Started Button
              Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: CustomButton(
                  text: _currentIndex == _slides.length - 1
                      ? 'Get Started'
                      : 'Next',
                  onPressed: _nextSlide,
                  icon: _currentIndex == _slides.length - 1
                      ? Icons.arrow_forward
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated Icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  height: 200,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    slide.icon,
                    size: 100,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 48),
          
          // Title
          Text(
            slide.title,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontSize: 32,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          // Description
          Text(
            slide.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.9),
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
