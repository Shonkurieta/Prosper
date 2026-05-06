import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_novells_screen.dart';
import 'admin_users_screen.dart';
import 'admin_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class AdminMainScreen extends StatefulWidget {
  final String token;
  final String role;

  const AdminMainScreen({super.key, required this.token, required this.role});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animController;
  late List<Widget> _screens = [];
  String _currentAdminEmail = '';
  int _currentAdminId = -1;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadCurrentAdminData().then((_) {
      if (mounted) {
        setState(() {
          _screens = [
            AdminNovellScreen(token: widget.token, role: widget.role),
            if (widget.role == 'ADMIN') 
              AdminUsersScreen(
                token: widget.token, 
                currentAdminEmail: _currentAdminEmail, 
                currentAdminId: _currentAdminId
              ),
            AdminProfileScreen(token: widget.token, role: widget.role),
          ];
        });
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentAdminEmail = prefs.getString('email') ?? '';
    _currentAdminId = prefs.getInt('id') ?? -1;
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
      _animController.reset();
      _animController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: _screens.isNotEmpty 
          ? FadeTransition(
              opacity: _animController,
              child: _screens[_selectedIndex],
            )
          : const Center(child: CircularProgressIndicator(color: accentColor)),
      bottomNavigationBar: _buildBottomBar(theme),
    );
  }

  Widget _buildBottomBar(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: theme.isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                theme: theme,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Главная',
                index: 0,
              ),
              if (widget.role == 'ADMIN')
                _buildNavItem(
                  theme: theme,
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  label: 'Пользователи',
                  index: 1,
                ),
              _buildNavItem(
                theme: theme,
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Профиль',
                index: widget.role == 'ADMIN' ? 2 : 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required ThemeProvider theme,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    // Используем accentColor для активного состояния, и основной цвет текста для пассивного
    final color = isSelected ? accentColor : theme.textPrimaryColor;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 28, // Чуть больше размер, как на картинке
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
