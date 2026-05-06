import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class AdminUsersScreen extends StatefulWidget {
  final String token;
  final String currentAdminEmail;
  final int currentAdminId;

  const AdminUsersScreen({
    super.key,
    required this.token,
    required this.currentAdminEmail,
    required this.currentAdminId,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late AdminService adminService;
  List<dynamic> users = [];
  List<dynamic> filteredUsers = [];
  bool loading = true;

  late AnimationController _animController;
  final TextEditingController _searchController = TextEditingController();

  static const Color accentColor = Color(0xFFD46A4F);

  // Role colors
  static const Map<String, Color> _roleColors = {
    'ADMIN': Color(0xFFD46A4F),
    'MODERATOR': Color(0xFF5B8CDB),
    'USER': Color(0xFF6BAF7A),
  };

  @override
  void initState() {
    super.initState();
    adminService = AdminService(widget.token);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
      if (mounted) _showSnackBar('Ошибка загрузки: $e', Colors.redAccent);
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
      _showSnackBar('Вы не можете изменить свою роль', Colors.orange);
      return;
    }
    if (currentRole == newRole) return;
    try {
      await adminService.updateUserRole(userId, newRole);
      _loadUsers();
      _showSnackBar('Роль обновлена', accentColor);
    } catch (e) {
      _showSnackBar('Ошибка: $e', Colors.redAccent);
    }
  }

  Future<void> _deleteUser(int userId, String email) async {
    final theme = context.read<ThemeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Удалить пользователя?',
            style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.w800)),
        content: Text(
          'Вы уверены, что хотите удалить\n$email?',
          style: TextStyle(color: theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondaryColor)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await adminService.deleteUser(userId);
      _loadUsers();
      _showSnackBar('Пользователь удалён', accentColor);
    } catch (e) {
      _showSnackBar('Ошибка удаления: $e', Colors.redAccent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                const SizedBox(height: 16),
                _buildSearchBar(theme),
                const SizedBox(height: 20),
                _buildListLabel(theme),
                const SizedBox(height: 8),
                Expanded(child: _buildList(theme)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              'Пользователи',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: theme.textPrimaryColor,
              ),
            ),
          ),
          // Total count badge
          if (!loading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${filteredUsers.length}',
                style: const TextStyle(
                  color: accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withOpacity(0.2)),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Поиск по email или роли...',
            hintStyle: TextStyle(
              color: theme.textSecondaryColor.withOpacity(0.5),
              fontSize: 14,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: accentColor, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: theme.textSecondaryColor),
                    onPressed: () {
                      _searchController.clear();
                      _filterUsers();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildListLabel(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Все аккаунты',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: theme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ThemeProvider theme) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
        ),
      );
    }

    if (filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: theme.textSecondaryColor.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'Пользователи не найдены',
              style: TextStyle(color: theme.textSecondaryColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: filteredUsers.length,
      itemBuilder: (context, index) {
        final delay = (index * 60).clamp(0, 400);
        return AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final delayedValue = (((_animController.value * 600) - delay) / 200)
                .clamp(0.0, 1.0);
            return Opacity(
              opacity: delayedValue,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - delayedValue)),
                child: child,
              ),
            );
          },
          child: _buildUserCard(filteredUsers[index], theme),
        );
      },
    );
  }

  Widget _buildUserCard(dynamic user, ThemeProvider theme) {
    final email = user['email'] ?? '';
    final role = (user['role'] ?? 'USER') as String;
    final userId = user['id'] as int;
    final isCurrentUser = userId == widget.currentAdminId;
    final roleColor = _roleColors[role] ?? accentColor;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: roleColor.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [roleColor.withOpacity(0.5), roleColor.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ВЫ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            if (!isCurrentUser) ...[
              _buildRolePicker(userId, role, theme),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _deleteUser(userId, email),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRolePicker(int userId, String currentRole, ThemeProvider theme) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      color: theme.cardColor,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 8),
      onSelected: (val) => _changeUserRole(userId, currentRole, val),
      itemBuilder: (context) => ['USER', 'MODERATOR', 'ADMIN'].map((r) {
        final rColor = _roleColors[r] ?? accentColor;
        final isSelected = r == currentRole;
        return PopupMenuItem(
          value: r,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? rColor : rColor.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                r,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? rColor : theme.textPrimaryColor,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Icon(Icons.check_rounded, size: 16, color: rColor),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.tune_rounded, color: accentColor, size: 18),
      ),
    );
  }
}