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
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
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
      _animController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      _animController.forward();
    }
  }

  Future<void> _logout() async {
    final theme = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Выход из системы',
            style: TextStyle(fontWeight: FontWeight.w700, color: theme.textPrimaryColor)),
        content: Text('Вы уверены, что хотите выйти из аккаунта?',
            style: TextStyle(color: theme.textSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.errorColor,
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
                    _buildHeader(theme),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildStatsRow(theme),
                          const SizedBox(height: 28),
                          _buildSectionLabel(theme, 'УПРАВЛЕНИЕ'),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.chrome_reader_mode_outlined,
                            title: 'Режим читателя',
                            subtitle: 'Просмотр приложения как пользователь',
                            color: Colors.teal,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => UserHome(token: widget.token)),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _buildSectionLabel(theme, 'НАСТРОЙКИ'),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: theme.isDarkMode
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            title: theme.isDarkMode ? 'Светлая тема' : 'Тёмная тема',
                            subtitle: 'Переключить оформление приложения',
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
                            subtitle: 'Завершить текущую сессию',
                            color: theme.errorColor,
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

  Widget _buildHeader(ThemeProvider theme) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
            bottom: BorderSide(color: theme.borderColor, width: 1),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _avatarUrl == null
                            ? const LinearGradient(
                                colors: [Color(0xFFE07560), Color(0xFFD46A4F)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        border: Border.all(color: theme.borderColor, width: 2),
                      ),
                      child: ClipOval(
                        child: _avatarUrl != null
                            ? Image.network(
                                ApiConstants.getCoverUrl(_avatarUrl!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAvatarInitial(),
                              )
                            : _buildAvatarInitial(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Name + email
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            _username,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: theme.textPrimaryColor,
                              letterSpacing: -0.5,
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
                          const SizedBox(height: 10),
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.role == 'ADMIN'
                                  ? accentColor.withValues(alpha: 0.12)
                                  : const Color(0xFF5B8CDB).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: widget.role == 'ADMIN'
                                    ? accentColor.withValues(alpha: 0.3)
                                    : const Color(0xFF5B8CDB).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              widget.role == 'ADMIN' ? 'Администратор' : 'Модератор',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: widget.role == 'ADMIN'
                                    ? accentColor
                                    : const Color(0xFF5B8CDB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarInitial() {
    return Center(
      child: Text(
        _username.isNotEmpty ? _username[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildStatsRow(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              theme: theme,
              icon: Icons.auto_stories_outlined,
              label: 'Новелл',
              value: '$_booksCount',
              color: accentColor,
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
                color: const Color(0xFF5B8CDB),
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
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
        boxShadow: [theme.cardShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.textPrimaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildSectionLabel(ThemeProvider theme, String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.borderColor),
            boxShadow: [theme.cardShadow],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
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
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.textSecondaryColor.withValues(alpha: 0.4),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
