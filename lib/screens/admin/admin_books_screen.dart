import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../constants/api_constants.dart';
import 'add_book_screen.dart';
import 'edit_book_screen.dart';
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
  List<dynamic> filteredBooks = [];
  bool loading = true;
  late AnimationController _animController;
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;

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
          'Удалить новеллу?',
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

  Future<void> _goToEditBook(dynamic book) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditBookScreen(
          token: widget.token,
          book: book,
        ),
      ),
    );
    if (updated == true) {
      _loadBooks();
      if (mounted) {
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Новелла обновлена'),
              ],
            ),
            backgroundColor: theme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
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

  void _showBookOptions(dynamic book) {
    final theme = context.read<ThemeProvider>();
    final title = book['title'] ?? 'Без названия';

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
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimaryColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 8),
            const Divider(),

            // Chapters
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.getActionColor('chapters').withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: theme.getActionColor('chapters'),
                  size: 24,
                ),
              ),
              title: Text(
                'Управление главами',
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Добавить, редактировать, удалить главы',
                style: TextStyle(
                  color: theme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _openChapters(book);
              },
            ),

            // Edit
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.getActionColor('edit').withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  color: theme.getActionColor('edit'),
                  size: 24,
                ),
              ),
              title: Text(
                'Редактировать новеллу',
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Изменить название, автора, обложку',
                style: TextStyle(
                  color: theme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _goToEditBook(book);
              },
            ),

            // Delete
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.errorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: theme.errorColor,
                  size: 24,
                ),
              ),
              title: Text(
                'Удалить новеллу',
                style: TextStyle(
                  color: theme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Безвозвратно удалить новеллу и все главы',
                style: TextStyle(
                  color: theme.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteBook(book['id'], title);
              },
            ),

            const SizedBox(height: 8),
          ],
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
                          if (!isSearching) ...[
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
                          ],
                          Expanded(
                            child: isSearching
                                ? _buildSearchField(theme)
                                : Column(
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
                          const SizedBox(width: 12),
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

                    // Search results indicator
                    if (isSearching && _searchController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Найдено: ${filteredBooks.length}',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.textSecondaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Content
                    Expanded(
                      child: loading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: theme.primaryColor,
                                strokeWidth: 2.5,
                              ),
                            )
                          : filteredBooks.isEmpty
                              ? _buildEmptyState(theme)
                              : RefreshIndicator(
                                  onRefresh: _loadBooks,
                                  color: theme.primaryColor,
                                  child: GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.62,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                    itemCount: filteredBooks.length,
                                    itemBuilder: (context, index) {
                                      return TweenAnimationBuilder(
                                        duration: Duration(milliseconds: 300 + (index * 50)),
                                        tween: Tween<double>(begin: 0, end: 1),
                                        builder: (context, double value, child) {
                                          return Transform.translate(
                                            offset: Offset(0, 20 * (1 - value)),
                                            child: Opacity(
                                              opacity: value,
                                              child: _buildBookCard(filteredBooks[index], theme),
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
          hintText: 'Поиск по названию или автору...',
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
                  onPressed: () {
                    _searchController.clear();
                  },
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
              isFiltering ? Icons.search_off : Icons.book_outlined,
              size: 80,
              color: theme.textSecondaryColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFiltering ? 'Ничего не найдено' : 'Нет новелл',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltering
                ? 'Попробуйте изменить запрос'
                : 'Добавьте первую новеллу в библиотеку',
            style: TextStyle(
              fontSize: 15,
              color: theme.textSecondaryColor,
            ),
          ),
          if (isFiltering) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
              },
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

  Widget _buildBookCard(dynamic book, ThemeProvider theme) {
    final coverUrl = _getCoverUrl(book['coverUrl']);
    final title = book['title'] ?? 'Без названия';
    final author = book['author'] ?? 'Неизвестный автор';

    return GestureDetector(
      onTap: () => _showBookOptions(book),
      child: Container(
        decoration: theme.getCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover image
            Expanded(
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
                      fontSize: 14,
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
                  const SizedBox(height: 10),
                  
                  // Action button with adaptive colors
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: theme.getManagementButtonGradient(),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showBookOptions(book),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.more_horiz_rounded,
                                  color: theme.getManagementButtonTextColor(),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Управление',
                                  style: TextStyle(
                                    color: theme.getManagementButtonTextColor(),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
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