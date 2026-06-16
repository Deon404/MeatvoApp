import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class HomeHeroOfferConfig {
  final String label;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String categoryName;
  final String assetPath;
  final Color backgroundColor;
  final Color accentColor;

  const HomeHeroOfferConfig({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.categoryName,
    required this.assetPath,
    required this.backgroundColor,
    required this.accentColor,
  });
}

class HomeCategoryVisual {
  final String name;
  final String subtitle;
  final String assetPath;
  final Color accentColor;
  final Color backgroundColor;

  const HomeCategoryVisual({
    required this.name,
    required this.subtitle,
    required this.assetPath,
    required this.accentColor,
    required this.backgroundColor,
  });
}

const HomeHeroOfferConfig homeHeroOffer = HomeHeroOfferConfig(
  label: 'LIMITED OFFER',
  title: 'Fresh cuts\ndelivered fast',
  subtitle: 'Premium quality meats packed fresh every day',
  ctaLabel: 'Shop Chicken',
  categoryName: 'Chicken',
  assetPath: 'assets/images/home/hero_fresh_cuts.png',
  backgroundColor: Color(0xFFFFF0EC),
  accentColor: AppColors.primary,
);

const List<HomeCategoryVisual> homeCategoryVisuals = [
  HomeCategoryVisual(
    name: 'Chicken',
    subtitle: 'Fresh cuts',
    assetPath: 'assets/images/categories/chicken.png',
    accentColor: AppColors.primary,
    backgroundColor: Color(0xFFFFF4EB),
  ),
  HomeCategoryVisual(
    name: 'Eggs',
    subtitle: 'Daily picks',
    assetPath: 'assets/images/categories/eggs.png',
    accentColor: Color(0xFFC68821),
    backgroundColor: Color(0xFFFFF9DD),
  ),
  HomeCategoryVisual(
    name: 'Fish',
    subtitle: 'Ocean fresh',
    assetPath: 'assets/images/categories/fish.png',
    accentColor: AppColors.info,
    backgroundColor: Color(0xFFEAF5FF),
  ),
  HomeCategoryVisual(
    name: 'Mutton',
    subtitle: 'Premium cuts',
    assetPath: 'assets/images/categories/mutton.png',
    accentColor: Color(0xFF9B6B2E),
    backgroundColor: Color(0xFFFFF3F7),
  ),
];
