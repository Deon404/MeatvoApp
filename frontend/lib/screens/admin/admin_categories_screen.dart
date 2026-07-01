import 'package:flutter/material.dart';
import '../../config/backend_resolver.dart';
import '../../services/admin_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/admin/admin_image_picker_field.dart';
import '../../widgets/admin/admin_navigation_drawer.dart';
import '../../widgets/common/error_state.dart';
class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _adminService = AdminService();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final rows = await _adminService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = rows;
        _isLoading = false;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = BackendResolver.toUserMessage(
          e,
          fallback: 'Could not load categories.',
        );
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

  Future<void> _openForm({Map<String, dynamic>? category}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category?['name']?.toString() ?? '');
    String? imageUrl = category?['imageUrl']?.toString();
    if (imageUrl != null && imageUrl.isEmpty) imageUrl = null;
    var isActive = category?['isActive'] != false;
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
                        category == null ? 'Add Category' : 'Edit Category',
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
                      AdminImagePickerField(
                        imageUrl: imageUrl,
                        label: 'Category Image',
                        onChanged: (url) => setModalState(() => imageUrl = url),
                      ),
                      const SizedBox(height: 12),                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (v) => setModalState(() => isActive = v),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(ctx);
                          try {
                            if (category == null) {
                              await _adminService.createCategory(
                                name: nameController.text.trim(),
                                imageUrl: imageUrl,
                                isActive: isActive,
                              );
                              _toast('Category added');
                            } else {
                              await _adminService.updateCategory(
                                category['id'] as String,
                                name: nameController.text.trim(),
                                imageUrl: imageUrl ?? '',
                                isActive: isActive,
                              );                              _toast('Category updated');
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
                        child: Text(category == null ? 'Create' : 'Save'),
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

  Widget _previewPlaceholder() {
    return Container(
      color: AppColors.divider,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, size: 48, color: AppColors.surface),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Delete "${category['name']}"? Active products block deletion.'),
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
      await _adminService.deleteCategory(category['id'] as String);
      _toast('Category deleted');
      await _load();
    } catch (e) {
      _toast(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: AdminNavigationDrawer(
        currentSection: AdminNavSection.categories,
        onLogout: () => AdminNavigationDrawer.confirmLogout(context),
      ),
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(),
            tooltip: 'Add category',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? ErrorStateWidget(
                  title: 'Categories unavailable',
                  message: _loadError,
                  onRetry: _load,
                )
              : RefreshIndicator(
              onRefresh: _load,
              child: _categories.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: R.sh(6, context)),
                        const Center(child: Text('No categories yet')),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final c = _categories[index];
                        final imageUrl = c['imageUrl'] as String? ?? '';
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openForm(category: c),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _previewPlaceholder(),
                                        )
                                      : _previewPlaceholder(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          c['name']?.toString() ?? '',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Icon(
                                        c['isActive'] == true
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        size: 18,
                                        color: c['isActive'] == true
                                            ? AppColors.success
                                            : AppColors.primary,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20),
                                        onPressed: () => _confirmDelete(c),
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
    );
  }
}
