import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../constants/api_constants.dart';
import 'add_book_screen.dart';
import 'manage_chapters_screen.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class AdminBooksScreen extends StatefulWidget {
  final String token;

  const AdminBooksScreen({super.key, required this.token});

  @override
  State<AdminBooksScreen> createState() => _AdminBooksScreenState();
}

class _AdminBooksScreenState extends State<AdminBooksScreen> with SingleTickerProviderStateMixin {
  late AdminService adminService;
  List<dynamic> books = [];
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
    _loadBooks();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() => loading = true);
    try {
      final result = await adminService.getBooks();
      setState(() {
        books = result;
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _deleteBook(int id, String title) async {
    final theme = context.read<ThemeProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Удалить книгу?',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить "$title"?\nЭто действие нельзя отменить.',
          style: TextStyle(
            color: theme.textSecondaryColor,
          ),
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
      await adminService.deleteBook(id);
      _loadBooks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Новелла удалена'),
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

  Future<void> _goToAddBook() async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBookScreen(token: widget.token),
      ),
    );
    if (added == true) _loadBooks();
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

  String _getCoverUrl(String? coverUrl) {
    if (coverUrl == null || coverUrl.isEmpty) return '';
    if (coverUrl.startsWith('http')) return coverUrl;
    final baseUrl = ApiConstants.baseUrl.replaceAll('/api', '');
    return '$baseUrl/api/admin/covers/${coverUrl.split('/').last}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: Stack(
            children: [
              // Decorative background shapes
              Positioned(
                top: -size.height * 0.1,
                right: -size.width * 0.2,
                child: Container(
                  width: size.width * 0.6,
                  height: size.width * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle1,
                  ),
                ),
              ),
              Positioned(
                bottom: -size.height * 0.15,
                left: -size.width * 0.3,
                child: Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle2,
                  ),
                ),
              ),
              
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.auto_stories_rounded,
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
                                  'Управление новеллами',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: theme.textPrimaryColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Text(
                                  'Всего ${books.length} новелл',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textSecondaryColor,
                                    fontWeight: FontWeight.w500,
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
                          : books.isEmpty
                              ? _buildEmptyState(theme)
                              : RefreshIndicator(
                                  onRefresh: _loadBooks,
                                  color: theme.primaryColor,
                                  child: GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.65,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                    itemCount: books.length,
                                    itemBuilder: (context, index) {
                                      return TweenAnimationBuilder(
                                        duration: Duration(milliseconds: 300 + (index * 50)),
                                        tween: Tween<double>(begin: 0, end: 1),
                                        builder: (context, double value, child) {
                                          return Transform.translate(
                                            offset: Offset(0, 20 * (1 - value)),
                                            child: Opacity(
                                              opacity: value,
                                              child: _buildBookCard(books[index], theme),
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
            ],
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: _goToAddBook,
              backgroundColor: theme.primaryColor,
              elevation: 0,
              child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
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
              Icons.book_outlined,
              size: 80,
              color: theme.textSecondaryColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Нет книг',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте первую книгу в библиотеку',
            style: TextStyle(
              fontSize: 15,
              color: theme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(dynamic book, ThemeProvider theme) {
    final coverUrl = _getCoverUrl(book['coverUrl']);
    final title = book['title'] ?? 'Без названия';
    final author = book['author'] ?? 'Неизвестный автор';

    return GestureDetector(
      onTap: () => _openChapters(book),
      child: Container(
        decoration: theme.getCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover image
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.primaryColor.withValues(alpha: 0.1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderCover(theme);
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: theme.primaryColor,
                              ),
                            );
                          },
                        )
                      : _buildPlaceholderCover(theme),
                ),
              ),
            ),

            // Book info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: theme.textPrimaryColor,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    author,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.menu_book_rounded,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                          onPressed: () => _openChapters(book),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          tooltip: 'Главы',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.delete_rounded,
                            color: theme.errorColor,
                            size: 20,
                          ),
                          onPressed: () => _deleteBook(book['id'], title),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          tooltip: 'Удалить',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Icon(
          Icons.book_rounded,
          size: 60,
          color: theme.primaryColor,
        ),
      ),
    );
  }
}