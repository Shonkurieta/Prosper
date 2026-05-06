import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../constants/api_constants.dart';
import 'add_book_screen.dart';
import 'edit_book_screen.dart';
import 'manage_chapters_screen.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/models/book.dart';

class AdminBooksScreen extends StatefulWidget {
  final String token;
  final String role;

  const AdminBooksScreen({super.key, required this.token, required this.role});

  @override
  State<AdminBooksScreen> createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends State<AdminBooksScreen> with SingleTickerProviderStateMixin {
  late AdminService adminService;
  List<dynamic> books = [];
  List<dynamic> filteredBooks = [];
  bool loading = true;
  late AnimationController _animController;
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    adminService = AdminService(widget.token);
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _searchController.addListener(_filterBooks);
    _loadBooks();
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterBooks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredBooks = books;
      } else {
        filteredBooks = books.where((book) {
          final title = (book['title'] ?? '').toString().toLowerCase();
          final author = (book['author'] ?? '').toString().toLowerCase();
          return title.contains(query) || author.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadBooks() async {
    setState(() => loading = true);
    try {
      final result = await adminService.getBooks();
      setState(() {
        books = result;
        filteredBooks = result;
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

  Future<void> _deleteBook(int id, String title) async {
    final theme = context.read<ThemeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить новеллу?'),
        content: Text('Вы уверены, что хотите удалить "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: accentColor))),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      await adminService.deleteBook(id);
      _loadBooks();
      _showSnackBar('Новелла удалена', accentColor);
    } catch (e) {
      _showSnackBar('Ошибка: $e', Colors.redAccent);
    }
  }

  Future<void> _goToAddBook() async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddBookScreen(token: widget.token)),
    );
    if (added == true) _loadBooks();
  }

  Future<void> _goToEditBook(dynamic book) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditBookScreen(
          token: widget.token,
          book: Book.fromJson(book as Map<String, dynamic>),
        ),
      ),
    );
    if (updated == true) _loadBooks();
  }

  void _openChapters(dynamic book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageChaptersScreen(
          token: widget.token,
          bookId: book['id'],
          bookTitle: book['title'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Все новеллы',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
                  ),
                  TextButton.icon(
                    onPressed: _goToAddBook,
                    icon: const Icon(Icons.add, size: 18, color: accentColor),
                    label: const Text('Добавить', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: loading 
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(accentColor)))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = filteredBooks[index];
                      return FadeTransition(
                        opacity: _animController,
                        child: _buildBookGridItem(book, theme),
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Text(
        'Библиотека',
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
            hintText: 'Поиск новелл...',
            hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: theme.textPrimaryColor, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildBookGridItem(dynamic book, ThemeProvider theme) {
    final coverUrl = book['coverUrl'] != null 
        ? '${ApiConstants.baseUrl}${book['coverUrl']}' 
        : null;
    final title = book['title'] ?? 'Без названия';
    final author = book['author'] ?? 'Автор неизвестен';

    return GestureDetector(
      onTap: () => _showBookOptions(book, theme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: coverUrl != null 
                      ? NetworkImage(coverUrl) 
                      : const AssetImage('assets/images/no_cover.png') as ImageProvider,
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
          ),
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  void _showBookOptions(dynamic book, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.textSecondaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_rounded, color: accentColor),
              title: Text('Управление главами', style: TextStyle(color: theme.textPrimaryColor)),
              onTap: () { Navigator.pop(context); _openChapters(book); },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: Text('Редактировать', style: TextStyle(color: theme.textPrimaryColor)),
              onTap: () { Navigator.pop(context); _goToEditBook(book); },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(context); _deleteBook(book['id'], book['title']); },
            ),
          ],
        ),
      ),
    );
  }
}
