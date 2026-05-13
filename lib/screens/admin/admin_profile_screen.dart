import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/notification_provider.dart';
import 'package:prosper/services/admin_service.dart';
import 'package:prosper/screens/user/user_home.dart';

class AdminProfileScreen extends StatefulWidget {
  final String token;
  final String role;

  const AdminProfileScreen({super.key, required this.token, required this.role});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String _username = '';
  String _email = '';
  bool _isLoading = true;
  int _booksCount = 0;
  int _usersCount = 0;

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Пользователь';
      _email = prefs.getString('email') ?? '';
    });

    try {
      final adminService = AdminService(widget.token);
      final books = await adminService.getBooks();
      if (widget.role == 'ADMIN') {
        final users = await adminService.getUsers();
        _usersCount = users.length;
      }
      setState(() {
        _booksCount = books.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final theme = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Выход', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Очищаем провайдер уведомлений
              if (mounted) {
                context.read<NotificationProvider>().clearOnLogout();
              }
              
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
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
                          _buildSectionLabel(theme, 'Управление'),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.book_outlined,
                            title: 'Режим читателя',
                            subtitle: 'Просмотр новелл',
                            color: Colors.green,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => UserHome(token: widget.token)),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                          _buildSectionLabel(theme, 'Настройки'),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: theme.isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            title: theme.isDarkMode ? 'Светлая тема' : 'Тёмная тема',
                            subtitle: 'Сменить оформление',
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
                            icon: Icons.logout_rounded,
                            title: 'Выйти из аккаунта',
                            subtitle: 'Завершить сессию',
                            color: Colors.redAccent,
                            onTap: _logout,
                          ),
                          const SizedBox(height: 48),
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
    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background banner
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
            ),
            child: CustomPaint(
              painter: _GridPatternPainter(accentColor.withOpacity(0.06)),
              size: Size.infinite,
            ),
          ),

          // Role chip — top right
          Positioned(
            top: 52,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.role == 'ADMIN' ? 'ADMIN' : 'MOD',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          // Bottom card that overlaps banner
          Positioned(
            bottom: -60,
            left: 20,
            right: 20,
            child: _buildProfileCard(theme),
          ),

          // Top label
          Positioned(
            top: 52,
            left: 20,
            child: Text(
              'Профиль',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: theme.textPrimaryColor,
              ),
            ),
          ),

          // Spacer so the sliver has correct height
          const SizedBox(height: 260),
        ],
      ),
    );
  }

  Widget _buildProfileCard(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accentColor.withOpacity(0.6), accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeProvider theme) {
    return Row(
      children: [
        _buildStatCard(theme, 'Новеллы', _booksCount.toString(), Icons.book_rounded),
        if (widget.role == 'ADMIN') ...[
          const SizedBox(width: 16),
          _buildStatCard(theme, 'Пользователи', _usersCount.toString(), Icons.people_rounded),
        ],
      ],
    );
  }

  Widget _buildStatCard(ThemeProvider theme, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accentColor, size: 24),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondaryColor,
              ),
            ),
          ],
        ),
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
    Color? color,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            fontWeight: FontWeight.bold,
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
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: theme.textSecondaryColor, size: 20),
      ),
    );
  }
}

class _GridPatternPainter extends CustomPainter {
  final Color color;
  _GridPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const step = 20.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
