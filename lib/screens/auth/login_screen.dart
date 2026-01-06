import 'package:prosper/screens/admin/admin_main_screen.dart';
import 'package:flutter/material.dart';
import 'package:prosper/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prosper/screens/user/user_home.dart';
import 'package:prosper/screens/admin/admin_home.dart';
import 'package:prosper/screens/auth/register_screen.dart';

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
    _testConnection();
  }

  Future<void> _testConnection() async {
    final isConnected = await _authService.testConnection();
    if (!mounted) return;
    
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Не удается подключиться к серверу'),
            ],
          ),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      final response = await _authService.login(username, password);

      final token = response['token']?.toString() ?? '';
      final role = response['role']?.toString() ?? 'USER';
      final usernameFromServer = response['username']?.toString() ?? '';
      final email = response['email']?.toString() ?? '';

      if (token.isEmpty) throw Exception('Токен не получен от сервера');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      await prefs.setString('role', role);
      await prefs.setString('username', usernameFromServer);
      await prefs.setString('email', email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Добро пожаловать, $usernameFromServer!'),
            ],
          ),
          backgroundColor: const Color(0xFF4ECDC4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ),
      );

      Widget homeScreen = role == 'ADMIN' 
          ? AdminMainScreen(token: token)
          : UserHome(token: token);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => homeScreen),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      
      String errorMessage = e.toString().replaceAll('Exception:', '').trim();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: const Color(0xFFFF6B6B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // Decorative background shapes
          Positioned(
            top: -size.height * 0.15,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.1,
            left: -size.width * 0.25,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFE66D).withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.3,
            left: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
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
                          // Simple icon without container
                          Center(
                            child: TweenAnimationBuilder(
                              duration: const Duration(milliseconds: 1200),
                              tween: Tween<double>(begin: 0, end: 1),
                              builder: (context, double value, child) {
                                return Transform.rotate(
                                  angle: value * 0.1,
                                  child: Icon(
                                    Icons.menu_book_rounded,
                                    size: 80,
                                    color: Color.lerp(
                                      const Color(0xFF4ECDC4),
                                      const Color(0xFF44A08D),
                                      value,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Title - left aligned
                          const Text(
                            'Вход',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2D3436),
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Войдите, чтобы продолжить',
                            style: TextStyle(
                              fontSize: 17,
                              color: Color(0xFF636E72),
                              fontWeight: FontWeight.w400,
                            ),
                          ),

                          const SizedBox(height: 48),

                          // Username field
                          _buildMinimalTextField(
                            controller: _usernameController,
                            label: 'Email или имя пользователя',
                            hint: 'Введите ваш email',
                            icon: Icons.alternate_email,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Введите email или имя пользователя';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // Password field
                          _buildMinimalTextField(
                            controller: _passwordController,
                            label: 'Пароль',
                            hint: 'Введите ваш пароль',
                            icon: Icons.lock_open,
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword 
                                    ? Icons.visibility_off_outlined 
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF636E72),
                                size: 22,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Введите пароль';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 40),

                          // Login button - full width solid color
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4ECDC4),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                disabledBackgroundColor: const Color(0xFF4ECDC4).withValues(alpha: 0.6),
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
                                      'Войти',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Register link - centered
                          Center(
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              child: const Text(
                                'Нет аккаунта? Зарегистрироваться',
                                style: TextStyle(
                                  color: Color(0xFF636E72),
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
  }

  Widget _buildMinimalTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(
              color: Color(0xFF2D3436),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF636E72).withValues(alpha: 0.5),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF4ECDC4),
                size: 22,
              ),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF4ECDC4),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFF6B6B),
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFF6B6B),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              errorStyle: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}