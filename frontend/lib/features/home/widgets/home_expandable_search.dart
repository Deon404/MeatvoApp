import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../constants/home_strings.dart';
import '../../../design_system/theme/meatvo_theme_extensions.dart';
import '../../../models/product_variant_model.dart';
import '../../../screens/product/product_detail_screen.dart';
import '../../../services/product_service.dart';
import '../../../ui/atoms/safe_icon_tap.dart';
import '../../../ui/organisms/meatvo_product_card.dart';
import '../../../ui/organisms/product_card_adapter.dart';

/// Hero + AnimatedContainer inline search — full screen navigation ki jagah.
class HomeExpandableSearch extends StatefulWidget {
  const HomeExpandableSearch({super.key});

  static const heroTag = 'home-search-bar'; // matches HomeHeader.searchHeroTag

  @override
  State<HomeExpandableSearch> createState() => _HomeExpandableSearchState();
}

class _HomeExpandableSearchState extends State<HomeExpandableSearch> {
  final ProductService _productService = ProductService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _expanded = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<ProductWithVariants> _results = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _focusNode.requestFocus();
      } else {
        _focusNode.unfocus();
        _controller.clear();
        _results = [];
        _errorMessage = null;
        _isLoading = false;
      }
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await _productService.searchProducts(query);
      if (!mounted || _controller.text.trim() != query) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Search failed. Please try again.';
        _results = [];
      });
    }
  }

  void _openProduct(ProductWithVariants product) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.product.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final horizontal = mv.spacing.md;
    final hasQuery = _controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            mv.spacing.sm,
            horizontal,
            mv.spacing.xs,
          ),
          child: Hero(
            tag: HomeExpandableSearch.heroTag,
            child: Material(
              color: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: mv.surfaceCard,
                  borderRadius: BorderRadius.circular(mv.radii.pill),
                  border: Border.all(
                    color: _expanded ? mv.brandPrimary : mv.border,
                    width: _expanded ? 1.5 : 1,
                  ),
                  boxShadow: _expanded ? mv.shadowMd : mv.shadowSm,
                ),
                child: _expanded
                    ? Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: mv.spacing.sm,
                          vertical: mv.spacing.xs,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: mv.brandPrimary,
                              size: 22,
                            ),
                            SizedBox(width: mv.spacing.xs),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                autofocus: true,
                                onChanged: _onQueryChanged,
                                style: Theme.of(context).textTheme.bodyMedium,
                                decoration: InputDecoration(
                                  hintText: HomeStrings.searchHint,
                                  isDense: true,
                                  filled: false,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: mv.textMuted),
                                ),
                              ),
                            ),
                            // The previous implementation wrapped IconButton
                            // in a tight SizedBox with explicit constraints.
                            // Even with those constraints, IconButton inserts
                            // a `_RenderInputPadding` (48×48 min tap target)
                            // into the render tree — which throws
                            // "RenderBox was not laid out" when this Row is
                            // mid-animation. We replaced both buttons with
                            // `SafeIconTap` (SizedBox + Material + InkWell)
                            // which has ZERO `_RenderInputPadding` and is
                            // therefore safe inside any tight row.
                            if (hasQuery)
                              SafeIconTap(
                                icon: Icons.close_rounded,
                                color: mv.textMuted,
                                onTap: () {
                                  _controller.clear();
                                  _onQueryChanged('');
                                },
                              ),
                            SafeIconTap(
                              icon: Icons.keyboard_arrow_up_rounded,
                              color: mv.textSecondary,
                              onTap: _toggleExpanded,
                            ),
                          ],
                        ),
                      )
                    : InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _toggleExpanded();
                        },
                        borderRadius: BorderRadius.circular(mv.radii.pill),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: mv.spacing.md,
                            vertical: mv.spacing.sm + 2,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, color: mv.textMuted, size: 22),
                              SizedBox(width: mv.spacing.sm),
                              Expanded(
                                child: Text(
                                  HomeStrings.searchHint,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: mv.textMuted),
                                ),
                              ),
                              Icon(
                                Icons.mic_none_rounded,
                                color: mv.textSecondary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded && hasQuery
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _buildResults(context),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final mv = context.meatvo;

    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
        child: const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    // Smart-cast local — `_errorMessage!` removed. Without the local,
    // Dart cannot promote `_errorMessage` from `String?` to `String`
    // across the `if` boundary because it is a mutable instance field;
    // a sibling setState clearing the error would crash with
    // "Null check operator used on a null value" mid-frame.
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Padding(
        padding: EdgeInsets.all(mv.spacing.md),
        child: Text(
          errorMessage,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mv.textSecondary,
              ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(mv.spacing.md),
        child: Text(
          'No products found',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mv.textMuted,
              ),
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = ProductCardAdapter.carouselWidth(screenWidth);
    final listHeight = ProductCardAdapter.carouselHeight(screenWidth) * 0.92;

    return SizedBox(
      height: listHeight + mv.spacing.sm,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: mv.spacing.md),
        itemCount: _results.length,
        separatorBuilder: (_, __) => SizedBox(width: mv.spacing.sm),
        itemBuilder: (context, index) {
          final product = _results[index];
          final canAdd = ProductCardAdapter.canAdd(product);
          return SizedBox(
            width: cardWidth,
            height: listHeight,
            child: MeatvoProductCard(
              product: product.product.copyWith(
                unit: ProductCardAdapter.displayUnit(product),
              ),
              displayPrice: ProductCardAdapter.displayPrice(product),
              displayUnit: ProductCardAdapter.displayUnit(product),
              originalPrice: ProductCardAdapter.originalPrice(product),
              discountPercent: product.product.discount,
              inStock: canAdd,
              layout: MeatvoProductCardLayout.carousel,
              onTap: () => _openProduct(product),
              onAdd: canAdd ? () => _openProduct(product) : null,
            ),
          );
        },
      ),
    );
  }
}
