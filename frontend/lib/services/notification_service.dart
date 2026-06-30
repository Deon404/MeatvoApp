import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

/// Notification storage with server sync and local cache fallback.
class NotificationService {
  static const String _storageKey = 'app_notifications';
  static const int _maxNotifications = 50;

  static NotificationService? _instance;
  factory NotificationService() => _instance ??= NotificationService._();
  NotificationService._();

  final ApiService _api = ApiService();
  SharedPreferences? _prefs;
  List<NotificationModel>? _cachedNotifications;

  Future<SharedPreferences> get _storage async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  bool _isServerNotificationId(String id) {
    final numeric = int.tryParse(id);
    return numeric != null && numeric > 0;
  }

  NotificationModel _parseApiNotification(Map<String, dynamic> json) {
    final data = json['data'];
    Map<String, dynamic>? parsedData;
    if (data is Map) {
      parsedData = Map<String, dynamic>.from(data);
      parsedData['order_id'] ??= parsedData['orderId'];
    }
    return NotificationModel.fromJson({
      ...json,
      if (parsedData != null) 'data': parsedData,
    });
  }

  /// Save a notification to local storage (FCM foreground / offline).
  Future<void> saveNotification({
    required String id,
    required String title,
    required String body,
    required String type,
    String? orderId,
  }) async {
    try {
      final notification = NotificationModel(
        id: id,
        userId: '',
        title: title,
        body: body,
        type: type,
        data: orderId != null ? {'order_id': orderId} : null,
        isRead: false,
        createdAt: DateTime.now(),
      );

      final history = await _getLocalHistory();
      history.removeWhere((n) => n.id == id);
      history.insert(0, notification);

      if (history.length > _maxNotifications) {
        history.removeRange(_maxNotifications, history.length);
      }

      await _saveToStorage(history);
      _cachedNotifications = history;

      debugPrint('Notification saved locally: $title');
    } catch (e) {
      debugPrint('Error saving notification: $e');
    }
  }

  /// Fetch from API, merge with local-only items, cache result.
  Future<List<NotificationModel>> getHistory() async {
    try {
      return await _syncFromServer();
    } catch (e) {
      debugPrint('Notification API sync failed, using local cache: $e');
      return _getLocalHistory();
    }
  }

  Future<List<NotificationModel>> _syncFromServer() async {
    final response = await _api.get(
      ApiUserPaths.notifications,
      queryParameters: {'limit': _maxNotifications},
    );
    final payload = response.data;
    if (payload is! Map) {
      throw const FormatException('Invalid notifications response');
    }

    final data = payload['data'];
    if (data is! Map) {
      throw const FormatException('Invalid notifications payload');
    }

    final rawList = data['notifications'];
    final serverNotifications = <NotificationModel>[];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map) {
          serverNotifications.add(
            _parseApiNotification(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final localOnly = await _getLocalOnlyNotifications(serverNotifications);
    final merged = [...serverNotifications, ...localOnly];
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (merged.length > _maxNotifications) {
      merged.removeRange(_maxNotifications, merged.length);
    }

    await _saveToStorage(merged);
    _cachedNotifications = merged;
    return List.from(merged);
  }

  Future<List<NotificationModel>> _getLocalOnlyNotifications(
    List<NotificationModel> serverNotifications,
  ) async {
    final local = await _getLocalHistory();
    final serverIds = serverNotifications.map((n) => n.id).toSet();
    return local.where((n) {
      if (serverIds.contains(n.id)) return false;
      return !_isServerNotificationId(n.id);
    }).toList();
  }

  Future<List<NotificationModel>> _getLocalHistory() async {
    if (_cachedNotifications != null) {
      return List.from(_cachedNotifications!);
    }

    try {
      final prefs = await _storage;
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        _cachedNotifications = [];
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      final notifications = jsonList
          .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
          .toList();

      _cachedNotifications = notifications;
      return List.from(notifications);
    } catch (e) {
      debugPrint('Error loading local notifications: $e');
      _cachedNotifications = [];
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_isServerNotificationId(notificationId)) {
      try {
        await _api.patch(ApiUserPaths.notificationRead(notificationId));
      } catch (e) {
        debugPrint('Failed to mark notification read on server: $e');
      }
    }

    try {
      final history = await _getLocalHistory();
      final index = history.indexWhere((n) => n.id == notificationId);

      if (index != -1) {
        history[index] = history[index].copyWith(isRead: true);
        await _saveToStorage(history);
        _cachedNotifications = history;
      }
    } catch (e) {
      debugPrint('Error marking notification as read locally: $e');
    }
  }

  Future<void> markAllRead() async {
    try {
      await _api.post(ApiUserPaths.notificationsReadAll);
    } catch (e) {
      debugPrint('Failed to mark all notifications read on server: $e');
    }

    try {
      final history = await _getLocalHistory();
      final updatedHistory = history
          .map((notification) => notification.copyWith(isRead: true))
          .toList();

      await _saveToStorage(updatedHistory);
      _cachedNotifications = updatedHistory;
    } catch (e) {
      debugPrint('Error marking all as read locally: $e');
    }
  }

  int get unreadCount {
    if (_cachedNotifications == null) return 0;
    return _cachedNotifications!.where((n) => !n.isRead).length;
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _api.get(ApiUserPaths.notifications);
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        final unread = data['data']['unreadCount'];
        if (unread is num) return unread.toInt();
      }
    } catch (_) {
      // fall through to local count
    }
    final history = await getHistory();
    return history.where((n) => !n.isRead).length;
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final history = await _getLocalHistory();
      history.removeWhere((n) => n.id == notificationId);
      await _saveToStorage(history);
      _cachedNotifications = history;
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final prefs = await _storage;
      await prefs.remove(_storageKey);
      _cachedNotifications = [];
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  Future<void> _saveToStorage(List<NotificationModel> notifications) async {
    try {
      final prefs = await _storage;
      final jsonList = notifications.map((n) => n.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error saving to storage: $e');
    }
  }

  void clearCache() {
    _cachedNotifications = null;
  }

  Future<List<Map<String, dynamic>>> getNotifications({
    bool unreadOnly = false,
  }) async {
    final history = await getHistory();
    final filtered =
        unreadOnly ? history.where((n) => !n.isRead).toList() : history;
    return filtered.map((n) => n.toJson()).toList();
  }
}
