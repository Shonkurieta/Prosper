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
  final List<AppNotification> _notifications = [];
  final Set<int> _subscribedBookIds = {};

  List<AppNotification> get notifications => _notifications;
  Set<int> get subscribedBookIds => _subscribedBookIds;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void addNotification(AppNotification notification) {
    _notifications.insert(0, notification);
    notifyListeners();
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

  void toggleSubscription(int bookId) {
    if (_subscribedBookIds.contains(bookId)) {
      _subscribedBookIds.remove(bookId);
    } else {
      _subscribedBookIds.add(bookId);
    }
    notifyListeners();
  }

  bool isSubscribed(int bookId) {
    return _subscribedBookIds.contains(bookId);
  }

  // Helper for demo/test purposes - usually this would come from a real backend
  void simulateNewChapter(int bookId, String bookTitle, String coverUrl, int chapterOrder) {
    if (_subscribedBookIds.contains(bookId)) {
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
}
