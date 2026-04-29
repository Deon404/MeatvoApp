class AddressModel {
  final int id;
  final String label;
  final String addressLine;
  final String landmark;
  final double lat;
  final double lng;
  final bool isDefault;

  const AddressModel({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.landmark,
    required this.lat,
    required this.lng,
    required this.isDefault,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: (json['id'] as num).toInt(),
      label: (json['label'] ?? '').toString(),
      addressLine: (json['addressLine'] ?? json['address_line'] ?? '').toString(),
      landmark: (json['landmark'] ?? '').toString(),
      lat: ((json['lat'] ?? 0) as num).toDouble(),
      lng: ((json['lng'] ?? 0) as num).toDouble(),
      isDefault: (json['isDefault'] ?? json['is_default'] ?? false) == true,
    );
  }
}
