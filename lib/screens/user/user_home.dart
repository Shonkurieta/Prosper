import 'package:flutter/material.dart';
import 'package:prosper/screens/home/home_screen.dart';
import 'package:prosper/screens/profile/profile_screen.dart';

class UserHome extends StatefulWidget {
  final String token;
  const UserHome({super.key, required this.token});

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(token: widget.token),
      ProfileScreen(token: widget.token),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          // Декоративные элементы фона
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4ECDC4).withValues(alpha: 0.08),
                    const Color(0xFF4ECDC4).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFE66D).withValues(alpha: 0.1),
                    const Color(0xFFFFE66D).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          
          // Основной контент
          screens[_selectedIndex],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.05),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildModernNavItem(
                    icon: Icons.library_books_outlined,
                    activeIcon: Icons.library_books_rounded,
                    label: 'Каталог',
                    index: 0,
                  ),
                  Container(
                    width: 1,
                    height: 35,
                    color: const Color(0xFF636E72).withValues(alpha: 0.1),
                  ),
                  _buildModernNavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Профиль',
                    index: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedIndex = index);
          _animController.forward(from: 0);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                      const Color(0xFF44A08D).withValues(alpha: 0.1),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.95,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected 
                      ? const Color(0xFF4ECDC4)
                      : const Color(0xFF636E72).withValues(alpha: 0.6),
                  size: 24,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected 
                        ? const Color(0xFF2D3436)
                        : const Color(0xFF636E72).withValues(alpha: 0.7),
                    letterSpacing: 0.2,
                  ),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}