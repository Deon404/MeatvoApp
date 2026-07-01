import 'package:flutter_test/flutter_test.dart';

import '../../lib/services/admin_service.dart';

void main() {
  group('AdminService order helpers', () {
    late AdminService adminService;

    setUp(() {
      adminService = AdminService();
    });

    test('isTerminalOrderStatus is true for delivered, cancelled, refunded', () {
      expect(
        adminService.isTerminalOrderStatus({'status': 'DELIVERED'}),
        isTrue,
      );
      expect(
        adminService.isTerminalOrderStatus({'status': 'cancelled'}),
        isTrue,
      );
      expect(
        adminService.isTerminalOrderStatus({'status': 'REFUNDED'}),
        isTrue,
      );
      expect(
        adminService.isTerminalOrderStatus({'status': 'PACKED'}),
        isFalse,
      );
    });

    test('canAssignRiderToOrder blocks terminal and awaiting-payment orders', () {
      expect(
        adminService.canAssignRiderToOrder({'status': 'CANCELLED'}),
        isFalse,
      );
      expect(
        adminService.canAssignRiderToOrder({
          'status': 'PLACED',
          'payment_mode': 'ONLINE',
          'payment_status': 'PENDING',
        }),
        isFalse,
      );
      expect(
        adminService.canAssignRiderToOrder({'status': 'PACKED'}),
        isTrue,
      );
    });

    test('orderMatchesAdminStatusFilter handles assigned and on-way filters', () {
      final assignedOrder = {
        'status': 'PACKED',
        'delivery_uid': '42',
      };
      expect(
        adminService.orderMatchesAdminStatusFilter(
          assignedOrder,
          'RIDER_ASSIGNED',
        ),
        isTrue,
      );

      final onWayOrder = {'status': 'OUT_FOR_DELIVERY'};
      expect(
        adminService.orderMatchesAdminStatusFilter(onWayOrder, 'OUT_FOR_DELIVERY'),
        isTrue,
      );

      final packedOnly = {'status': 'PACKED'};
      expect(
        adminService.orderMatchesAdminStatusFilter(packedOnly, 'RIDER_ASSIGNED'),
        isFalse,
      );
    });
  });
}
