import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await NotificationService.getUnreadCount();
      notifyListeners();
    } catch (e) {
      print('Error refreshing unread count: $e');
    }
  }

  void setUnreadCount(int count) {
    _unreadCount = count;
    notifyListeners();
  }

  void decrementUnreadCount() {
    if (_unreadCount > 0) {
      _unreadCount--;
      notifyListeners();
    }
  }

  void clearOnLogout() {
    _unreadCount = 0;
    notifyListeners();
  }
}
