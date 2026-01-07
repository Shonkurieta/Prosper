import 'package:flutter/material.dart';
import 'package:prosper/services/user_service.dart';
import 'package:prosper/services/storage_service.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/screens/bookmarks/bookmarks_screen.dart';
import 'package:prosper/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  final String token;

  const ProfileScreen({super.key, required this.token});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    _animController.forward();
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getProfile(widget.token);
      final bookmarks = await _bookmarkService.getBookmarks(widget.token);
      
      // Count books in progress (not completed)
      int inProgress = 0;
      for (var bookmark in bookmarks) {
        if (bookmark['currentChapter'] != null && bookmark['currentChapter'] > 1) {
          inProgress++;
        }
      }
      
      setState(() {
        _profile = profile;
        _bookmarksCount = bookmarks.length;
        _booksInProgress = inProgress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
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
          'Выход из системы',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите выйти из аккаунта?',
          style: TextStyle(
            color: theme.textSecondaryColor,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: theme.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storage.clearToken();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.errorColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Выйти',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _getInitial() {
    final nickname = _profile?['nickname'] ?? '';
    final username = _profile?['username'] ?? 'User';
    
    if (nickname.isNotEmpty) return nickname[0].toUpperCase();
    if (username.isNotEmpty) return username[0].toUpperCase();
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final nickname = _profile?['nickname'] ?? '';
    final username = _profile?['username'] ?? 'User';
    final email = _profile?['email'] ?? '';

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: Stack(
            children: [
              // Decorative background shapes
              Positioned(
                top: -size.height * 0.12,
                left: -size.width * 0.18,
                child: Container(
                  width: size.width * 0.75,
                  height: size.width * 0.75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle2,
                  ),
                ),
              ),
              Positioned(
                bottom: -size.height * 0.08,
                right: -size.width * 0.22,
                child: Container(
                  width: size.width * 0.65,
                  height: size.width * 0.65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle1,
                  ),
                ),
              ),
              Positioned(
                top: size.height * 0.35,
                right: -25,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle3,
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: theme.primaryColor,
                              strokeWidth: 2.5,
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const SizedBox(height: 20),

                                // Profile Avatar
                                TweenAnimationBuilder(
                                  duration: const Duration(milliseconds: 1200),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Transform.scale(
                                      scale: 0.8 + (value * 0.2),
                                      child: Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: theme.primaryColor.withValues(alpha: 0.15),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.primaryColor.withValues(alpha: 0.2),
                                              blurRadius: 20,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            _getInitial(),
                                            style: TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.w900,
                                              color: theme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 24),

                                // Username
                                Text(
                                  nickname.isNotEmpty ? nickname : username,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: theme.textPrimaryColor,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 8),

                                // Email
                                if (email.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: theme.getCardDecoration(),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.mail_outline,
                                          color: theme.textSecondaryColor,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          email,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: theme.textSecondaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                const SizedBox(height: 32),

                                // Statistics
                                Text(
                                  'Моя статистика',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimaryColor,
                                  ),
                                ),

                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatCard(
                                        theme: theme,
                                        icon: Icons.bookmark_rounded,
                                        title: 'Закладки',
                                        value: '$_bookmarksCount',
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildStatCard(
                                        theme: theme,
                                        icon: Icons.auto_stories_rounded,
                                        title: 'В процессе',
                                        value: '$_booksInProgress',
                                        color: const Color(0xFF6C5CE7),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 32),

                                // Theme Toggle
                                _buildMenuItem(
                                  theme: theme,
                                  icon: theme.isDarkMode 
                                      ? Icons.light_mode_outlined 
                                      : Icons.dark_mode_outlined,
                                  title: theme.isDarkMode ? 'Светлая тема' : 'Темная тема',
                                  description: 'Переключить тему оформления',
                                  onTap: () async {
                                    await theme.toggleTheme();
                                  },
                                  trailing: Switch(
                                    value: theme.isDarkMode,
                                    onChanged: (value) async {
                                      await theme.toggleTheme();
                                    },
                                    activeColor: theme.primaryColor,
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Menu Items
                                _buildMenuItem(
                                  theme: theme,
                                  icon: Icons.bookmark_border_rounded,
                                  title: 'Мои закладки',
                                  description: 'Сохранённые новеллы и прогресс',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookmarksScreen(token: widget.token),
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 12),

                                _buildMenuItem(
                                  theme: theme,
                                  icon: Icons.refresh_rounded,
                                  title: 'Обновить данные',
                                  description: 'Перезагрузить профиль и статистику',
                                  onTap: () {
                                    _loadData();
                                  },
                                ),

                                const SizedBox(height: 12),

                                _buildMenuItem(
                                  theme: theme,
                                  icon: Icons.info_outline_rounded,
                                  title: 'О приложении',
                                  description: 'Версия 1.0.0 • Prosper',
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: theme.cardColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        title: Text(
                                          'Prosper',
                                          style: TextStyle(
                                            color: theme.textPrimaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        content: Text(
                                          'Приложение для чтения визуальных новелл\n\nВерсия: 1.0.0\n\n© 2025 Prosper',
                                          style: TextStyle(
                                            color: theme.textSecondaryColor,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(
                                              'Закрыть',
                                              style: TextStyle(
                                                color: theme.primaryColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                                const SizedBox(height: 40),

                                // Logout Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 60,
                                  child: ElevatedButton(
                                    onPressed: _logout,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.errorColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.exit_to_app_rounded, size: 24),
                                        SizedBox(width: 12),
                                        Text(
                                          'Выйти из системы',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: theme.getCardDecoration(),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: theme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: theme.textSecondaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      decoration: theme.getCardDecoration(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.textPrimaryColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: theme.textSecondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.textSecondaryColor.withValues(alpha: 0.4),
                    size: 18,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}