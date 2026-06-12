import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

/// Local notification storage service with SharedPreferences
class NotificationService {
  static const String _storageKey = 'app_notifications';
  static const int _maxNotifications = 50;

  static NotificationService? _instance;
  factory NotificationService() => _instance ??= NotificationService._();
  NotificationService._();

  SharedPreferences? _prefs;
  List<NotificationModel>? _cachedNotifications;

  Future<SharedPreferences> get _storage async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Save a notification to local storage
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

      final history = await getHistory();
      history.insert(0, notification);

      // Keep only last 50 notifications (FIFO)
      if (history.length > _maxNotifications) {
        history.removeRange(_maxNotifications, history.length);
      }

      await _saveToStorage(history);
      _cachedNotifications = history;
      
      debugPrint('✅ Notification saved: $title');
    } catch (e) {
      debugPrint('❌ Error saving notification: $e');
    }
  }

  /// Get notification history
  Future<List<NotificationModel>> getHistory() async {
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
          .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
          .toList();

      _cachedNotifications = notifications;
      return List.from(notifications);
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
      _cachedNotifications = [];
      return [];
    }
  }

  /// Mark a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final history = await getHistory();
      final index = history.indexWhere((n) => n.id == notificationId);
      
      if (index != -1) {
        history[index] = history[index].copyWith(isRead: true);
        await _saveToStorage(history);
        _cachedNotifications = history;
      }
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllRead() async {
    try {
      final history = await getHistory();
      final updatedHistory = history
          .map((notification) => notification.copyWith(isRead: true))
          .toList();
      
      await _saveToStorage(updatedHistory);
      _cachedNotifications = updatedHistory;
      
      debugPrint('✅ All notifications marked as read');
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  /// Get unread notification count
  int get unreadCount {
    if (_cachedNotifications == null) return 0;
    return _cachedNotifications!.where((n) => !n.isRead).length;
  }

  /// Get unread count asynchronously
  Future<int> getUnreadCount() async {
    final history = await getHistory();
    return history.where((n) => !n.isRead).length;
  }

  /// Delete a specific notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final history = await getHistory();
      history.removeWhere((n) => n.id == notificationId);
      await _saveToStorage(history);
      _cachedNotifications = history;
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> deleteAllNotifications() async {
    try {
      final prefs = await _storage;
      await prefs.remove(_storageKey);
      _cachedNotifications = [];
      debugPrint('✅ All notifications cleared');
    } catch (e) {
      debugPrint('❌ Error clearing notifications: $e');
    }
  }

  /// Save notifications to storage
  Future<void> _saveToStorage(List<NotificationModel> notifications) async {
    try {
      final prefs = await _storage;
      final jsonList = notifications.map((n) => n.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('❌ Error saving to storage: $e');
    }
  }

  /// Clear cache (useful for testing)
  void clearCache() {
    _cachedNotifications = null;
  }

  /// Legacy method for backward compatibility
  Future<List<Map<String, dynamic>>> getNotifications({
    bool unreadOnly = false,
  }) async {
    final history = await getHistory();
    final filtered = unreadOnly ? history.where((n) => !n.isRead).toList() : history;
    return filtered.map((n) => n.toJson()).toList();
  }
}
