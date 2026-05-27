import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/notification_provider.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
import 'package:prosper/screens/novell/novell_detail_screen.dart';
import 'package:prosper/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsScreen extends StatefulWidget {
  final String token;
  const NotificationsScreen({super.key, required this.token});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with WidgetsBindingObserver {
  String _filter = 'Непрочитанные';
  String _currentUsername = 'Гость';
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUsername();
    _loadNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadNotifications();
    }
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUsername = prefs.getString('username') ?? 'Гость';
    });
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
      context.read<NotificationProvider>().refreshUnreadCount();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showConfirmDialog({
    required String title,
    required String message,
    required VoidCallback onConfirm,
    ThemeProvider? theme,
  }) {
    final t = theme ?? context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: t.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: t.borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.textPrimaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: t.textSecondaryColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('Отмена', style: TextStyle(color: t.textPrimaryColor)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Подтвердить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final notificationProvider = context.watch<NotificationProvider>();

    List<dynamic> filteredNotifications = _notifications;
    if (_filter == 'Непрочитанные') {
      filteredNotifications = _notifications.where((n) => !(n['read'] ?? false)).toList();
    } else if (_filter == 'Прочитанные') {
      filteredNotifications = _notifications.where((n) => n['read'] ?? false).toList();
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        title: Text(
          'Уведомления',
          style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold),
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
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : RefreshIndicator(
              color: accentColor,
              onRefresh: _loadNotifications,
              child: filteredNotifications.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: _buildEmptyState(theme),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: filteredNotifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationItem(context, theme, filteredNotifications[index]);
                      },
                    ),
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
            if (newValue != null) setState(() => _filter = newValue);
          },
          items: <String>['Все', 'Непрочитанные', 'Прочитанные']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, ThemeProvider theme, Map<String, dynamic> notification) {
    final isRead = notification['read'] ?? false;
    final type = notification['type'];

    return InkWell(
      onTap: () async {
        if (!isRead) {
          try {
            await NotificationService.markAsRead(notification['id']);
            setState(() => notification['read'] = true);
            context.read<NotificationProvider>().decrementUnreadCount();
          } catch (_) {}
        }

        if (!mounted) return;

        if (type == 'NEW_CHAPTER' && notification['bookId'] != null && notification['chapterOrder'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReaderScreen(
                token: widget.token,
                bookId: notification['bookId'],
                chapterOrder: notification['chapterOrder'],
                currentUsername: _currentUsername,
              ),
            ),
          );
        } else if (type == 'COMMENT_REPLY' && notification['bookId'] != null) {
          // Переход к конкретному комментарию во вкладке "Комментарии"
          final commentId = notification['commentId'] as int?;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NovellDetailScreen(
                token: widget.token,
                bookId: notification['bookId'],
                initialTab: 2,
                scrollToCommentId: commentId,
              ),
            ),
          );
        } else if (notification['bookId'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NovellDetailScreen(
                token: widget.token,
                bookId: notification['bookId'],
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: !isRead ? accentColor.withValues(alpha: 0.05) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: theme.isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
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
                    notification['title'] ?? 'Уведомление',
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
                    notification['message'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: accentColor, shape: BoxShape.circle),
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
          _showConfirmDialog(
            title: 'Отметить всё прочитанным?',
            message: 'Все уведомления будут помечены как прочитанные.',
            theme: theme,
            onConfirm: () async {
              try {
                await NotificationService.markAllAsRead();
                _loadNotifications();
              } catch (_) {}
            },
          );
        } else if (value == 'delete_all') {
          _showConfirmDialog(
            title: 'Удалить все уведомления?',
            message: 'Это действие нельзя отменить.',
            theme: theme,
            onConfirm: () async {
              try {
                await NotificationService.deleteAllNotifications();
                _loadNotifications();
              } catch (_) {}
            },
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
          child: const Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Text('Удалить все уведомления', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: theme.textSecondaryColor.withValues(alpha: 0.2)),
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
