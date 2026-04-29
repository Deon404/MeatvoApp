import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/address_model.dart';
import '../services/checkout_service.dart';

final selectedAddressProvider = StateProvider<AddressModel?>((ref) => null);
final couponCodeProvider = StateProvider<String>((ref) => '');
final couponDiscountProvider = StateProvider<double>((ref) => 0);
final paymentMethodProvider = StateProvider<String>((ref) => 'COD');

final addressesProvider = FutureProvider<List<AddressModel>>((ref) async {
  return ref.read(checkoutServiceProvider).getAddresses();
});
