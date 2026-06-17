import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/product_variant_model.dart';
import '../../services/product_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../ui/organisms/meatvo_product_card.dart';
import '../../providers/store_settings_provider.dart';
import '../../ui/organisms/product_card_bindings.dart';
import '../../utils/ordering_gate.dart';
import '../../viewmodels/home_provider.dart';
import '../../widgets/categories/product_grid_item.dart';
import '../product/product_detail_screen.dart';

/// Search Screen - Shows search results for products
class SearchScreen extends ConsumerStatefulWidget {
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ProductService _productService = ProductService();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<ProductWithVariants> _products = [];
  List<String> _recentSearches = [];
  List<String> _searchSuggestions = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  bool _hasSearchText = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    // Local capture removes the three `widget.initialQuery!` bangs.
    // `widget.initialQuery` is technically a getter on State; Dart cannot
    // smart-cast it across the multiple uses below.
    final initialQuery = widget.initialQuery;
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
      _searchQuery = initialQuery;
      _hasSearchText = true;
      _performSearch();
    } else {
      _searchFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getStringList('recent_searches') ?? [];
      if (mounted) {
        setState(() {
          _recentSearches = recent.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getStringList('recent_searches') ?? [];
      
      // Remove if already exists
      recent.remove(query);
      // Add to beginning
      recent.insert(0, query);
      // Keep only last 10
      final updated = recent.take(10).toList();
      
      await prefs.setStringList('recent_searches', updated);
      if (mounted) {
        setState(() {
          _recentSearches = updated.take(5).toList();
        });
      }
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  Future<void> _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recent_searches');
      if (mounted) {
        setState(() {
          _recentSearches = [];
        });
      }
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  Future<void> _loadSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      // Get popular products for suggestions
      final products = await _productService.getFeaturedProducts();
      final suggestions = products
          .where((p) => p.product.name.toLowerCase().contains(query.toLowerCase()))
          .take(5)
          .map((p) => p.product.name)
          .toList();

      if (mounted) {
        setState(() {
          _searchSuggestions = suggestions;
          _showSuggestions = true;
        });
      }
    } catch (e) {
      // Silently fail - suggestions are optional
      debugPrint('Error loading suggestions: $e');
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _products = [];
        _searchQuery = '';
        _errorMessage = null;
        _showSuggestions = false;
      });
      return;
    }

    // Save to recent searches
    await _saveRecentSearch(query);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _searchQuery = query;
      _showSuggestions = false;
    });

    try {
      final products = await _productService.searchProducts(query);
      
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _handleProductTap(ProductWithVariants product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: product.product.id),
      ),
    );
  }

  void _handleSuggestionTap(String suggestion) {
    _searchController.text = suggestion;
    _performSearch();
  }

  void _handleRecentSearchTap(String query) {
    _searchController.text = query;
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          // Local capture — drops the `widget.initialQuery!` bang. If the
          // ancestor rebuilt with a null query mid-frame the previous code
          // crashed with "Null check operator used on a null value".
          autofocus: (widget.initialQuery ?? '').isEmpty,
          style: TextStyle(
            color: Colors.white,
            fontSize: R.fontSize(16, context),
          ),
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(
              color: Colors.white70,
              fontSize: R.fontSize(16, context),
            ),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _performSearch(),
          onChanged: (value) {
            setState(() {
              _hasSearchText = value.isNotEmpty;
            });
            _loadSuggestions(value);
          },
          focusNode: _searchFocusNode,
        ),
        actions: [
          if (_hasSearchText || _searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _products = [];
                  _searchQuery = '';
                  _errorMessage = null;
                  _hasSearchText = false;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _performSearch,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // Show suggestions if search is empty and user is typing
    if (_showSuggestions && _searchController.text.isNotEmpty && _searchQuery.isEmpty) {
      return _buildSuggestionsView();
    }

    // Show recent searches if no search query
    if (_searchQuery.isEmpty && !_isLoading && !_hasSearchText) {
      return _buildRecentSearchesView();
    }

    if (_searchQuery.isEmpty && !_isLoading) {
      return _buildEmptySearchState();
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_products.isEmpty) {
      return _buildNoResultsState();
    }

    return RefreshIndicator(
      onRefresh: _performSearch,
      color: AppColors.primary,
      child: _buildProductGrid(),
    );
  }

  Widget _buildRecentSearchesView() {
    if (_recentSearches.isEmpty) {
      return _buildEmptySearchState();
    }

    return ListView(
      padding: EdgeInsets.all(R.sw(4, context)),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: R.fontSize(16, context),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: _clearRecentSearches,
              child: Text(
                'Clear',
                style: TextStyle(
                  fontSize: R.fontSize(14, context),
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: R.sh(1, context)),
        ..._recentSearches.map((search) => _buildRecentSearchItem(search)),
      ],
    );
  }

  Widget _buildRecentSearchItem(String query) {
    return Card(
      margin: EdgeInsets.only(bottom: R.sh(1, context)),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: ListTile(
        leading: Icon(
          Icons.history,
          color: AppColors.surface,
        ),
        title: Text(
          query,
          style: TextStyle(
            fontSize: R.fontSize(14, context),
            color: AppColors.textPrimary,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.close,
            size: 18,
            color: AppColors.surface,
          ),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            final recent = prefs.getStringList('recent_searches') ?? [];
            recent.remove(query);
            await prefs.setStringList('recent_searches', recent);
            await _loadRecentSearches();
          },
        ),
        onTap: () => _handleRecentSearchTap(query),
      ),
    );
  }

  Widget _buildSuggestionsView() {
    if (_searchSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      padding: EdgeInsets.all(R.sw(4, context)),
      children: [
        Text(
          'Suggestions',
          style: TextStyle(
            fontSize: R.fontSize(16, context),
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: R.sh(1, context)),
        ..._searchSuggestions.map((suggestion) => _buildSuggestionItem(suggestion)),
      ],
    );
  }

  Widget _buildSuggestionItem(String suggestion) {
    return Card(
      margin: EdgeInsets.only(bottom: R.sh(1, context)),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.divider, width: 1),
      ),
      child: ListTile(
        leading: Icon(
          Icons.search,
          color: AppColors.surface,
        ),
        title: Text(
          suggestion,
          style: TextStyle(
            fontSize: R.fontSize(14, context),
            color: AppColors.textPrimary,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.surface,
        ),
        onTap: () => _handleSuggestionTap(suggestion),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.sw(6, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: AppColors.surface,
            ),
            SizedBox(height: R.sh(2, context)),
            Text(
              'Search Products',
              style: TextStyle(
                fontSize: R.fontSize(18, context),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: R.sh(1, context)),
            Text(
              'Enter a product name or description to search',
              style: TextStyle(
                fontSize: R.fontSize(14, context),
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.sw(6, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            SizedBox(height: R.sh(2, context)),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: R.fontSize(18, context),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: R.sh(1, context)),
            Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(
                fontSize: R.fontSize(14, context),
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: R.sh(3, context)),
            ElevatedButton.icon(
              onPressed: _performSearch,
              icon: const Icon(Icons.refresh),
              label: Text(
                'Retry',
                style: TextStyle(fontSize: R.fontSize(14, context)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.sw(6, context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppColors.surface,
            ),
            SizedBox(height: R.sh(2, context)),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: R.fontSize(18, context),
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: R.sh(1, context)),
            Text(
              'No products found for "$_searchQuery"',
              style: TextStyle(
                fontSize: R.fontSize(14, context),
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: R.sh(1, context)),
            Text(
              'Try searching with different keywords',
              style: TextStyle(
                fontSize: R.fontSize(14, context),
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    final homeState = ref.watch(homeViewModelProvider);
    final storeStatus = ref.watch(storeSettingsSyncProvider);
    final cart = homeState.cart;
    final busyProductIds = homeState.busyProductIds;
    final changeQty = ref.read(homeViewModelProvider.notifier).changeCartQuantity;
    final cardHeight =
        MeatvoProductCard.gridCardHeight(MediaQuery.sizeOf(context).width);

    return GridView.builder(
      padding: EdgeInsets.all(R.sw(4, context)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: R.sw(4, context),
        mainAxisSpacing: R.sw(4, context),
        mainAxisExtent: cardHeight,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final productId = product.product.id;
        final qty = cart.findItemByProductId(productId)?.quantity.round() ?? 0;
        final busy = busyProductIds.contains(productId);
        final bindings = ProductCardBindings.forProduct(
          storeStatus: storeStatus,
          product: product,
          cart: cart,
          onQuantityChange: (p, next) async {
            await OrderingGate.guardQuantityChange(
              context,
              ref,
              currentQuantity: qty,
              nextQuantity: next,
              action: () => changeQty(p, next),
            );
          },
        );

        return ProductGridItem(
          product: product,
          quantity: qty,
          isBusy: busy,
          orderingPaused: bindings.orderingPaused,
          onTap: () => _handleProductTap(product),
          onAdd: bindings.onAdd,
          onIncrement: bindings.onIncrement,
          onDecrement: bindings.onDecrement,
        );
      },
    );
  }
}

