import 'package:prosper/screens/admin/admin_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:prosper/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prosper/screens/user/user_home.dart';
import 'package:prosper/screens/auth/register_screen.dart';
import 'package:prosper/screens/auth/forgot_password_screen.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/notification_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthResponse(Map<String, dynamic> response) async {
    final token = response['token']?.toString() ?? '';
    final role = response['role']?.toString() ?? 'USER';
    final usernameFromServer = response['username']?.toString() ?? '';
    final email = response['email']?.toString() ?? '';
    final id = response['id'] as int? ?? -1;

    if (token.isEmpty) throw Exception('Токен не получен от сервера');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('role', role);
    await prefs.setString('username', usernameFromServer);
    await prefs.setString('email', email);
    await prefs.setInt('id', id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Добро пожаловать, $usernameFromServer!'),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );

    Widget nextScreen = (role == 'ADMIN' || role == 'MODERATOR')
        ? AdminMainScreen(token: token, role: role)
        : UserHome(token: token);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => nextScreen),
      (route) => false,
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );
      await _handleAuthResponse(response);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final response = await _authService.loginWithGoogle();
      await _handleAuthResponse(response);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(dynamic e) {
    if (!mounted) return;
    final theme = context.read<ThemeProvider>();
    String errorMessage = e.toString().replaceAll('Exception:', '').trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: theme.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(theme),
                      const SizedBox(height: 48),
                      _buildTextField(
                        theme: theme,
                        controller: _usernameController,
                        label: 'Имя пользователя',
                        icon: Icons.person_outline_rounded,
                        hint: 'Введите ваш логин',
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        theme: theme,
                        controller: _passwordController,
                        label: 'Пароль',
                        icon: Icons.lock_outline_rounded,
                        hint: 'Введите ваш пароль',
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      const SizedBox(height: 40),
                      _buildLoginButton(theme),
                      const SizedBox(height: 16),
                      _buildGoogleLoginButton(theme),
                      const SizedBox(height: 16),
                      _buildForgotPasswordLink(theme),
                      const SizedBox(height: 24),
                      _buildRegisterLink(theme),
                      const SizedBox(height: 16),
                      _buildGuestButton(theme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleLoginButton(ThemeProvider theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _loginWithGoogle,
        icon: const Icon(Icons.g_mobiledata, size: 32, color: accentColor),
        label: const Text(
          'Войти через Google',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: accentColor),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: accentColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordLink(ThemeProvider theme) {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
        ),
        child: Text(
          'Забыли пароль?',
          style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.auto_stories_rounded, color: accentColor, size: 32),
        ),
        const SizedBox(height: 24),
        Text(
          'С возвращением',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: theme.textPrimaryColor,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Войдите в свой аккаунт Prosper',
          style: TextStyle(
            fontSize: 16,
            color: theme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required ThemeProvider theme,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: theme.textPrimaryColor.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(color: theme.textPrimaryColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontSize: 14),
              prefixIcon: Icon(icon, color: accentColor, size: 22),
              suffixIcon: isPassword 
                ? IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: theme.textSecondaryColor.withOpacity(0.5),
                      size: 20,
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) => value == null || value.isEmpty ? 'Заполните это поле' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(ThemeProvider theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Войти',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }

  Widget _buildRegisterLink(ThemeProvider theme) {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
        child: RichText(
          text: TextSpan(
            text: 'Нет аккаунта? ',
            style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
            children: const [
              TextSpan(
                text: 'Зарегистрироваться',
                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestButton(ThemeProvider theme) {
    return Center(
      child: TextButton(
        onPressed: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UserHome(token: '')),
            (route) => false,
          );
        },
        child: Text(
          'Читать без регистрации',
          style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
        ),
      ),
    );
  }
}
