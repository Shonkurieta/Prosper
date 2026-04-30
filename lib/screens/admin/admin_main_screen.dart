
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_books_screen.dart';
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
  late List<Widget> _screens = []; // Initialize with an empty list
  String _currentAdminEmail = '';
  int _currentAdminId = -1;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadCurrentAdminData().then((_) {
      setState(() {
        _screens = [
          AdminBooksScreen(token: widget.token, role: widget.role),
          if (widget.role == 'ADMIN') AdminUsersScreen(token: widget.token, currentAdminEmail: _currentAdminEmail, currentAdminId: _currentAdminId),
          AdminProfileScreen(token: widget.token, role: widget.role),
        ];
      });
      _animController.forward();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentAdminEmail = prefs.getString('email') ?? '';
      _currentAdminId = prefs.getInt('id') ?? -1;
    });
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
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: FadeTransition(
            opacity: _animController,
            child: _screens.isNotEmpty ? _screens[_selectedIndex] : const Center(child: CircularProgressIndicator()), // Handle empty _screens initially
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(
                top: BorderSide(
                  color: theme.borderColor,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor,
                  blurRadius: 20,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      theme: theme,
                      icon: Icons.menu_book_rounded,
                      label: 'Новеллы',
                      index: 0,
                    ),
                    if (widget.role == 'ADMIN')
                      _buildNavItem(
                        theme: theme,
                        icon: Icons.people_outline,
                        label: 'Пользователи',
                        index: 1,
                      ),
                    _buildNavItem(
                      theme: theme,
                      icon: Icons.person_outline,
                      label: 'Профиль',
                      index: widget.role == 'ADMIN' ? 2 : 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required ThemeProvider theme,
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? theme.primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? theme.primaryColor
                    : theme.textSecondaryColor,
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? theme.primaryColor
                      : theme.textSecondaryColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
