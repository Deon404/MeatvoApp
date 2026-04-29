import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/checkout_provider.dart';
import '../../services/checkout_service.dart';

class AddressScreen extends ConsumerStatefulWidget {
  const AddressScreen({super.key});

  @override
  ConsumerState<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends ConsumerState<AddressScreen> {
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _addAddress() async {
    final label = _labelController.text.trim();
    final address = _addressController.text.trim();
    if (label.isEmpty || address.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(checkoutServiceProvider).addAddress(
            label: label,
            addressLine: address,
            landmark: _landmarkController.text.trim(),
          );
      ref.invalidate(addressesProvider);
      _labelController.clear();
      _addressController.clear();
      _landmarkController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address added')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final addresses = ref.watch(addressesProvider);
    final selected = ref.watch(selectedAddressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Address')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Saved addresses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          addresses.when(
            data: (list) {
              if (list.isEmpty) return const Text('No saved address yet.');
              return RadioGroup<int>(
                groupValue: selected?.id,
                onChanged: (value) {
                  if (value == null) return;
                  final next = list.firstWhere((a) => a.id == value);
                  ref.read(selectedAddressProvider.notifier).state = next;
                },
                child: Column(
                  children: list
                      .map(
                        (a) => RadioListTile<int>(
                          value: a.id,
                          title: Text(a.label),
                          subtitle: Text('${a.addressLine}${a.landmark.isEmpty ? '' : ', ${a.landmark}'}'),
                        ),
                      )
                      .toList(),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Address load error: $err'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use my location integration Day 13 me polish hoga.')),
              );
            },
            icon: const Icon(Icons.my_location),
            label: const Text('Use my location'),
          ),
          const Divider(height: 32),
          const Text('Add new address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: 'Label (Home, Office)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Address line'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _landmarkController,
            decoration: const InputDecoration(labelText: 'Landmark'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _isSaving ? null : _addAddress,
            child: Text(_isSaving ? 'Saving...' : 'Save Address'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: selected == null ? null : () => context.go('/checkout/review'),
            child: const Text('Continue to Review'),
          ),
        ),
      ),
    );
  }
}
