import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AdminUsersScreen extends StatefulWidget {
  final String token;
  final String currentAdminEmail;
  final int currentAdminId;
  const AdminUsersScreen({super.key, required this.token, required this.currentAdminEmail, required this.currentAdminId});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late AdminService adminService;
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  bool loading = true;
  bool isSearching = false;
  String _currentAdminRole = 'USER'; // Default to USER
  String _currentAdminEmail = '';
  int _currentAdminId = -1;
  late AnimationController _animController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    adminService = AdminService(widget.token);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _searchController.addListener(_filterUsers);
    _loadCurrentAdminData();
    _loadUsers();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Фильтрует filteredUsers, оригинальный users не трогает
  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredUsers = users;
      } else {
        filteredUsers = users.where((user) {
          final email = (user['email'] ?? '').toLowerCase();
          final role = (user['role'] ?? '').toLowerCase();
          return email.contains(query) || role.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadCurrentAdminData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentAdminEmail = prefs.getString('email') ?? '';
      _currentAdminRole = prefs.getString('role') ?? 'USER';
      _currentAdminId = prefs.getInt('id') ?? -1; // Assuming 'id' is stored in SharedPreferences
    });
  }

  Future<void> _loadUsers() async {
    setState(() => loading = true);
    try {
      final result = await adminService.getUsers();
      setState(() {
        users = result;
        filteredUsers = result;
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
                Expanded(child: Text('Ошибка загрузки: $e')),
              ],
            ),
            backgroundColor: theme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _changeUserRole(int userId, String currentRole, String newRole) async {
    if (userId == widget.currentAdminId) {
      if (mounted) {
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Text("Вы не можете изменить свою собственную роль."),
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
      return;
    }

    if (currentRole == newRole) return; // No change needed

    try {
      await adminService.updateUserRole(userId, newRole);
      _loadUsers();
      if (mounted) {
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text("Роль пользователя обновлена до $newRole"),
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
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ошибка обновления роли: $e"),
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
        final theme = context.read<ThemeProvider>();
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
            backgroundColor: theme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
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
    if (role == 'ADMIN') return theme.warningColor;
    if (role == 'MODERATOR') return Colors.orange;
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
                      // ✅ Иконка скрывается во время поиска, как в AdminBooksScreen
                      if (!isSearching) ...[
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
                      ],
                      Expanded(
                        // ✅ Переключаемся между полем поиска и заголовком
                        child: isSearching
                            ? _buildSearchField(theme)
                            : Column(
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
                                    'Всего ${users.length} пользователей',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      // ✅ Кнопка toggle поиска
                      Container(
                        decoration: BoxDecoration(
                          color: isSearching
                              ? theme.primaryColor.withValues(alpha: 0.15)
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Icon(
                            isSearching ? Icons.close : Icons.search,
                            color: isSearching
                                ? theme.primaryColor
                                : theme.textSecondaryColor,
                          ),
                          onPressed: () {
                            setState(() {
                              isSearching = !isSearching;
                              if (!isSearching) {
                                _searchController.clear();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ Счётчик результатов поиска, как в AdminBooksScreen
                if (isSearching && _searchController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Найдено: ${filteredUsers.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textSecondaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Content
                Expanded(
                  child: loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                            strokeWidth: 2.5,
                          ),
                        )
                      // ✅ filteredUsers вместо users
                      : filteredUsers.isEmpty
                          ? _buildEmptyState(theme)
                          : RefreshIndicator(
                              onRefresh: _loadUsers,
                              color: theme.primaryColor,
                              backgroundColor: theme.cardColor,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                itemCount: filteredUsers.length,
                                itemBuilder: (context, index) {
                                  return TweenAnimationBuilder(
                                    duration: Duration(
                                        milliseconds: 300 + (index * 50)),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    builder:
                                        (context, double value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, 20 * (1 - value)),
                                        child: Opacity(
                                          opacity: value,
                                          child: _buildUserCard(
                                              filteredUsers[index], theme),
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

  // ✅ Вынесен в отдельный метод, как в AdminBooksScreen
  Widget _buildSearchField(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(
          color: theme.textPrimaryColor,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: 'Поиск по email или роли...',
          hintStyle: TextStyle(
            color: theme.textSecondaryColor.withValues(alpha: 0.5),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: theme.textSecondaryColor,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: theme.textSecondaryColor,
                  ),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    final isFiltering = _searchController.text.isNotEmpty;

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
              isFiltering ? Icons.search_off : Icons.people_outline,
              size: 80,
              color: theme.textSecondaryColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFiltering ? 'Ничего не найдено' : 'Нет пользователей',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltering
                ? 'Попробуйте изменить запрос'
                : 'Пользователи появятся здесь',
            style: TextStyle(
              fontSize: 15,
              color: theme.textSecondaryColor,
            ),
          ),
          // ✅ Кнопка сброса поиска, как в AdminBooksScreen
          if (isFiltering) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _searchController.clear(),
              icon: Icon(Icons.clear, color: theme.primaryColor),
              label: Text(
                'Очистить поиск',
                style: TextStyle(color: theme.primaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user, ThemeProvider theme) {
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'USER';
    final isAdmin = role == 'ADMIN';
    final isModerator = role == 'MODERATOR';
    final isCurrentUser = user['id'] == widget.currentAdminId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: theme.getCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getRoleColor(role, theme).withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  _getInitial(email),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(role, theme),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_rounded
                            : (isModerator ? Icons.verified_user_rounded : Icons.person_rounded),
                        size: 12,
                        color: _getRoleColor(role, theme),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAdmin ? 'Admin' : (isModerator ? 'Moderator' : 'User'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getRoleColor(role, theme),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Role dropdown
            if (!isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: role,
                    isDense: true,
                    items: <String>['USER', 'MODERATOR', 'ADMIN'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value, 
                          style: TextStyle(
                            color: theme.textPrimaryColor,
                            fontSize: 12,
                          )
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        _changeUserRole(user['id'], role, newValue);
                      }
                    },
                    dropdownColor: theme.cardColor,
                    icon: Icon(Icons.arrow_drop_down, size: 18, color: theme.textSecondaryColor),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRoleColor(role, theme).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ВЫ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getRoleColor(role, theme),
                  ),
                ),
              ),

            const SizedBox(width: 4),

            // Delete button
            if (!isCurrentUser)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: theme.errorColor,
                    size: 18,
                  ),
                ),
                tooltip: 'Удалить',
                onPressed: () => _deleteUser(user['id'], email),
              ),
          ],
        ),
      ),
    );
  }
}
