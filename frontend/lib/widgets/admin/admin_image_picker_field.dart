import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/admin_service.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/media_url_resolver.dart';
import '../../utils/responsive_helper.dart';

/// Admin form field — pick an image from gallery/camera, upload to server, receive URL.
class AdminImagePickerField extends StatefulWidget {
  const AdminImagePickerField({
    super.key,
    required this.imageUrl,
    required this.onChanged,
    this.aspectRatio = 16 / 9,
    this.required = false,
    this.label = 'Product Image',
  });

  final String? imageUrl;
  final ValueChanged<String?> onChanged;
  final double aspectRatio;
  final bool required;
  final String label;

  @override
  State<AdminImagePickerField> createState() => _AdminImagePickerFieldState();
}

class _AdminImagePickerFieldState extends State<AdminImagePickerField> {
  final _adminService = AdminService();
  final _picker = ImagePicker();

  String? _localPreviewPath;
  bool _isUploading = false;
  String? _error;

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() {
      _error = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _localPreviewPath = picked.path;
        _isUploading = true;
      });

      final url = await _adminService.uploadImage(picked.path);
      if (!mounted) return;

      setState(() {
        _isUploading = false;
        _localPreviewPath = null;
      });
      widget.onChanged(url);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _showSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: sheetBottomPadding(ctx)),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUpload(ImageSource.camera);
              },
            ),
            if ((widget.imageUrl ?? '').isNotEmpty || _localPreviewPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.primary),
                title: const Text('Remove image'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _localPreviewPath = null;
                    _error = null;
                  });
                  widget.onChanged(null);
                },
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_localPreviewPath != null) {
      return Image.file(
        File(_localPreviewPath!),
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }

    final url = MediaUrlResolver.resolve(widget.imageUrl?.trim()) ?? '';
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(icon: Icons.broken_image),
      );
    }

    return _placeholder();
  }

  Widget _placeholder({IconData icon = Icons.image_outlined}) {
    return Container(
      color: AppColors.divider,
      alignment: Alignment.center,
      child: Icon(icon, size: 48, color: AppColors.surface),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage =
        _localPreviewPath != null || (widget.imageUrl?.trim().isNotEmpty == true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.required ? '${widget.label} *' : widget.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildPreview(),
                if (_isUploading)
                  Container(
                    color: Colors.black38,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 8),
                        Text(
                          'Uploading...',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _isUploading ? null : _showSourceSheet,
          icon: Icon(hasImage ? Icons.swap_horiz : Icons.upload_outlined),
          label: Text(hasImage ? 'Change image' : 'Upload image'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.primary, fontSize: 12),
          ),
        ],
        if (widget.required && !hasImage && !_isUploading) ...[
          const SizedBox(height: 4),
          const Text(
            'Image upload is required',
            style: TextStyle(color: AppColors.primary, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
