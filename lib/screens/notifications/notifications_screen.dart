import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/notification_provider.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
import 'package:prosper/screens/novell/novell_detail_screen.dart';
import 'package:prosper/services/comment_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  final String token;
  const NotificationsScreen({super.key, required this.token});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'Непрочитанные';
  String _currentUsername = 'Гость';
  List<dynamic> _commentNotifications = [];
  bool _isLoadingCommentNotifications = true;
  static const Color accentColor = Color(0xFFD46A4F);
  final CommentNotificationService _commentNotificationService = CommentNotificationService();

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _loadCommentNotifications();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUsername = prefs.getString('username') ?? 'Гость';
    });
  }

  Future<void> _loadCommentNotifications() async {
    try {
      final notifications = await _commentNotificationService.getNotifications(widget.token);
      setState(() {
        _commentNotifications = notifications;
        _isLoadingCommentNotifications = false;
      });
    } catch (e) {
      setState(() => _isLoadingCommentNotifications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    
    List<AppNotification> chapterNotifications = notificationProvider.notifications;
    if (_filter == 'Все') {
      // Show all
    } else if (_filter == 'Непрочитанные') {
      chapterNotifications = chapterNotifications.where((n) => !n.isRead).toList();
    } else if (_filter == 'Прочитанные') {
      chapterNotifications = chapterNotifications.where((n) => n.isRead).toList();
    }
    
    List<dynamic> allNotifications = [];
    allNotifications.addAll(chapterNotifications);
    allNotifications.addAll(_commentNotifications);
    allNotifications.sort((a, b) {
      DateTime timeA = a is AppNotification ? a.timestamp : (a['createdAt'] != null ? DateTime.parse(a['createdAt']) : DateTime.now());
      DateTime timeB = b is AppNotification ? b.timestamp : (b['createdAt'] != null ? DateTime.parse(b['createdAt']) : DateTime.now());
      return timeB.compareTo(timeA);
    });

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
      body: allNotifications.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: allNotifications.length,
              itemBuilder: (context, index) {
                final notification = allNotifications[index];
                if (notification is AppNotification) {
                  return _buildNotificationItem(context, theme, notificationProvider, notification);
                } else {
                  return _buildCommentNotificationItem(context, theme, notification);
                }
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

  Widget _buildCommentNotificationItem(BuildContext context, ThemeProvider theme, dynamic notification) {
    final isRead = notification['isRead'] ?? false;
    
    return InkWell(
      onTap: () {
        if (!isRead) {
          _commentNotificationService.markAsRead(widget.token, notification['id']);
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NovellDetailScreen(
              token: widget.token,
              bookId: notification['bookId'],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: !isRead ? accentColor.withValues(alpha: 0.05) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: theme.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                ApiConstants.getCoverUrl(notification['bookCoverUrl'] ?? ''),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification['bookTitle'] ?? 'Без названия',
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
                    notification['commentAuthor'] ?? 'Аноним',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['commentContent'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textSecondaryColor.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (!isRead)
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
              currentUsername: _currentUsername,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.transparent : accentColor.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(
              color: theme.isDarkMode ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
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
                      color: theme.textSecondaryColor.withValues(alpha: 0.6),
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
          Icon(Icons.notifications_none_rounded, size: 80, color: theme.textSecondaryColor.withValues(alpha: 0.2)),
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
