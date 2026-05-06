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

  // Colors from the screenshot
  static const Color accentColor = Color(0xFFD46A4F); // The orange/coral from the screenshot
  static const Color lightGrey = Color(0xFFF5F5F5);

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
        title: const Text('Удалить пользователя?'),
        content: Text('Вы уверены, что хотите удалить $email?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
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
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: Colors.white, // Match screenshot background
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'Список пользователей',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
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

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Text(
        'Пользователи',
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.5), width: 1),
        ),
        child: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Поиск по email или роли...',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.black, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // No heavy shadows, just a clean look
      ),
      child: Row(
        children: [
          // Avatar Style
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: lightGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                email.isNotEmpty ? email[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
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
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (!isCurrentUser) ...[
            _buildRolePicker(user['id'], role),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: accentColor, size: 22),
              onPressed: () => _deleteUser(user['id'], email),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('ВЫ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor)),
            ),
        ],
      ),
    );
  }

  Widget _buildRolePicker(int userId, String currentRole) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert, color: Colors.black54),
      onSelected: (val) => _changeUserRole(userId, currentRole, val),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => ['USER', 'MODERATOR', 'ADMIN'].map((r) => PopupMenuItem(
        value: r,
        child: Text(r, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      )).toList(),
    );
  }
}
