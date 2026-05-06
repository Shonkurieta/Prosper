import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

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

  late AnimationController _animController;
  final TextEditingController _searchController = TextEditingController();

  // Color from the screenshot for accents
  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    adminService = AdminService(widget.token);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _searchController.addListener(_filterUsers);
    _loadUsers();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

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
        _showSnackBar('Ошибка загрузки: $e', Colors.redAccent);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _changeUserRole(int userId, String currentRole, String newRole) async {
    if (userId == widget.currentAdminId) {
      _showSnackBar("Вы не можете изменить свою роль", Colors.orange);
      return;
    }
    if (currentRole == newRole) return;

    try {
      await adminService.updateUserRole(userId, newRole);
      _loadUsers();
      _showSnackBar("Роль обновлена", accentColor);
    } catch (e) {
      _showSnackBar("Ошибка: $e", Colors.redAccent);
    }
  }

  Future<void> _deleteUser(int userId, String email) async {
    final theme = context.read<ThemeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить пользователя?', style: TextStyle(color: theme.textPrimaryColor)),
        content: Text('Вы уверены, что хотите удалить $email?', style: TextStyle(color: theme.textSecondaryColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Отмена', style: TextStyle(color: theme.textSecondaryColor))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Удалить', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await adminService.deleteUser(userId);
      _loadUsers();
      _showSnackBar('Пользователь удален', accentColor);
    } catch (e) {
      _showSnackBar('Ошибка удаления: $e', Colors.redAccent);
    }
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
                _buildHeader(theme),
                _buildSearchBar(theme),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Список пользователей',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: -0.5,
                      color: theme.textPrimaryColor,
                    ),
                  ),
                ),
                Expanded(
                  child: loading 
                    ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentColor)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return FadeTransition(
                            opacity: _animController,
                            child: SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
                                CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
                              ),
                              child: _buildUserCard(user, theme),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Text(
        'Пользователи',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1,
          color: theme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.5), width: 1),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: theme.textPrimaryColor),
          decoration: InputDecoration(
            hintText: 'Поиск по email или роли...',
            hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: theme.textPrimaryColor, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (val) => setState(() {}),
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user, ThemeProvider theme) {
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'USER';
    final isCurrentUser = user['id'] == widget.currentAdminId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                email.isNotEmpty ? email[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textPrimaryColor),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(fontSize: 12, color: theme.textSecondaryColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (!isCurrentUser) ...[
            _buildRolePicker(user['id'], role, theme),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: accentColor, size: 22),
              onPressed: () => _deleteUser(user['id'], email),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('ВЫ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor)),
            ),
        ],
      ),
    );
  }

  Widget _buildRolePicker(int userId, String currentRole, ThemeProvider theme) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert, color: theme.textSecondaryColor),
      color: theme.cardColor,
      onSelected: (val) => _changeUserRole(userId, currentRole, val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => ['USER', 'MODERATOR', 'ADMIN'].map((r) => PopupMenuItem(
        value: r,
        child: Text(r, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.textPrimaryColor)),
      )).toList(),
    );
  }
}
