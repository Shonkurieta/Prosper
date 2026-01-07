import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/services/admin_service.dart';
import 'package:prosper/screens/admin/add_book_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  final String token;

  const AdminProfileScreen({super.key, required this.token});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  String _username = '';
  String _email = '';
  bool _isLoading = true;
  int _booksCount = 0;
  int _usersCount = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Администратор';
      _email = prefs.getString('email') ?? '';
    });

    try {
      final adminService = AdminService(widget.token);
      final books = await adminService.getBooks();
      final users = await adminService.getUsers();
      
      setState(() {
        _booksCount = books.length;
        _usersCount = users.length;
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
        title: Text(
          'Выход из системы',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите выйти?',
          style: TextStyle(color: theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: TextStyle(color: theme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.primaryColor,
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          children: [
                            const SizedBox(height: 20),

                            // Аватар
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.cardColor,
                                boxShadow: [theme.cardShadow],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.primaryColor.withValues(alpha: 0.15),
                                ),
                                child: Icon(
                                  Icons.admin_panel_settings_rounded,
                                  size: 70,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Роль
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: theme.errorColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.errorColor.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    color: theme.errorColor,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'АДМИНИСТРАТОР',
                                    style: TextStyle(
                                      color: theme.errorColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Имя пользователя
                            Text(
                              _username,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: theme.textPrimaryColor,
                                letterSpacing: 0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 8),

                            // Email
                            if (_email.isNotEmpty)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.alternate_email,
                                    color: theme.textSecondaryColor,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _email,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: theme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 40),

                            // Theme Toggle
                            _buildMenuItem(
                              theme: theme,
                              icon: theme.isDarkMode 
                                  ? Icons.light_mode_outlined 
                                  : Icons.dark_mode_outlined,
                              title: theme.isDarkMode ? 'Светлая тема' : 'Темная тема',
                              description: 'Переключить тему оформления',
                              color: theme.primaryColor,
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

                            const SizedBox(height: 24),

                            // Статистика
                            Text(
                              'Статистика системы',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimaryColor,
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Карточки статистики в сетке
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    theme: theme,
                                    icon: Icons.menu_book_rounded,
                                    title: 'Новеллы',
                                    value: '$_booksCount',
                                    color: theme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    theme: theme,
                                    icon: Icons.people_outline,
                                    title: 'Пользователи',
                                    value: '$_usersCount',
                                    color: const Color(0xFF6C5CE7),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Быстрые действия
                            Text(
                              'Быстрые действия',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimaryColor,
                              ),
                            ),

                            const SizedBox(height: 16),

                            _buildActionCard(
                              theme: theme,
                              icon: Icons.library_add_rounded,
                              title: 'Добавить новеллу',
                              description: 'Создать новую новеллу в библиотеке',
                              color: theme.primaryColor,
                              onTap: () async {
                                // Navigate to add book screen
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddBookScreen(token: widget.token),
                                  ),
                                );
                                
                                // Reload data if book was added
                                if (result == true) {
                                  setState(() => _isLoading = true);
                                  await _loadData();
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.white),
                                            SizedBox(width: 12),
                                            Text('Новелла успешно добавлена'),
                                          ],
                                        ),
                                        backgroundColor: theme.successColor,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        margin: const EdgeInsets.all(20),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),

                            const SizedBox(height: 12),

                            _buildActionCard(
                              theme: theme,
                              icon: Icons.refresh_rounded,
                              title: 'Обновить данные',
                              description: 'Перезагрузить статистику',
                              color: theme.warningColor,
                              onTap: () {
                                setState(() => _isLoading = true);
                                _loadData();
                              },
                            ),

                            const SizedBox(height: 12),

                            _buildActionCard(
                              theme: theme,
                              icon: Icons.analytics_outlined,
                              title: 'Аналитика',
                              description: 'Просмотр статистики и отчетов',
                              color: const Color(0xFF00B894),
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Функция в разработке'),
                                    backgroundColor: theme.primaryColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 40),

                            // Кнопка выхода
                            SizedBox(
                              width: double.infinity,
                              height: 60,
                              child: ElevatedButton(
                                onPressed: _logout,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.errorColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout_rounded, size: 22),
                                    SizedBox(width: 12),
                                    Text(
                                      'Выйти из системы',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuItem({
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: theme.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(
              icon,
              color: color,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: theme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: theme.textSecondaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: theme.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: theme.textSecondaryColor,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}