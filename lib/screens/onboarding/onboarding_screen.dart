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
  // v5 uses CarouselSliderController (no conflict with Flutter Material)
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  int _currentIndex = 0;

  final List<_OnboardingSlide> _slides = [
    const _OnboardingSlide(
      icon: Icons.directions_run,
      title: 'Track Your Runs',
      description: 'Record your running routes with GPS precision',
    ),
    const _OnboardingSlide(
      icon: Icons.map,
      title: 'Claim Your Territory',
      description:
          'Every run marks the area as yours. The more you run, the more you own!',
    ),
    const _OnboardingSlide(
      icon: Icons.emoji_events,
      title: 'Compete for Territory',
      description:
          'Challenge others for territory dominance. Better pace and distance wins!',
    ),
    const _OnboardingSlide(
      icon: Icons.leaderboard,
      title: 'Climb the Ranks',
      description:
          'Compete locally and globally. Become the champion of your city!',
    ),
    const _OnboardingSlide(
      icon: Icons.flag,
      title: 'Ready to Run?',
      description: "Let's get started and mark your first territory!",
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
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _nextSlide() {
    if (_currentIndex < _slides.length - 1) {
      _carouselController.nextPage(
        duration: const Duration(milliseconds: 400),
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
              // Skip Button row
              SizedBox(
                height: 56,
                child: _currentIndex < _slides.length - 1
                    ? Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
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
                    : const SizedBox.shrink(),
              ),

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
                    return _SlideWidget(slide: _slides[index]);
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
                    dotColor: Colors.white.withValues(alpha: 0.3),
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 3,
                  ),
                ),
              ),

              // Next / Get Started Button
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
}

/// Each slide is its own StatefulWidget so the entry animation re-triggers.
class _SlideWidget extends StatefulWidget {
  final _OnboardingSlide slide;
  const _SlideWidget({required this.slide});

  @override
  State<_SlideWidget> createState() => __SlideWidgetState();
}

class __SlideWidgetState extends State<_SlideWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                height: 200,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.slide.icon,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              widget.slide.title,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 32,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              widget.slide.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
  });
}
