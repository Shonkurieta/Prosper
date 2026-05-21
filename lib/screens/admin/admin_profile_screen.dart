import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/services/admin_service.dart';
import 'package:prosper/services/user_service.dart';
import 'package:prosper/constants/api_constants.dart';
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
  String? _avatarUrl;
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
      final userService = UserService();
      final profile = await userService.getProfile(widget.token);
      
      final adminService = AdminService(widget.token);
      final books = await adminService.getBooks();
      if (widget.role == 'ADMIN') {
        final users = await adminService.getUsers();
        _usersCount = users.length;
      }
      setState(() {
        _username = profile['nickname'] ?? profile['username'] ?? _username;
        _email = profile['email'] ?? _email;
        _avatarUrl = profile['avatarUrl'];
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
              gradient: _avatarUrl == null ? LinearGradient(
                colors: [accentColor.withOpacity(0.6), accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
              color: _avatarUrl != null ? Colors.white : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: _avatarUrl != null
                  ? Image.network(
                      ApiConstants.getCoverUrl(_avatarUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(
                          _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                  : Center(
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
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimaryColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _email,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textSecondaryColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 68),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              theme: theme,
              icon: Icons.auto_stories_outlined,
              label: 'Новелл',
              value: '$_booksCount',
              accent: accentColor,
            ),
          ),
          if (widget.role == 'ADMIN') ...[
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                theme: theme,
                icon: Icons.people_outline_rounded,
                label: 'Пользователей',
                value: '$_usersCount',
                accent: const Color(0xFF5B8CDB),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
  required ThemeProvider theme,
  required IconData icon,
  required String label,
  required String value,
  required Color accent,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accent.withOpacity(0.15)),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(                          // ← вот это критично
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: theme.textPrimaryColor,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildSectionLabel(ThemeProvider theme, String label) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: theme.textSecondaryColor,
          ),
        ),
      ],
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
    final iconColor = color ?? accentColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: iconColor.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimaryColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: theme.textSecondaryColor.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// Subtle grid pattern for the header banner
class _GridPatternPainter extends CustomPainter {
  final Color color;
  _GridPatternPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPatternPainter old) => old.color != color;
}