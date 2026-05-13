import 'package:flutter/material.dart';
import 'package:prosper/services/user_service.dart';
import 'package:prosper/services/storage_service.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/screens/auth/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String token;

  const ProfileScreen({super.key, required this.token});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final StorageService _storage = StorageService();
  final BookmarkService _bookmarkService = BookmarkService();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  int _bookmarksCount = 0;
  int _booksInProgress = 0;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getProfile(widget.token);
      final bookmarks = await _bookmarkService.getBookmarks(widget.token);

      int inProgress = 0;
      for (var bookmark in bookmarks) {
        final status = bookmark['status'] as String?;
        if (status == BookmarkService.READING) inProgress++;
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _bookmarksCount = bookmarks.length;
          _booksInProgress = inProgress;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Ошибка загрузки: $e')),
              ],
            ),
            backgroundColor: theme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final theme = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Выход',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите выйти из аккаунта?',
          style: TextStyle(color: theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              context.read<NotificationProvider>().clearOnLogout();
              await _storage.clearToken();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Выйти', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getInitial() {
    final nickname = _profile?['nickname'] ?? '';
    final username = _profile?['username'] ?? 'U';
    if (nickname.isNotEmpty) return nickname[0].toUpperCase();
    if (username.isNotEmpty) return username[0].toUpperCase();
    return 'U';
  }

  String _getDisplayName() {
    final nickname = _profile?['nickname'] ?? '';
    final username = _profile?['username'] ?? 'User';
    return nickname.isNotEmpty ? nickname : username;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    _buildSliverHeader(theme),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 20),
                          _buildStatsRow(theme),
                          const SizedBox(height: 32),

                          // Кнопка возврата в админку
                          FutureBuilder<SharedPreferences>(
                            future: SharedPreferences.getInstance(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                final role = snapshot.data!.getString('role');
                                if (role == 'ADMIN' || role == 'MODERATOR') {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildSectionLabel(theme, 'Управление'),
                                      const SizedBox(height: 12),
                                      _buildMenuItem(
                                        theme: theme,
                                        icon: Icons.admin_panel_settings_outlined,
                                        title: 'Вернуться в управление',
                                        subtitle: 'Выйти из режима читателя',
                                        color: Colors.green,
                                        onTap: () => Navigator.of(context).pop(),
                                      ),
                                      const SizedBox(height: 32),
                                    ],
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          _buildSectionLabel(theme, 'Настройки'),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: theme.isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            title: theme.isDarkMode ? 'Светлая тема' : 'Тёмная тема',
                            subtitle: 'Переключить оформление',
                            onTap: () => theme.toggleTheme(),
                            trailing: Switch(
                              value: theme.isDarkMode,
                              activeColor: accentColor,
                              onChanged: (_) => theme.toggleTheme(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.refresh_rounded,
                            title: 'Обновить данные',
                            subtitle: 'Перезагрузить профиль и статистику',
                            onTap: _loadData,
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.info_outline_rounded,
                            title: 'О приложении',
                            subtitle: 'Версия 1.0.0 • Prosper',
                            onTap: () {
                              showAboutDialog(
                                context: context,
                                applicationName: 'Prosper',
                                applicationVersion: '1.0.0',
                                applicationIcon: const Icon(Icons.book_rounded, color: accentColor),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          _buildSectionLabel(theme, 'Аккаунт'),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.logout_rounded,
                            title: 'Выйти из системы',
                            subtitle: 'Завершить текущую сессию',
                            color: Colors.redAccent,
                            onTap: _logout,
                          ),
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSliverHeader(ThemeProvider theme) {
    return SliverAppBar(
      expandedHeight: 220,
      backgroundColor: theme.backgroundColor,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor,
                    accentColor.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(painter: GridPainter()),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getInitial(),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getDisplayName(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _profile?['email'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(ThemeProvider theme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            '$_bookmarksCount',
            'В закладках',
            Icons.bookmarks_outlined,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            theme,
            '$_booksInProgress',
            'В процессе',
            Icons.menu_book_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(ThemeProvider theme, String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: accentColor, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textPrimaryColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(ThemeProvider theme, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: theme.textSecondaryColor,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMenuItem({
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (color ?? accentColor).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color ?? accentColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.textPrimaryColor,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: theme.textSecondaryColor,
          ),
        ),
        trailing: trailing ?? Icon(
          Icons.chevron_right_rounded,
          color: theme.textSecondaryColor.withOpacity(0.5),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
