import 'package:flutter/material.dart';
import 'package:prosper/services/user_service.dart';

class ManageUsersScreen extends StatefulWidget {
  final String token;

  const ManageUsersScreen({super.key, required this.token});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> with SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  List<dynamic> _users = [];
  bool _isLoading = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _loadUsers();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userService.fetchUsers(widget.token);
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        _showSnackBar('Ошибка загрузки: $e', isError: true);
      }
    }
  }

  Future<void> _deleteUser(int userId, String username) async {
    try {
      await _userService.deleteUser(widget.token, userId);
      await _loadUsers();
      if (mounted) {
        _showSnackBar('Пользователь "$username" удалён');
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Ошибка удаления: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFFF6B6B) : const Color(0xFF4ECDC4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showDeleteDialog(int userId, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Удалить пользователя?',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить пользователя "$username"?',
          style: const TextStyle(color: Color(0xFF636E72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF636E72)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(userId, username);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF4ECDC4),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Управление',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        const Text(
                          'Пользователи системы',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF636E72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Индикатор количества
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_users.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Список пользователей
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4ECDC4),
                      ),
                    )
                  : _users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                                ),
                                child: const Icon(
                                  Icons.people_outline,
                                  size: 80,
                                  color: Color(0xFF4ECDC4),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Нет пользователей',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3436),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: RefreshIndicator(
                            onRefresh: _loadUsers,
                            color: const Color(0xFF4ECDC4),
                            backgroundColor: Colors.white,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _users.length,
                              itemBuilder: (context, index) {
                                final user = _users[index];
                                final userId = user['id'] is int
                                    ? user['id'] as int
                                    : int.parse(user['id'].toString());
                                final username = user['username'] ?? 'Без имени';
                                final email = user['email'] ?? '';
                                final role = user['role'] ?? 'USER';

                                return TweenAnimationBuilder(
                                  duration: Duration(milliseconds: 300 + (index * 50)),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 20 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      leading: Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: role == 'ADMIN'
                                              ? const Color(0xFFFF6B6B).withValues(alpha: 0.15)
                                              : const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                                        ),
                                        child: Icon(
                                          role == 'ADMIN'
                                              ? Icons.admin_panel_settings
                                              : Icons.person,
                                          color: role == 'ADMIN'
                                              ? const Color(0xFFFF6B6B)
                                              : const Color(0xFF4ECDC4),
                                        ),
                                      ),
                                      title: Text(
                                        username,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2D3436),
                                          fontSize: 16,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Text(
                                            email,
                                            style: const TextStyle(
                                              color: Color(0xFF636E72),
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: role == 'ADMIN'
                                                  ? const Color(0xFFFF6B6B).withValues(alpha: 0.15)
                                                  : const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: role == 'ADMIN'
                                                    ? const Color(0xFFFF6B6B).withValues(alpha: 0.3)
                                                    : const Color(0xFF4ECDC4).withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              role,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: role == 'ADMIN'
                                                    ? const Color(0xFFFF6B6B)
                                                    : const Color(0xFF4ECDC4),
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: role != 'ADMIN'
                                          ? IconButton(
                                              icon: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                                                ),
                                                child: const Icon(
                                                  Icons.delete_outline,
                                                  color: Color(0xFFFF6B6B),
                                                  size: 20,
                                                ),
                                              ),
                                              onPressed: () => _showDeleteDialog(userId, username),
                                            )
                                          : const Icon(
                                              Icons.lock_outline,
                                              color: Color(0xFF636E72),
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}