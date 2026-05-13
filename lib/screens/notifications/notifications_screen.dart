import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/notification_provider.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:prosper/screens/reader/reader_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String token;
  const NotificationsScreen({super.key, required this.token});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'Непрочитанные';
  static const Color accentColor = Color(0xFFD46A4F);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    
    List<AppNotification> filteredNotifications = notificationProvider.notifications;
    if (_filter == 'Все') {
      filteredNotifications = filteredNotifications.where((n) => !n.isRead).toList();
    } else if (_filter == 'Прочитанные') {
      filteredNotifications = filteredNotifications.where((n) => n.isRead).toList();
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        title: Text(
          'Уведомления',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.textPrimaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _buildFilterDropdown(theme),
          _buildMoreOptions(theme, notificationProvider),
        ],
      ),
      body: filteredNotifications.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: filteredNotifications.length,
              itemBuilder: (context, index) {
                final notification = filteredNotifications[index];
                return _buildNotificationItem(context, theme, notificationProvider, notification);
              },
            ),
    );
  }

  Widget _buildFilterDropdown(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filter,
          dropdownColor: theme.cardColor,
          icon: Icon(Icons.keyboard_arrow_down, color: theme.textSecondaryColor, size: 20),
          style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _filter = newValue;
              });
            }
          },
          items: <String>['Все', 'Непрочитанные', 'Прочитанные']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMoreOptions(ThemeProvider theme, NotificationProvider provider) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.textPrimaryColor),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'mark_all_read') {
          provider.markAllAsRead();
        } else if (value == 'delete_all') {
          provider.removeAllNotifications();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, color: theme.textPrimaryColor, size: 20),
              const SizedBox(width: 12),
              Text('Настройки', style: TextStyle(color: theme.textPrimaryColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'mark_all_read',
          child: Row(
            children: [
              Icon(Icons.done_all, color: theme.textPrimaryColor, size: 20),
              const SizedBox(width: 12),
              Text('Отметить всё прочитанным', style: TextStyle(color: theme.textPrimaryColor)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete_all',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              const SizedBox(width: 12),
              Text('Удалить все уведомления', style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationItem(BuildContext context, ThemeProvider theme, NotificationProvider provider, AppNotification notification) {
    return InkWell(
      onTap: () {
        provider.markAsRead(notification.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(
              token: widget.token,
              bookId: notification.bookId,
              chapterOrder: notification.chapterOrder,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : accentColor.withOpacity(0.05),
          border: Border(
            bottom: BorderSide(
              color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Обложка слева
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                ApiConstants.getCoverUrl(notification.coverUrl),
                width: 45,
                height: 65,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 45,
                  height: 65,
                  color: theme.cardColor,
                  child: Icon(Icons.book, color: theme.textSecondaryColor, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Информация справа
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.bookTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Добавлена глава ${notification.chapterOrder}',
                    style: TextStyle(
                      color: theme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(notification.timestamp),
                    style: TextStyle(
                      color: theme.textSecondaryColor.withOpacity(0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин. назад';
    if (diff.inHours < 24) return '${diff.inHours} ч. назад';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: theme.textSecondaryColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'Уведомлений пока нет',
            style: TextStyle(color: theme.textSecondaryColor, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
