import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../providers/orders_provider.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/loading_skeleton.dart';

class OrderTrackingScreen extends ConsumerWidget {
  final int orderId;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveOrder = ref.watch(liveOrderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: Text('Tracking #$orderId')),
      body: liveOrder.when(
        data: (order) {
          const store = LatLng(28.6139, 77.2090);
          final partnerLat = order.assignment?.currentLat ?? store.latitude;
          final partnerLng = order.assignment?.currentLng ?? store.longitude;
          final partner = LatLng(partnerLat, partnerLng);
          final home = LatLng(store.latitude + 0.01, store.longitude + 0.01);

          final eta = _etaFromStatus(order.status);
          return Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: partner, zoom: 13),
                  markers: {
                    const Marker(
                      markerId: MarkerId('store'),
                      position: store,
                      infoWindow: InfoWindow(title: 'Store'),
                    ),
                    Marker(
                      markerId: const MarkerId('partner'),
                      position: partner,
                      infoWindow: const InfoWindow(title: 'Delivery Partner'),
                    ),
                    Marker(
                      markerId: const MarkerId('home'),
                      position: home,
                      infoWindow: const InfoWindow(title: 'Delivery Address'),
                    ),
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${order.status}'),
                    Text('ETA: $eta'),
                    if (order.assignment != null)
                      Text('Partner: ${order.assignment!.partnerName} • ${order.assignment!.partnerPhone}'),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            LoadingSkeleton(height: 280),
            SizedBox(height: 12),
            LoadingSkeleton(height: 16),
            SizedBox(height: 8),
            LoadingSkeleton(height: 16),
          ],
        ),
        error: (err, _) => AppErrorState(
          title: 'Tracking unavailable',
          subtitle: '$err',
          onRetry: () => ref.invalidate(liveOrderProvider(orderId)),
        ),
      ),
    );
  }

  String _etaFromStatus(String status) {
    switch (status) {
      case 'PLACED':
        return '30-35 mins';
      case 'CONFIRMED':
      case 'PACKED':
        return '20-25 mins';
      case 'OUT_FOR_DELIVERY':
        return '8-12 mins';
      case 'DELIVERED':
        return 'Delivered';
      default:
        return 'Updating...';
    }
  }
}
