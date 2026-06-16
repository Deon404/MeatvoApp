import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_theme.dart';
import '../../utils/app_transitions.dart';
import '../../utils/responsive_helper.dart';
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

  late final List<OnboardingPage> _pages = [
    OnboardingPage(
      eyebrow: 'Freshly cut. Expertly packed.',
      title: 'Farm Fresh Meat Delivered',
      subtitle:
          'Premium chicken, mutton, fish, and eggs sourced fresh every morning and delivered with cold-chain care.',
      imageUrl:
          'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=1600&q=80',
      gradientColors: const [
        Color(0xFFE53935),
        Color(0xFFB71C1C),
        Color(0x80000000),
      ],
      highlights: const [
        PageHighlight(icon: Icons.restaurant_menu_rounded, label: 'Fresh cuts'),
        PageHighlight(icon: Icons.eco_rounded, label: 'Farm sourced'),
        PageHighlight(icon: Icons.thermostat_rounded, label: 'Cold packed'),
      ],
      stats: const [
        PageStat(value: '30+ min', label: 'Express slots'),
        PageStat(value: 'Top rated', label: 'Trusted quality'),
      ],
    ),
    OnboardingPage(
      eyebrow: 'Fastest delivery promise',
      title: 'Lightning Fast Delivery',
      subtitle:
          'Track your order live and get kitchen-ready cuts to your doorstep in under 30 minutes across your nearby zone.',
      imageUrl:
          'https://images.unsplash.com/photo-1519003722824-194d4455a60c?auto=format&fit=crop&w=1600&q=80',
      gradientColors: const [
        Color(0xFFFF5252),
        Color(0xFFC62828),
        Color(0x70000000),
      ],
      highlights: const [
        PageHighlight(icon: Icons.bolt_rounded, label: 'Quick dispatch'),
        PageHighlight(icon: Icons.delivery_dining_rounded, label: 'Live tracking'),
        PageHighlight(icon: Icons.schedule_rounded, label: 'ETA updates'),
      ],
      stats: const [
        PageStat(value: '10k+', label: 'Orders delivered'),
        PageStat(value: 'Live', label: 'Rider tracking'),
      ],
    ),
    OnboardingPage(
      eyebrow: 'More value in every cart',
      title: 'Unbeatable Prices',
      subtitle:
          'Enjoy launch deals, combo packs, and transparent everyday pricing without compromising on freshness.',
      imageUrl:
          'https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&w=1600&q=80',
      gradientColors: const [
        Color(0xFFD32F2F),
        Color(0xFF8E0000),
        Color(0x70000000),
      ],
      highlights: const [
        PageHighlight(icon: Icons.local_offer_rounded, label: 'Daily offers'),
        PageHighlight(icon: Icons.inventory_2_rounded, label: 'Combo packs'),
        PageHighlight(icon: Icons.currency_rupee_rounded, label: 'Best value'),
      ],
      stats: const [
        PageStat(value: 'Up to 25%', label: 'Launch savings'),
        PageStat(value: 'No hidden', label: 'Transparent pricing'),
      ],
    ),
    OnboardingPage(
      eyebrow: 'Hygiene you can trust',
      title: '100% Hygienic & Safe',
      subtitle:
          'Handled in sanitized conditions, inspected before dispatch, and packed securely so every delivery feels reliable.',
      imageUrl:
          'https://images.unsplash.com/photo-1582719478250-c89cae4dc85b?auto=format&fit=crop&w=1600&q=80',
      gradientColors: const [
        Color(0xFFEF5350),
        Color(0xFFAD1457),
        Color(0x70000000),
      ],
      highlights: const [
        PageHighlight(icon: Icons.verified_user_rounded, label: 'Quality checks'),
        PageHighlight(icon: Icons.health_and_safety_rounded, label: 'Sanitized handling'),
        PageHighlight(icon: Icons.workspace_premium_rounded, label: 'Safe packaging'),
      ],
      stats: const [
        PageStat(value: 'QC passed', label: 'Inspected daily'),
        PageStat(value: 'Sealed', label: 'Tamper-safe bags'),
      ],
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
    final theme = Theme.of(context);
    final page = _pages[_currentPage];
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) => _OnboardingBackground(
              controller: _pageController,
              page: _pages[index],
              index: index,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isTablet = constraints.maxWidth >= 640;
                  final isDesktop = constraints.maxWidth >= 960;
                  final isCompactHeight = constraints.maxHeight < 720;
                  final useStackedFooter =
                      isCompactHeight || constraints.maxWidth < 380;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _BrandBadge(isDark: isDark),
                          const Spacer(),
                          TextButton(
                            onPressed: _skipOnboarding,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.12),
                              minimumSize: Size(
                                R.sw(18, context),
                                math.max(44.0, R.sh(5.5, context)),
                              ),
                            ),
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: R.fontSize(14, context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompactHeight ? 12 : 24),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.only(bottom: isCompactHeight ? 12 : 0),
                          child: Align(
                            alignment: isDesktop
                                ? Alignment.centerLeft
                                : isTablet
                                    ? Alignment.bottomLeft
                                    : Alignment.bottomCenter,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 420),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final offset = Tween<Offset>(
                                  begin: const Offset(0, 0.08),
                                  end: Offset.zero,
                                ).animate(animation);
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(position: offset, child: child),
                                );
                              },
                              child: _OnboardingContentCard(
                                key: ValueKey(page.title),
                                page: page,
                                isDesktop: isDesktop,
                                compact: isCompactHeight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: isCompactHeight ? 8 : 16),
                      if (useStackedFooter)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _pages.length,
                                (index) => _PageIndicator(
                                  isActive: index == _currentPage,
                                  color: _pages[index].gradientColors.first,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            PremiumButton(
                              label: _currentPage == _pages.length - 1
                                  ? 'Get Started'
                                  : 'Next',
                              icon: _currentPage == _pages.length - 1
                                  ? Icons.login_rounded
                                  : Icons.arrow_forward_rounded,
                              onPressed: _nextPage,
                              expanded: true,
                              height: 56,
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: List.generate(
                                  _pages.length,
                                  (index) => _PageIndicator(
                                    isActive: index == _currentPage,
                                    color: _pages[index].gradientColors.first,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: isDesktop ? 280 : 210,
                              child: PremiumButton(
                                label: _currentPage == _pages.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                icon: _currentPage == _pages.length - 1
                                    ? Icons.login_rounded
                                    : Icons.arrow_forward_rounded,
                                onPressed: _nextPage,
                                expanded: true,
                                height: 56,
                              ),
                            ),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingBackground extends StatelessWidget {
  const _OnboardingBackground({
    required this.controller,
    required this.page,
    required this.index,
  });

  final PageController controller;
  final OnboardingPage page;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double offset = 0;
        if (controller.hasClients && controller.position.hasContentDimensions) {
          final currentPage = controller.page ?? controller.initialPage.toDouble();
          offset = currentPage - index;
        }

        final parallax = (offset * -36).clamp(-48.0, 48.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(parallax, 0),
              child: OverflowBox(
                minWidth: 0,
                maxWidth: MediaQuery.of(context).size.width + 96,
                alignment: Alignment.center,
                child: CachedNetworkImage(
                  imageUrl: page.imageUrl,
                  fit: BoxFit.cover,
                  width: MediaQuery.of(context).size.width + 96,
                  placeholder: (context, url) => _BackgroundPlaceholder(
                    accentColor: page.gradientColors.first,
                  ),
                  errorWidget: (context, url, error) => _BackgroundFallback(
                    accentColor: page.gradientColors.first,
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: page.gradientColors,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OnboardingContentCard extends StatelessWidget {
  const _OnboardingContentCard({
    super.key,
    required this.page,
    required this.isDesktop,
    required this.compact,
  });

  final OnboardingPage page;
  final bool isDesktop;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxWidth = isDesktop ? 540.0 : 680.0;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: EdgeInsets.all(compact ? 20 : (isDesktop ? 28 : 24)),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 40,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.radiusPill),
              ),
              child: Text(
                page.eyebrow,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            SizedBox(height: compact ? 14 : 20),
            Text(
              page.title,
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontSize: R.fontSize(
                  compact ? 28 : (isDesktop ? 40 : 32),
                  context,
                ),
                height: 1.1,
              ),
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              page.subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.55,
              ),
            ),
            SizedBox(height: compact ? 16 : 24),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: page.highlights
                  .map((highlight) => _HighlightPill(highlight: highlight))
                  .toList(),
            ),
            SizedBox(height: compact ? 14 : 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: page.stats
                  .map(
                    (stat) => _StatCard(
                      stat: stat,
                      accentColor: page.gradientColors.first,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(AppRadius.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/logo.png',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.shopping_bag_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'MEATVO',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightPill extends StatelessWidget {
  const _HighlightPill({required this.highlight});

  final PageHighlight highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(highlight.icon, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            highlight.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.stat,
    required this.accentColor,
  });

  final PageStat stat;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.radiusLg),
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.isActive,
    required this.color,
  });

  final bool isActive;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(right: 8),
      width: isActive ? 34 : 10,
      height: 10,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _BackgroundPlaceholder extends StatelessWidget {
  const _BackgroundPlaceholder({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: accentColor.withValues(alpha: 0.28),
      highlightColor: accentColor.withValues(alpha: 0.14),
      child: Container(
        color: accentColor.withValues(alpha: 0.24),
      ),
    );
  }
}

class _BackgroundFallback extends StatelessWidget {
  const _BackgroundFallback({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.86),
            const Color(0xFF350505),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.photo_camera_back_rounded,
          color: Colors.white70,
          size: 36,
        ),
      ),
    );
  }
}

class OnboardingPage {
  const OnboardingPage({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.gradientColors,
    required this.highlights,
    required this.stats,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String imageUrl;
  final List<Color> gradientColors;
  final List<PageHighlight> highlights;
  final List<PageStat> stats;
}

class PageHighlight {
  const PageHighlight({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}

class PageStat {
  const PageStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

