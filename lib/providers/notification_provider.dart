import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String title;
  final String bookTitle;
  final String coverUrl;
  final int chapterOrder;
  final int bookId;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.bookTitle,
    required this.coverUrl,
    required this.chapterOrder,
    required this.bookId,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationProvider extends ChangeNotifier {
  String? _currentUserId;
  final Map<String, Set<int>> _userSubscriptions = {};
  final List<AppNotification> _notifications = [];
  

  List<AppNotification> get notifications => _notifications;
  Set<int> get _subscribedBookIds => _userSubscriptions[_currentUserId] ?? {};

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void addNotification(AppNotification notification) {
    // Добавляем уведомление только если пользователь подписан на эту книгу
    if (_currentUserId != null && _userSubscriptions[_currentUserId] != null && _userSubscriptions[_currentUserId]!.contains(notification.bookId)) {
      _notifications.insert(0, notification);
      notifyListeners();
    }
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    for (var n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void removeAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

    void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      notifyListeners();
    }
  }

  void toggleSubscription(int bookId) {
    if (_currentUserId == null) return; // Cannot subscribe without a user
    _userSubscriptions.putIfAbsent(_currentUserId!, () => {});
    if (_userSubscriptions[_currentUserId]!.contains(bookId)) {
      _userSubscriptions[_currentUserId]!.remove(bookId);
    } else {
      _userSubscriptions[_currentUserId]!.add(bookId);
    }
    notifyListeners();
  }

  bool isSubscribed(int bookId) {
    return _currentUserId != null && _userSubscriptions[_currentUserId] != null && _userSubscriptions[_currentUserId]!.contains(bookId);
  }

  // Helper for demo/test purposes - usually this would come from a real backend
  void simulateNewChapter(int bookId, String bookTitle, String coverUrl, int chapterOrder) {
    addNotification(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'добавлена новая глава ($chapterOrder)',
      bookTitle: bookTitle,
      coverUrl: coverUrl,
      chapterOrder: chapterOrder,
      bookId: bookId,
      timestamp: DateTime.now(),
    ));
  }
}