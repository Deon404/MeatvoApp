/// Thrown when the signed-in user lacks permission for delivery-partner APIs.
class RoleAccessException implements Exception {
  final String message;
  final String? role;

  RoleAccessException(this.message, {this.role});

  @override
  String toString() => message;
}
