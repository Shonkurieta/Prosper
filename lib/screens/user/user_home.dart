import 'package:flutter/material.dart';
import 'package:prosper/screens/home/home_screen.dart';
import 'package:prosper/screens/library/library_screen.dart';
import 'package:prosper/screens/profile/profile_screen.dart';
import 'package:prosper/screens/bookmarks/bookmarks_screen.dart';
import 'package:prosper/screens/notifications/notifications_screen.dart';
import 'package:prosper/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prosper/screens/ai_assistant_screen.dart';

class UserHome extends StatefulWidget {
  final String token;
  const UserHome({super.key, required this.token});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 1;
  late AnimationController _animController;
  late String _currentToken;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _currentToken = widget.token;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _animController.forward();
    WidgetsBinding.instance.addObserver(this);
    _initUserInNotificationProvider();
  }

  void _updateToken(String newToken) {
    setState(() {
      _currentToken = newToken;
    });
  }

  List<Widget> _buildScreens() {
    return [
      HomeScreen(token: _currentToken),
      LibraryScreen(token: _currentToken),
      BookmarksScreen(token: _currentToken),
      NotificationsScreen(token: _currentToken),
      ProfileScreen(
        token: _currentToken,
        onTokenUpdated: _updateToken,
      ),
    ];
  }

  Future<void> _initUserInNotificationProvider() async {
    if (mounted && _currentToken.isNotEmpty) {
      context.read<NotificationProvider>().refreshUnreadCount();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _currentToken.isNotEmpty) {
      context.read<NotificationProvider>().refreshUnreadCount();
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final screens = _buildScreens();
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: FadeTransition(
        opacity: _animController,
        child: screens[_selectedIndex],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: AiAssistantScreen(token: _currentToken),
            ),
          );
        },
        backgroundColor: accentColor,
        shape: const CircleBorder(),
        elevation: 0,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget _buildBottomBar(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                theme: theme,
                icon: Icons.bookmark_border_rounded,
                activeIcon: Icons.bookmark_rounded,
                label: 'Закладки',
                index: 2,
              ),
              _buildNavItem(
                theme: theme,
                icon: Icons.menu_book_outlined,
                activeIcon: Icons.menu_book,
                label: 'Каталог',
                index: 0,
              ),
              _buildNavItem(
                theme: theme,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Главная',
                index: 1,
              ),
              _buildNavItem(
                theme: theme,
                icon: Icons.notifications_none_rounded,
                activeIcon: Icons.notifications_rounded,
                label: 'Уведомления',
                index: 3,
                showBadge: context.watch<NotificationProvider>().unreadCount > 0,
              ),
              _buildNavItem(
                theme: theme,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Профиль',
                index: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required ThemeProvider theme,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    bool showBadge = false,
  }) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? accentColor : theme.textPrimaryColor;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  color: color,
                  size: 26,
                ),
                if (showBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
