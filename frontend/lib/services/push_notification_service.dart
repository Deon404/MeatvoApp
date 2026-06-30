import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../app_navigator_key.dart';
import '../config/env_config.dart';
import '../firebase_options.dart';
import '../screens/orders/order_detail_screen.dart';
import 'api_client.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// Background message handler (must be top-level function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvConfig.load();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background message: ${message.messageId}');

  final notification = message.notification;
  if (notification != null) {
    final notificationType = message.data['type']?.toString() ?? 'system';
    await NotificationService().saveNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification.title ?? 'Meatvo',
      body: notification.body ?? '',
      type: notificationType,
      orderId: message.data['order_id']?.toString(),
    );
  }
}

/// Push Notification Service with full FCM integration
class PushNotificationService {
  static PushNotificationService? _instance;
  factory PushNotificationService() =>
      _instance ??= PushNotificationService._();
  PushNotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  bool _isInitialized = false;
  bool _tokenListenerAttached = false;

  /// Must be called from [main] before [runApp] (Firebase requirement).
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  static const _orderUpdatesChannel = AndroidNotificationChannel(
    'order_updates',
    'Order Updates',
    description: 'Notifications for order status updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  static const _promoChannel = AndroidNotificationChannel(
    'promotions',
    'Promotions',
    description: 'Special offers and promotions',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  /// Initialize push notifications with FCM
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('✅ Push notifications already initialized');
      return;
    }

    try {
      // 1. Request notification permissions
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        debugPrint('⚠️ Notification permissions denied');
        return;
      }

      // 2. Initialize local notifications
      await _initializeLocalNotifications();

      // 3. Ensure FCM auto-init is on (helps MIUI / delayed Play Services).
      await _fcm.setAutoInitEnabled(true);

      // 4. Get FCM token and send to backend (retries SERVICE_NOT_AVAILABLE).
      await _registerFCMToken();

      // 5. Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 6. Handle notification taps (when app is in background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 7. Check if app was opened from a terminated state notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      _isInitialized = true;
      debugPrint('✅ FCM push notification handlers ready');
      if (_fcmToken != null) {
        debugPrint('🔑 FCM token registered');
      } else {
        debugPrint('⚠️ FCM token pending — will retry on login or refresh');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing push notifications: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Request notification permissions (iOS + Android 13+)
  Future<bool> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
      announcement: false,
    );

    debugPrint('📱 Notification permission status: ${settings.authorizationStatus}');
    
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
           settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          _handleLocalNotificationTap(response.payload!);
        }
      },
    );

    // Create Android notification channels
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_orderUpdatesChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_promoChannel);
    }
  }

  /// Upload the current FCM token to the backend (requires auth).
  /// Safe to call after login or on cold start with an existing session.
  Future<void> syncTokenWithBackend() async {
    try {
      if (!_isInitialized) {
        // Attempt lightweight init — permissions may still be denied.
        await initialize();
      }
      _fcmToken ??= await _getTokenWithRetry(maxAttempts: 3);
      _attachTokenRefreshListener();
      if (_fcmToken == null) {
        debugPrint('⚠️ No FCM token available to sync');
        return;
      }
      await _sendTokenToBackend(_fcmToken!);
    } catch (e) {
      debugPrint('❌ Error syncing FCM token: $e');
    }
  }

  /// Fetch FCM token with retries — SERVICE_NOT_AVAILABLE is common on MIUI
  /// when Google Play Services is not ready at cold start.
  Future<String?> _getTokenWithRetry({int maxAttempts = 5}) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final token = await _fcm.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (e) {
        lastError = e;
        final msg = e.toString();
        final retryable = msg.contains('SERVICE_NOT_AVAILABLE') ||
            msg.contains('IOException') ||
            msg.contains('unknown');
        if (!retryable || attempt == maxAttempts) {
          rethrow;
        }
        final delay = Duration(seconds: attempt * 2);
        debugPrint(
          '⏳ FCM token unavailable (attempt $attempt/$maxAttempts) — '
          'retrying in ${delay.inSeconds}s',
        );
        await Future.delayed(delay);
      }
    }
    if (lastError != null) throw lastError;
    return null;
  }

  void _attachTokenRefreshListener() {
    if (_tokenListenerAttached) return;
    _tokenListenerAttached = true;
    _fcm.onTokenRefresh.listen((newToken) {
      if (kDebugMode) debugPrint('🔄 FCM token refreshed');
      _fcmToken = newToken;
      _sendTokenToBackend(newToken);
    });
  }

  /// Register FCM token and send to backend
  Future<void> _registerFCMToken() async {
    try {
      _fcmToken = await _getTokenWithRetry();

      if (_fcmToken == null) {
        debugPrint('⚠️ Failed to get FCM token');
        return;
      }

      _attachTokenRefreshListener();
      await _sendTokenToBackend(_fcmToken!);
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
    }
  }

  /// Send FCM token to backend
  Future<void> _sendTokenToBackend(String token) async {
    try {
      final storage = StorageService();
      final accessToken = await storage.getAccessToken();
      
      if (accessToken == null || accessToken.isEmpty) {
        if (kDebugMode) {
          debugPrint('⚠️ No access token, skipping FCM token upload');
        }
        return;
      }

      final apiClient = ApiClient(storage);
      final response = await apiClient.dio.post(
        '/users/fcm-token',
        data: {'fcm_token': token},
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token sent to backend successfully');
      }
    } catch (e) {
      debugPrint('❌ Error sending FCM token to backend: $e');
    }
  }

  /// Handle foreground messages - show local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📩 Foreground message received: ${message.messageId}');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    final notification = message.notification;
    if (notification == null) return;

    // Determine channel based on notification type
    final notificationType = message.data['type'] ?? 'promo';
    final channel = notificationType == 'order_status' 
        ? _orderUpdatesChannel 
        : _promoChannel;

    // Save to local notification history
    await NotificationService().saveNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification.title ?? '',
      body: notification.body ?? '',
      type: notificationType,
      orderId: message.data['order_id']?.toString(),
    );

    // Show local notification
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: notificationType == 'order_status' 
              ? Priority.high 
              : Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _buildPayload(message.data),
    );
  }

  /// Handle notification tap when app is in background or terminated
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped: ${message.data}');
    _navigateBasedOnData(message.data);
  }

  /// Handle local notification tap
  void _handleLocalNotificationTap(String payload) {
    debugPrint('🔔 Local notification tapped: $payload');
    
    final parts = payload.split(':');
    if (parts.isEmpty) return;

    final type = parts[0];
    final data = <String, dynamic>{'type': type};
    
    if (parts.length > 1) {
      data['id'] = parts[1];
    }

    _navigateBasedOnData(data);
  }

  /// Navigate to appropriate screen based on notification data
  void _navigateBasedOnData(Map<String, dynamic> data) {
    final nav = appNavigatorKey.currentState;
    if (nav == null) {
      debugPrint('⚠️ Navigator not available');
      return;
    }

    final type = data['type']?.toString();
    
    if (type == 'order_status') {
      final orderId = data['order_id']?.toString() ?? data['id']?.toString();
      if (orderId != null) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: orderId),
          ),
        );
      }
    } else if (type == 'promo') {
      // Navigate to home screen for promotions
      nav.pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  /// Build payload string from data
  String _buildPayload(Map<String, dynamic> data) {
    final type = data['type'] ?? 'promo';
    final id = data['order_id'] ?? data['id'] ?? '';
    return '$type:$id';
  }

  /// Show local order assignment notification
  Future<void> showOrderAssignment({
    required int orderId,
    String? body,
  }) async {
    if (!_isInitialized) return;
    
    await _localNotifications.show(
      orderId,
      'New Order Assigned',
      body ?? 'Order #$orderId is ready for pickup',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _orderUpdatesChannel.id,
          _orderUpdatesChannel.name,
          channelDescription: _orderUpdatesChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: 'order_status:$orderId',
    );
  }

  /// Get current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Whether FCM handlers are active (permissions granted and init completed).
  bool get isConfigured => _isInitialized;

  /// Whether a device token is available for backend push delivery.
  bool get hasToken => _fcmToken != null && _fcmToken!.isNotEmpty;

  /// Refresh FCM token (useful for testing or manual refresh)
  Future<void> refreshToken() async {
    try {
      await _fcm.deleteToken();
      await _registerFCMToken();
    } catch (e) {
      debugPrint('❌ Error refreshing FCM token: $e');
    }
  }

  static const int _ongoingTrackingNotificationId = 9001;

  /// Android ongoing notification for active order tracking.
  Future<void> showOngoingTrackingNotification({
    required String orderId,
    required String statusLabel,
    String? etaLabel,
  }) async {
    if (!Platform.isAndroid) return;
    if (!_isInitialized) {
      try {
        await initialize();
      } catch (_) {
        return;
      }
    }

    final body = etaLabel != null && etaLabel.isNotEmpty
        ? '$statusLabel · $etaLabel'
        : statusLabel;

    await _localNotifications.show(
      _ongoingTrackingNotificationId,
      'Meatvo order update',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _orderUpdatesChannel.id,
          _orderUpdatesChannel.name,
          channelDescription: _orderUpdatesChannel.description,
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          onlyAlertOnce: true,
          showWhen: false,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: 'order_status:$orderId',
    );
  }

  Future<void> dismissOngoingTrackingNotification() async {
    await _localNotifications.cancel(_ongoingTrackingNotificationId);
  }
}

