import 'package:flutter/material.dart';
import '../../services/admin_service.dart';

class AdminUsersScreen extends StatefulWidget {
  final String token;

  const AdminUsersScreen({super.key, required this.token});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> with SingleTickerProviderStateMixin {
  late AdminService adminService;
  List<dynamic> users = [];
  bool loading = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    adminService = AdminService(widget.token);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadUsers();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => loading = true);
    try {
      final result = await adminService.getUsers();
      setState(() {
        users = result;
        loading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Ошибка: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(int userId, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Удалить пользователя?',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить пользователя "$email"?\nЭто действие нельзя отменить.',
          style: const TextStyle(color: Color(0xFF636E72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF636E72)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await adminService.deleteUser(userId);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Пользователь удалён'),
              ],
            ),
            backgroundColor: const Color(0xFF4ECDC4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  String _getInitial(String? email) {
    if (email == null || email.isEmpty) return 'U';
    return email[0].toUpperCase();
  }

  Color _getRoleColor(String? role) {
    if (role == 'ADMIN') {
      return const Color(0xFFFFE66D); // Yellow
    }
    return const Color(0xFF4ECDC4); // Cyan
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.people_outline,
                      color: Color(0xFF4ECDC4),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Пользователи',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${users.length} пользователей',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF636E72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4ECDC4),
                        strokeWidth: 2.5,
                      ),
                    )
                  : users.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadUsers,
                          color: const Color(0xFF4ECDC4),
                          backgroundColor: Colors.white,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              return TweenAnimationBuilder(
                                duration: Duration(milliseconds: 300 + (index * 50)),
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, double value, child) {
                                  return Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: Opacity(
                                      opacity: value,
                                      child: _buildUserCard(users[index]),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  Widget _buildUserCard(dynamic user) {
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'USER';
    final isAdmin = role == 'ADMIN';

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getRoleColor(role).withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  _getInitial(email),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(role),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D3436),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(role).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isAdmin 
                              ? Icons.admin_panel_settings_rounded 
                              : Icons.person_rounded,
                          size: 14,
                          color: _getRoleColor(role),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAdmin ? 'Администратор' : 'Пользователь',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getRoleColor(role),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Delete button
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFFF6B6B),
                  size: 20,
                ),
              ),
              tooltip: 'Удалить пользователя',
              onPressed: () => _deleteUser(user['id'], email),
            ),
          ],
        ),
      ),
    );
  }
}