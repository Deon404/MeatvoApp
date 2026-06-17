import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../utils/app_transitions.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/onboarding/clay_container.dart';
import '../../widgets/premium/premium_button.dart';
import '../auth/phone_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Farm Fresh Meat',
      subtitle: 'Handpicked cuts, packed with care.',
      icon: Icons.eco_rounded,
    ),
    OnboardingPageData(
      title: '30-Minute Delivery',
      subtitle: 'Fresh orders at your doorstep, fast.',
      icon: Icons.delivery_dining_rounded,
    ),
    OnboardingPageData(
      title: 'Order in 3 Taps',
      subtitle: 'Browse, add to cart, and checkout.',
      icon: Icons.touch_app_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_currentPage != index) {
      setState(() => _currentPage = index);
    }
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    _completeOnboarding();
  }

  void _skipOnboarding() {
    HapticFeedback.lightImpact();
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      AppTransitions.fade(const PhoneScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final mv = context.meatvo;
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MeatvoColors.surfaceWarm,
              MeatvoColors.surfaceMuted,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              mv.spacing.lg,
              mv.spacing.md,
              mv.spacing.lg,
              mv.spacing.lg,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxHeight < 720;
                final iconSize = isCompact ? 96.0 : 120.0;
                final iconGlyphSize = isCompact ? 44.0 : 52.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _BrandBadge(mv: mv, theme: theme),
                        const Spacer(),
                        TextButton(
                          onPressed: _skipOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: mv.textSecondary,
                            backgroundColor: MeatvoColors.surfaceCard,
                            minimumSize: const Size(64, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(mv.radii.pill),
                            ),
                          ),
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? mv.spacing.md : mv.spacing.xl),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          return SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight -
                                    (isCompact ? 180 : 220),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClayIconWell(
                                    icon: page.icon,
                                    size: iconSize,
                                    iconSize: iconGlyphSize,
                                  ),
                                  SizedBox(height: isCompact ? 24 : 36),
                                  ClayContainer(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: mv.spacing.lg,
                                      vertical: isCompact
                                          ? mv.spacing.lg
                                          : mv.spacing.xl,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          page.title,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                            color: mv.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: R.fontSize(
                                              isCompact ? 22 : 26,
                                              context,
                                            ),
                                            height: 1.2,
                                          ),
                                        ),
                                        SizedBox(height: mv.spacing.sm),
                                        Text(
                                          page.subtitle,
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                            color: mv.textSecondary,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: mv.spacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => ClayPageDot(isActive: index == _currentPage),
                      ),
                    ),
                    SizedBox(height: mv.spacing.lg),
                    PremiumButton(
                      label: isLastPage ? 'Get Started' : 'Next',
                      icon: isLastPage
                          ? Icons.login_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _nextPage,
                      expanded: true,
                      height: 56,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({
    required this.mv,
    required this.theme,
  });

  final MeatvoThemeData mv;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderRadius: mv.radii.pill,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/logo.png',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.shopping_bag_rounded,
              color: mv.brandPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'MEATVO',
            style: theme.textTheme.labelLarge?.copyWith(
              color: mv.brandPrimary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageData {
  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
