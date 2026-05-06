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

  @override
  void initState() {
    super.initState();
    adminService = AdminService(widget.token);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
        _showSnackBar('Ошибка: $e', Colors.redAccent);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13, letterSpacing: 0.5)),
        backgroundColor: color.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  Future<void> _changeUserRole(int userId, String currentRole, String newRole) async {
    if (userId == widget.currentAdminId) {
      _showSnackBar("Нельзя изменить свою роль", Colors.grey);
      return;
    }
    if (currentRole == newRole) return;

    try {
      await adminService.updateUserRole(userId, newRole);
      _loadUsers();
      _showSnackBar("Роль: $newRole", Colors.black87);
    } catch (e) {
      _showSnackBar("Ошибка: $e", Colors.redAccent);
    }
  }

  Future<void> _deleteUser(int userId, String email) async {
    final theme = context.read<ThemeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        title: const Text('Удаление', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w300)),
        content: Text('Удалить $email?', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await adminService.deleteUser(userId);
      _loadUsers();
      _showSnackBar('Удалено', Colors.black87);
    } catch (e) {
      _showSnackBar('Ошибка: $e', Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: loading 
                ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          final curve = CurvedAnimation(
                            parent: _animController,
                            curve: Interval(index / (filteredUsers.length + 1).clamp(1, 100), 1.0, curve: Curves.easeOutQuart),
                          );
                          return Opacity(
                            opacity: curve.value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - curve.value)),
                              child: child,
                            ),
                          );
                        },
                        child: _buildUserTile(user, theme),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isSearching)
            const Text('USERS', style: TextStyle(fontSize: 14, letterSpacing: 4, fontWeight: FontWeight.w200))
          else
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'SEARCH', hintStyle: TextStyle(fontSize: 12, letterSpacing: 2), border: InputBorder.none),
                style: const TextStyle(fontSize: 14, letterSpacing: 1),
              ),
            ),
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search_rounded, size: 20, color: Colors.grey[400]),
            onPressed: () => setState(() => isSearching = !isSearching),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(dynamic user, ThemeProvider theme) {
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'USER';
    final isCurrentUser = user['id'] == widget.currentAdminId;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          _buildAvatar(email, role),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w300, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(role, style: TextStyle(fontSize: 10, letterSpacing: 1.5, color: _getRoleColor(role).withOpacity(0.7), fontWeight: FontWeight.w300)),
              ],
            ),
          ),
          if (!isCurrentUser) ...[
            _buildRoleMenu(user['id'], role, theme),
            IconButton(
              icon: Icon(Icons.remove_circle_outline_rounded, size: 16, color: Colors.grey[300]),
              onPressed: () => _deleteUser(user['id'], email),
            ),
          ] else
            Text('SELF', style: TextStyle(fontSize: 9, letterSpacing: 2, color: Colors.grey[300])),
        ],
      ),
    );
  }

  Widget _buildAvatar(String email, String role) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          email.isNotEmpty ? email[0].toUpperCase() : 'U', 
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w200, color: _getRoleColor(role))
        ),
      ),
    );
  }

  Widget _buildRoleMenu(int userId, String currentRole, ThemeProvider theme) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_horiz_rounded, size: 18, color: Colors.grey[350]),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      onSelected: (val) => _changeUserRole(userId, currentRole, val),
      itemBuilder: (context) => ['USER', 'MODERATOR', 'ADMIN'].map((r) => PopupMenuItem(
        value: r,
        child: Text(r, style: const TextStyle(fontSize: 11, letterSpacing: 1)),
      )).toList(),
    );
  }

  Color _getRoleColor(String role) {
    if (role == 'ADMIN') return Colors.black;
    if (role == 'MODERATOR') return Colors.orangeAccent;
    return Colors.grey;
  }
}
