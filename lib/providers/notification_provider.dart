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
  // Храним уведомления отдельно для каждого пользователя
  final Map<String, List<AppNotification>> _userNotifications = {};
  

  List<AppNotification> get notifications {
    if (_currentUserId == null) return [];
    return _userNotifications[_currentUserId] ?? [];
  }

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  void addNotification(AppNotification notification) {
    // В симуляции мы добавляем уведомление всем пользователям, которые подписаны на книгу
    // В реальном приложении это бы делал бэкенд
    _userSubscriptions.forEach((userId, subscriptions) {
      if (subscriptions.contains(notification.bookId)) {
        _userNotifications.putIfAbsent(userId, () => []);
        
        // Создаем копию уведомления для каждого пользователя, чтобы статус isRead был индивидуальным
        final userNotification = AppNotification(
          id: notification.id,
          title: notification.title,
          bookTitle: notification.bookTitle,
          coverUrl: notification.coverUrl,
          chapterOrder: notification.chapterOrder,
          bookId: notification.bookId,
          timestamp: notification.timestamp,
          isRead: false,
        );
        
        _userNotifications[userId]!.insert(0, userNotification);
      }
    });
    notifyListeners();
  }

  void markAsRead(String id) {
    if (_currentUserId == null) return;
    final userNotifs = _userNotifications[_currentUserId];
    if (userNotifs == null) return;

    final index = userNotifs.indexWhere((n) => n.id == id);
    if (index != -1 && !userNotifs[index].isRead) {
      userNotifs[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    if (_currentUserId == null) return;
    final userNotifs = _userNotifications[_currentUserId];
    if (userNotifs == null) return;

    for (var n in userNotifs) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void removeAllNotifications() {
    if (_currentUserId == null) return;
    _userNotifications[_currentUserId]?.clear();
    notifyListeners();
  }

  void setCurrentUser(String? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      print('🔔 NotificationProvider: Current user set to $userId');
      notifyListeners();
    }
  }

  void clearOnLogout() {
    _currentUserId = null;
    // Мы не очищаем все уведомления всех пользователей, 
    // просто сбрасываем текущего пользователя.
    // Если нужно очистить память полностью - можно раскомментировать:
    // _userNotifications.clear();
    // _userSubscriptions.clear();
    notifyListeners();
  }

  void toggleSubscription(int bookId) {
    if (_currentUserId == null) return;
    _userSubscriptions.putIfAbsent(_currentUserId!, () => {});
    if (_userSubscriptions[_currentUserId]!.contains(bookId)) {
      _userSubscriptions[_currentUserId]!.remove(bookId);
    } else {
      _userSubscriptions[_currentUserId]!.add(bookId);
    }
    notifyListeners();
  }

  bool isSubscribed(int bookId) {
    return _currentUserId != null && 
           _userSubscriptions[_currentUserId] != null && 
           _userSubscriptions[_currentUserId]!.contains(bookId);
  }

  void simulateNewChapter(int bookId, String bookTitle, String coverUrl, int chapterOrder) {
    addNotification(AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'добавлена новая глава',
      bookTitle: bookTitle,
      coverUrl: coverUrl,
      chapterOrder: chapterOrder,
      bookId: bookId,
      timestamp: DateTime.now(),
    ));
  }
}
