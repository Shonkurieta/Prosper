import 'dart:io';
import 'package:flutter/material.dart';
import 'package:prosper/services/user_service.dart';
import 'package:prosper/services/storage_service.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/screens/auth/login_screen.dart';
import 'package:prosper/screens/auth/register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/notification_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:prosper/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final String token;
  final Function(String)? onTokenUpdated;

  const ProfileScreen({super.key, required this.token, this.onTokenUpdated});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final StorageService _storage = StorageService();
  final BookmarkService _bookmarkService = BookmarkService();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  int _bookmarksCount = 0;
  int _booksInProgress = 0;
  int _completedCount = 0;
  late String _currentToken;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _currentToken = widget.token;
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
    if (widget.token.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getProfile(_currentToken);
      final bookmarks = await _bookmarkService.getBookmarks(_currentToken);

      int inProgress = 0;
      int completed = 0;
      for (var bookmark in bookmarks) {
        final status = bookmark['status'] as String?;
        if (status == BookmarkService.READING) inProgress++;
        if (status == BookmarkService.COMPLETED) completed++;
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _bookmarksCount = bookmarks.length;
          _booksInProgress = inProgress;
          _completedCount = completed;
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
              // Выходим из Google сессии, если она была
              await _authService.signOut();
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

  void _showEditNicknameDialog(ThemeProvider theme) {
    final controller = TextEditingController(text: _getDisplayName());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Сменить никнейм', style: TextStyle(color: theme.textPrimaryColor)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: theme.textPrimaryColor),
          decoration: InputDecoration(
            hintText: 'Новый никнейм',
            hintStyle: TextStyle(color: theme.textSecondaryColor),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.textSecondaryColor)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNickname = controller.text.trim();
              if (newNickname.isEmpty) return;
              Navigator.pop(context);
              try {
                final response = await _userService.updateNickname(_currentToken, newNickname);
                final newToken = response['token'];
                if (newToken != null) {
                  await _storage.saveToken(newToken);
                  
                  // Обновляем имя пользователя в SharedPreferences, так как оно используется в других экранах
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('username', newNickname);
                  
                  if (widget.onTokenUpdated != null) {
                    widget.onTokenUpdated!(newToken);
                  }
                  
                  setState(() {
                    _currentToken = newToken;
                  });
                }
                _loadData();
                _showSuccessSnackBar('Никнейм успешно изменён');
              } catch (e) {
                _showErrorSnackBar(e.toString());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(ThemeProvider theme) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Сменить пароль', style: TextStyle(color: theme.textPrimaryColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPasswordField(oldPasswordController, 'Текущий пароль', theme),
            _buildPasswordField(newPasswordController, 'Новый пароль', theme),
            _buildPasswordField(confirmPasswordController, 'Подтвердите пароль', theme),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                _showErrorSnackBar('Пароли не совпадают');
                return;
              }
              if (newPasswordController.text.length < 8) {
                _showErrorSnackBar('Минимум 8 символов');
                return;
              }
              Navigator.pop(context);
              try {
                await _userService.changePassword(
                  _currentToken, 
                  oldPasswordController.text, 
                  newPasswordController.text
                );
                _showSuccessSnackBar('Пароль успешно изменён');
              } catch (e) {
                _showErrorSnackBar(e.toString());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Сменить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint, ThemeProvider theme) {
    return TextField(
      controller: controller,
      obscureText: true,
      style: TextStyle(color: theme.textPrimaryColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textSecondaryColor),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.textSecondaryColor)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: accentColor)),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    
    if (pickedFile != null) {
      try {
        setState(() => _isLoading = true);
        await _userService.updateAvatar(_currentToken, File(pickedFile.path));
        await _loadData();
        _showSuccessSnackBar('Аватар успешно обновлён');
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorSnackBar(e.toString());
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception: ', '')),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    if (widget.token.isEmpty) return _buildGuestScreen(theme);
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
                          const SizedBox(height: 24),
                          _buildStatsRow(theme),
                          const SizedBox(height: 28),

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
                                        color: Colors.teal,
                                        onTap: () => Navigator.of(context).pop(),
                                      ),
                                      const SizedBox(height: 28),
                                    ],
                                  );
                                }
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                          _buildSectionLabel(theme, 'Профиль'),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.person_outline_rounded,
                            title: 'Изменить никнейм',
                            subtitle: 'Сменить имя пользователя',
                            onTap: () => _showEditNicknameDialog(theme),
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.lock_outline_rounded,
                            title: 'Изменить пароль',
                            subtitle: 'Обновить данные для входа',
                            onTap: () => _showChangePasswordDialog(theme),
                          ),
                          const SizedBox(height: 28),
                          _buildSectionLabel(theme, 'Интерфейс'),
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
                          const SizedBox(height: 28),
                          _buildSectionLabel(theme, 'Аккаунт'),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            theme: theme,
                            icon: Icons.logout_rounded,
                            title: 'Выйти из системы',
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

  Widget _buildSliverHeader(ThemeProvider theme) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(bottom: BorderSide(color: theme.borderColor)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              children: [
                // Avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 3),
                      ),
                      child: ClipOval(
                        child: _profile?['avatarUrl'] != null
                            ? Image.network(
                                ApiConstants.getCoverUrl(_profile!['avatarUrl']),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAvatarFallback(),
                              )
                            : _buildAvatarFallback(),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadAvatar,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.cardColor, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _getDisplayName(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimaryColor,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _profile?['email'] ?? '',
                  style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: accentColor.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          _getInitial(),
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(ThemeProvider theme) {
    return Row(
      children: [
        Expanded(child: _buildStatCard(theme, '$_bookmarksCount', 'Закладки', Icons.bookmarks_outlined)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard(theme, '$_booksInProgress', 'Читаю', Icons.menu_book_rounded)),
        const SizedBox(width: 10),
        Expanded(child: _buildStatCard(theme, '$_completedCount', 'Прочитано', Icons.check_circle_outline_rounded)),
      ],
    );
  }

  Widget _buildStatCard(ThemeProvider theme, String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderColor),
        boxShadow: [theme.cardShadow],
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 19),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.textPrimaryColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: theme.textSecondaryColor),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
          label.toUpperCase(),
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
                      style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
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

  Widget _buildGuestScreen(ThemeProvider theme) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.person_outline_rounded, color: accentColor, size: 48),
                ),
                const SizedBox(height: 24),
                Text('Вы не авторизованы',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('Войдите или зарегистрируйтесь, чтобы получить доступ к профилю',
                    style: TextStyle(fontSize: 14, color: theme.textSecondaryColor, height: 1.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Войти', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: accentColor), foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Зарегистрироваться', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

