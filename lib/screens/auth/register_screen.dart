import 'package:flutter/material.dart';
import 'package:prosper/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prosper/screens/user/user_home.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Пароли не совпадают');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final response = await _authService.register(username, email, password);

      final token = response['token']?.toString() ?? '';
      final role = response['role']?.toString() ?? 'USER';
      final usernameFromServer = response['username']?.toString() ?? '';
      final emailFromServer = response['email']?.toString() ?? '';
      final id = response['id'] as int? ?? -1;

      if (token.isEmpty) throw Exception('Токен не получен от сервера');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('role', role);
      await prefs.setString('username', usernameFromServer);
      await prefs.setString('email', emailFromServer);
      await prefs.setInt('id', id);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => UserHome(token: token)),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Ошибка регистрации: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final theme = context.read<ThemeProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
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
                      const SizedBox(height: 32),
                      _buildTextField(
                        theme: theme,
                        controller: _usernameController,
                        label: 'Имя пользователя',
                        icon: Icons.person_outline_rounded,
                        hint: 'Как вас называть?',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        theme: theme,
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        hint: 'example@mail.com',
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        theme: theme,
                        controller: _passwordController,
                        label: 'Пароль',
                        icon: Icons.lock_outline_rounded,
                        hint: 'Минимум 6 символов',
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        theme: theme,
                        controller: _confirmPasswordController,
                        label: 'Подтверждение пароля',
                        icon: Icons.lock_clock_outlined,
                        hint: 'Повторите пароль',
                        isPassword: true,
                        obscureText: _obscurePassword,
                      ),
                      const SizedBox(height: 32),
                      _buildRegisterButton(theme),
                      const SizedBox(height: 24),
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

  Widget _buildHeader(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Регистрация',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: theme.textPrimaryColor,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Создайте аккаунт, чтобы начать читать',
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
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(color: theme.textPrimaryColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontSize: 14),
              prefixIcon: Icon(icon, color: accentColor, size: 22),
              suffixIcon: isPassword && onTogglePassword != null
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

  Widget _buildRegisterButton(ThemeProvider theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
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
                'Создать аккаунт',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
      ),
    );
  }
}
