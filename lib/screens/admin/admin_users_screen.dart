import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

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
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Ошибка: $e')),
              ],
            ),
            backgroundColor: theme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(int userId, String email) async {
    final theme = context.read<ThemeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Удалить пользователя?',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить пользователя "$email"?\nЭто действие нельзя отменить.',
          style: TextStyle(color: theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Отмена',
              style: TextStyle(color: theme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.errorColor,
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
            backgroundColor: theme.successColor,
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
            backgroundColor: theme.errorColor,
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

  Color _getRoleColor(String? role, ThemeProvider theme) {
    if (role == 'ADMIN') {
      return theme.warningColor;
    }
    return theme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
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
                          color: theme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.people_outline,
                          color: theme.primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Пользователи',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: theme.textPrimaryColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '${users.length} пользователей',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textSecondaryColor,
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
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                            strokeWidth: 2.5,
                          ),
                        )
                      : users.isEmpty
                          ? _buildEmptyState(theme)
                          : RefreshIndicator(
                              onRefresh: _loadUsers,
                              color: theme.primaryColor,
                              backgroundColor: theme.cardColor,
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
                                          child: _buildUserCard(users[index], theme),
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
      },
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.people_outline,
              size: 80,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Нет пользователей',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user, ThemeProvider theme) {
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'USER';
    final isAdmin = role == 'ADMIN';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: theme.getCardDecoration(),
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
                color: _getRoleColor(role, theme).withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  _getInitial(email),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(role, theme),
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimaryColor,
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
                      color: _getRoleColor(role, theme).withValues(alpha: 0.15),
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
                          color: _getRoleColor(role, theme),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isAdmin ? 'Администратор' : 'Пользователь',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getRoleColor(role, theme),
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
                  color: theme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: theme.errorColor,
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