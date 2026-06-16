import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/admin/admin_image_picker_field.dart';
class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> {
  final _adminService = AdminService();
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;
  bool _isSavingOrder = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _adminService.getBanners();
      if (!mounted) return;
      setState(() {
        _banners = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _toast(e.toString(), isError: true);
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

  Future<void> _openForm({Map<String, dynamic>? banner}) async {
    final formKey = GlobalKey<FormState>();
    String? imageUrl = banner?['imageUrl']?.toString();
    if (imageUrl != null && imageUrl.isEmpty) imageUrl = null;
    final titleController = TextEditingController(text: banner?['title']?.toString() ?? '');    final subtitleController = TextEditingController(text: banner?['subtitle']?.toString() ?? '');
    var isActive = banner?['isActive'] != false;
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
                        banner == null ? 'Add Banner' : 'Edit Banner',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      AdminImagePickerField(
                        imageUrl: imageUrl,
                        label: 'Banner Image',
                        aspectRatio: 16 / 7,
                        required: true,
                        onChanged: (url) => setModalState(() => imageUrl = url),
                      ),
                      const SizedBox(height: 12),                      TextFormField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title (optional)'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: subtitleController,
                        decoration: const InputDecoration(labelText: 'Subtitle (optional)'),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (v) => setModalState(() => isActive = v),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (imageUrl == null || imageUrl!.trim().isEmpty) {
                            setModalState(() {});
                            return;
                          }
                          if (!formKey.currentState!.validate()) return;
                          Navigator.pop(ctx);
                          try {
                            final uploadedUrl = imageUrl!.trim();
                            if (banner == null) {
                              await _adminService.createBanner(
                                imageUrl: uploadedUrl,                                title: titleController.text.trim(),
                                subtitle: subtitleController.text.trim(),
                                isActive: isActive,
                                sortOrder: _banners.length,
                              );
                              _toast('Banner added');
                            } else {
                              await _adminService.updateBanner(
                                banner['id'] as String,
                                imageUrl: uploadedUrl,                                title: titleController.text.trim(),
                                subtitle: subtitleController.text.trim(),
                                isActive: isActive,
                              );
                              _toast('Banner updated');
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
                        child: Text(banner == null ? 'Create' : 'Save'),
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

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.divider,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.surface),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> banner) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Banner?'),
        content: const Text('This cannot be undone.'),
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
      await _adminService.deleteBanner(banner['id'] as String);
      _toast('Banner deleted');
      await _load();
    } catch (e) {
      _toast(e.toString(), isError: true);
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final updated = List<Map<String, dynamic>>.from(_banners);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    setState(() {
      _banners = updated;
      _isSavingOrder = true;
    });
    try {
      await _adminService.reorderBanners(
        updated.map((b) => b['id'] as String).toList(),
      );
      _toast('Banner order saved');
    } catch (e) {
      _toast(e.toString(), isError: true);
      await _load();
    } finally {
      if (mounted) setState(() => _isSavingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Banners'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          if (_isSavingOrder)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openForm(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _banners.isEmpty
              ? Center(
                  child: TextButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add first banner'),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _banners.length,
                  onReorder: _onReorder,
                  itemBuilder: (context, index) {
                    final b = _banners[index];
                    final imageUrl = b['imageUrl'] as String? ?? '';
                    return Card(
                      key: ValueKey(b['id']),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          if (imageUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Image.network(
                                imageUrl,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => SizedBox(
                                  height: 120,
                                  child: _imagePlaceholder(),
                                ),
                              ),
                            ),
                          ListTile(
                            leading: const Icon(Icons.drag_handle),
                            title: Text(b['title']?.toString().isNotEmpty == true
                                ? b['title'].toString()
                                : 'Banner #${index + 1}'),
                            subtitle: Text(b['subtitle']?.toString() ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: b['isActive'] == true,
                                  onChanged: (v) async {
                                    try {
                                      await _adminService.updateBanner(
                                        b['id'] as String,
                                        isActive: v,
                                      );
                                      setState(() {
                                        _banners[index] = {...b, 'isActive': v};
                                      });
                                    } catch (e) {
                                      _toast(e.toString(), isError: true);
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _openForm(banner: b),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.primary),
                                  onPressed: () => _confirmDelete(b),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
