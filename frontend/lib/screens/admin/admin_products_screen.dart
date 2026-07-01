import 'package:flutter/material.dart';
import '../../config/backend_resolver.dart';
import '../../services/admin_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/admin/admin_image_picker_field.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';
import '../../widgets/common/error_state.dart';
/// Admin products — full CRUD against `/api/admin/products`.
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _adminService = AdminService();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _categories = [];
  final Map<String, TextEditingController> _stockControllers = {};
  bool _isLoading = true;
  String? _loadError;
  String? _busyProductId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _stockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _categoryName(String categoryId) {
    if (categoryId.isEmpty) return 'Uncategorized';
    final match = _categories.where((c) => c['id'] == categoryId);
    return match.isEmpty ? categoryId : (match.first['name']?.toString() ?? categoryId);
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final categories = await _adminService.getCategories();
      final products = await _adminService.getAdminProductsNormalized();
      for (final c in _stockControllers.values) {
        c.dispose();
      }
      _stockControllers.clear();
      for (final p in products) {
        final id = p['id'] as String;
        _stockControllers[id] = TextEditingController(
          text: '${p['stockQty'] ?? 0}',
        );
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _products = products;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = BackendResolver.toUserMessage(
          e,
          fallback: 'Could not load products.',
        );
        _products = [];
        _categories = [];
      });
    }
  }

  void _toast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.primary : AppColors.success,
      ),
    );
  }

  Future<void> _saveStock(String productId) async {
    final controller = _stockControllers[productId];
    if (controller == null) return;
    final stock = int.tryParse(controller.text.trim());
    if (stock == null || stock < 0) {
      _toast('Invalid stock', isError: true);
      return;
    }
    setState(() => _busyProductId = productId);
    try {
      await _adminService.updateProductStock(productId, stock);
      _toast('Stock updated');
      final idx = _products.indexWhere((p) => p['id'] == productId);
      if (idx >= 0) {
        setState(() {
          _products[idx] = {
            ..._products[idx],
            'stockQty': stock,
            'inStock': stock > 0,
          };
        });
      }
    } catch (e) {
      _toast(e.toString(), isError: true);
      await _load();
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> product, bool value) async {
    final id = product['id'] as String;
    setState(() => _busyProductId = id);
    try {
      await _adminService.setProductAvailability(id, value);
      _toast(value ? 'Product activated' : 'Product deactivated');
      setState(() {
        final idx = _products.indexWhere((p) => p['id'] == id);
        if (idx >= 0) _products[idx] = {..._products[idx], 'isActive': value};
      });
    } catch (e) {
      _toast(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busyProductId = null);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: Text('Remove "${product['name']}" from catalog? (soft delete)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _adminService.deleteProduct(product['id'] as String);
      _toast('Product removed');
      await _load();
    } catch (e) {
      _toast(e.toString(), isError: true);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? product}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?['name']?.toString() ?? '');
    final salePriceController = TextEditingController(
      text: product != null ? '${product['salePrice'] ?? product['price']}' : '',
    );
    final mrpController = TextEditingController(
      text: product?['mrp']?.toString() ?? '',
    );
    final stockController = TextEditingController(
      text: product != null ? '${product['stockQty'] ?? 0}' : '',
    );
    final unitController = TextEditingController(text: product?['unit']?.toString() ?? 'kg');
    final descController = TextEditingController(text: product?['description']?.toString() ?? '');
    String? imageUrl = product?['imageUrl']?.toString();
    if (imageUrl != null && imageUrl.isEmpty) imageUrl = null;
    String? categoryId = product?['categoryId']?.toString();
    if (categoryId != null && categoryId.isEmpty) categoryId = null;
    var isActive = product?['isActive'] != false;

    int? previewDiscount(double sale, double? mrp) {
      if (mrp == null || mrp <= sale + 0.01) return null;
      return ((1 - sale / mrp) * 100).round().clamp(1, 99);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: modalSheetInsets(context),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        product == null ? 'Add Product' : 'Edit Product',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Name required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: categoryId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Uncategorized'),
                          ),
                          ..._categories.map(
                            (c) => DropdownMenuItem<String?>(
                              value: c['id'] as String,
                              child: Text(c['name']?.toString() ?? ''),
                            ),
                          ),
                        ],
                        onChanged: (v) => setModalState(() => categoryId = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: salePriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Selling Price',
                          helperText: 'Customer pays this amount',
                          prefixText: '₹ ',
                        ),
                        onChanged: (_) => setModalState(() {}),
                        validator: (v) {
                          final p = double.tryParse(v?.trim() ?? '');
                          if (p == null || p <= 0) return 'Valid selling price required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: mrpController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'MRP (optional)',
                          helperText: 'Higher than selling price to show % OFF badge',
                          prefixText: '₹ ',
                        ),
                        onChanged: (_) => setModalState(() {}),
                        validator: (v) {
                          final raw = v?.trim() ?? '';
                          if (raw.isEmpty) return null;
                          final mrp = double.tryParse(raw);
                          final sale = double.tryParse(salePriceController.text.trim());
                          if (mrp == null || mrp <= 0) return 'Enter valid MRP';
                          if (sale != null && mrp <= sale) {
                            return 'MRP must be higher than selling price';
                          }
                          return null;
                        },
                      ),
                      Builder(
                        builder: (context) {
                          final sale = double.tryParse(salePriceController.text.trim());
                          final mrp = double.tryParse(mrpController.text.trim());
                          final discount = sale != null ? previewDiscount(sale, mrp) : null;
                          if (discount == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Customer app will show $discount% OFF badge',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stock'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: unitController,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      ),
                      const SizedBox(height: 12),
                      AdminImagePickerField(
                        imageUrl: imageUrl,
                        label: 'Product Image',
                        aspectRatio: 1,
                        onChanged: (url) => setModalState(() => imageUrl = url),
                      ),
                      const SizedBox(height: 12),                      TextFormField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 2,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (v) => setModalState(() => isActive = v),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(ctx);
                          final salePrice = double.parse(salePriceController.text.trim());
                          final mrpRaw = mrpController.text.trim();
                          final mrp = mrpRaw.isEmpty ? null : double.parse(mrpRaw);
                          final stock = int.tryParse(stockController.text.trim());
                          try {
                            if (product == null) {
                              await _adminService.createProduct(
                                name: nameController.text.trim(),
                                price: salePrice,
                                mrp: mrp,
                                categoryId: categoryId,
                                stockQty: stock,
                                unit: unitController.text.trim(),
                                description: descController.text.trim(),
                                imageUrl: imageUrl,
                                isActive: isActive,
                              );
                              _toast('Product added');
                            } else {
                              await _adminService.updateProduct(
                                product['id'] as String,
                                name: nameController.text.trim(),
                                price: salePrice,
                                mrp: mrp,
                                clearMrp: mrpRaw.isEmpty,
                                categoryId: categoryId ?? '',
                                stockQty: stock,
                                unit: unitController.text.trim(),
                                description: descController.text.trim(),
                                imageUrl: imageUrl,
                                isActive: isActive,
                              );
                              _toast('Product updated');
                            }
                            await _load();
                          } catch (e) {
                            _toast(e.toString(), isError: true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(product == null ? 'Create' : 'Save'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.products,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Products'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(),
            tooltip: 'Add product',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? ErrorStateWidget(
                    title: 'Products unavailable',
                    message: _loadError,
                    onRetry: _load,
                  )
                : RefreshIndicator(
              onRefresh: _load,
              child: _products.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: R.sh(5, context)),
                        const Center(child: Text('No products')),
                      ],
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            AppColors.divider.withValues(alpha: 0.4),
                          ),
                          columns: const [
                            DataColumn(label: Text('Image')),
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Sale')),
                            DataColumn(label: Text('MRP')),
                            DataColumn(label: Text('% OFF')),
                            DataColumn(label: Text('Stock')),
                            DataColumn(label: Text('Active')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: _products.map((p) {
                            final id = p['id'] as String;
                            final imageUrl = p['imageUrl'] as String? ?? '';
                            final busy = _busyProductId == id;
                            return DataRow(
                              cells: [
                                DataCell(
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(Icons.broken_image),
                                            )
                                          : const ColoredBox(
                                              color: AppColors.divider,
                                              child: Icon(Icons.inventory_2),
                                            ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      p['name']?.toString() ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(_categoryName(p['categoryId']?.toString() ?? ''))),
                                DataCell(Text('₹${p['salePrice'] ?? p['price']}')),
                                DataCell(Text(
                                  p['mrp'] != null ? '₹${p['mrp']}' : '—',
                                )),
                                DataCell(Text(
                                  p['discountPercent'] != null
                                      ? '${p['discountPercent']}%'
                                      : '—',
                                  style: TextStyle(
                                    color: p['discountPercent'] != null
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontWeight: p['discountPercent'] != null
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                )),
                                DataCell(
                                  SizedBox(
                                    width: 88,
                                    child: TextField(
                                      controller: _stockControllers[id],
                                      keyboardType: TextInputType.number,
                                      enabled: !busy,
                                      decoration: const InputDecoration(
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      onSubmitted: (_) => _saveStock(id),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  busy
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Switch(
                                          value: p['isActive'] == true,
                                          onChanged: (v) => _toggleActive(p, v),
                                        ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        onPressed: () => _openForm(product: p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            size: 20, color: AppColors.primary),
                                        onPressed: () => _confirmDelete(p),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
      ),
      floatingActionButton: _products.isNotEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _openForm(),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            ),
    );
  }
}
