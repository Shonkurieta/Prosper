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
  bool _obscureConfirmPassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final response = await _authService.register(username, email, password);

      final token = response['token']?.toString() ?? '';
      final role = response['role']?.toString() ?? 'USER';

      if (token.isEmpty) throw Exception('Токен не получен от сервера');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('role', role);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => UserHome(token: token)),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      final theme = context.read<ThemeProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Ошибка регистрации: ${e.toString()}')),
            ],
          ),
          backgroundColor: theme.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: Stack(
            children: [
              // Decorative background shapes
              Positioned(
                top: -size.height * 0.15,
                left: -size.width * 0.2,
                child: Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle2,
                  ),
                ),
              ),
              Positioned(
                bottom: -size.height * 0.1,
                right: -size.width * 0.25,
                child: Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle1,
                  ),
                ),
              ),
              Positioned(
                top: size.height * 0.25,
                right: -30,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle3,
                  ),
                ),
              ),
              
              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Back button and theme toggle
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [theme.cardShadow],
                                    ),
                                    child: IconButton(
                                      onPressed: () => Navigator.pop(context),
                                      icon: Icon(
                                        Icons.arrow_back_ios_new,
                                        color: theme.primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [theme.cardShadow],
                                    ),
                                    child: IconButton(
                                      onPressed: () async {
                                        await theme.toggleTheme();
                                      },
                                      icon: Icon(
                                        theme.isDarkMode 
                                            ? Icons.light_mode_outlined 
                                            : Icons.dark_mode_outlined,
                                        color: theme.primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // Icon
                              Center(
                                child: TweenAnimationBuilder(
                                  duration: const Duration(milliseconds: 1200),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Transform.rotate(
                                      angle: value * 0.1,
                                      child: Icon(
                                        Icons.person_add_rounded,
                                        size: 72,
                                        color: theme.primaryColor,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Title
                              Text(
                                'Регистрация',
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w900,
                                  color: theme.textPrimaryColor,
                                  height: 1.1,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Создайте новый аккаунт',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: theme.textSecondaryColor,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Username field
                              _buildMinimalTextField(
                                theme: theme,
                                controller: _usernameController,
                                label: 'Имя пользователя',
                                hint: 'Введите имя пользователя',
                                icon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите имя пользователя';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'Минимум 3 символа';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Email field
                              _buildMinimalTextField(
                                theme: theme,
                                controller: _emailController,
                                label: 'Email',
                                hint: 'Введите ваш email',
                                icon: Icons.alternate_email,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите email';
                                  }
                                  if (!value.trim().contains('@')) {
                                    return 'Введите корректный email';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Password field
                              _buildMinimalTextField(
                                theme: theme,
                                controller: _passwordController,
                                label: 'Пароль',
                                hint: 'Минимум 8 символов',
                                icon: Icons.lock_open,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword 
                                        ? Icons.visibility_off_outlined 
                                        : Icons.visibility_outlined,
                                    color: theme.textSecondaryColor,
                                    size: 22,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Введите пароль';
                                  }
                                  if (value.trim().length < 8) {
                                    return 'Минимум 8 символов';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Confirm Password field
                              _buildMinimalTextField(
                                theme: theme,
                                controller: _confirmPasswordController,
                                label: 'Подтвердите пароль',
                                hint: 'Введите пароль еще раз',
                                icon: Icons.lock_clock_outlined,
                                obscureText: _obscureConfirmPassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword 
                                        ? Icons.visibility_off_outlined 
                                        : Icons.visibility_outlined,
                                    color: theme.textSecondaryColor,
                                    size: 22,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Подтвердите пароль';
                                  }
                                  if (value.trim() != _passwordController.text.trim()) {
                                    return 'Пароли не совпадают';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 40),

                              // Register button
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _register,
                                  style: theme.getPrimaryButtonStyle().copyWith(
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(vertical: 18),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Зарегистрироваться',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Login link
                              Center(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  child: Text(
                                    'Уже есть аккаунт? Войти',
                                    style: TextStyle(
                                      color: theme.textSecondaryColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMinimalTextField({
    required ThemeProvider theme,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textPrimaryColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: theme.isDarkMode 
                ? Border.all(color: theme.borderColor, width: 1.5)
                : null,
            boxShadow: [theme.cardShadow],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: TextStyle(
              color: theme.textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: theme.getInputDecoration(
              hintText: hint,
              prefixIcon: icon,
              suffixIcon: suffixIcon,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}