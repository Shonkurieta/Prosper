import 'package:flutter/material.dart';
import 'package:prosper/screens/admin/manage_books_screen.dart';
import 'package:prosper/screens/admin/manage_users_screen.dart';
import 'package:prosper/screens/profile/profile_screen.dart';

class AdminHome extends StatefulWidget {
  final String token;
  const AdminHome({super.key, required this.token});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animController;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _screens = [
      ManageBooksScreen(token: widget.token),
      ManageUsersScreen(token: widget.token),
      ProfileScreen(token: widget.token),
    ];
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: FadeTransition(
        opacity: _animController,
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: const Color(0xFFE0E5EC),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
                  icon: Icons.menu_book_rounded,
                  label: 'Книги',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.people_outline,
                  label: 'Пользователи',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.person_outline,
                  label: 'Профиль',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
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
                ? const Color(0xFF4ECDC4).withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected 
                    ? const Color(0xFF4ECDC4)
                    : const Color(0xFF636E72),
                size: 26,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? const Color(0xFF4ECDC4)
                      : const Color(0xFF636E72),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}