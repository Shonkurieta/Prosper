import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/screens/admin/add_book_screen.dart';
import 'package:prosper/screens/admin/edit_book_screen.dart';
import 'package:prosper/screens/admin/manage_chapters_screen.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class ManageBooksScreen extends StatefulWidget {
  final String token;

  const ManageBooksScreen({super.key, required this.token});

  @override
  State<ManageBooksScreen> createState() => _ManageBooksScreenState();
}

class _ManageBooksScreenState extends State<ManageBooksScreen> with SingleTickerProviderStateMixin {
  late Future<List<dynamic>> _books;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  int _bookCount = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _books = BookService().getAdminBooks(widget.token);
    _updateBookCount();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _updateBookCount() async {
    final books = await _books;
    if (mounted) {
      setState(() => _bookCount = books.length);
    }
  }

  Future<void> _refreshBooks() async {
    setState(() {
      _books = BookService().getAdminBooks(widget.token);
    });
    await _updateBookCount();
  }

  Future<void> _deleteBook(int id, String title) async {
    try {
      print('Attempting to delete book: $id');
      await BookService().deleteBook(widget.token, id);
      await _refreshBooks();
      if (mounted) {
        _showSnackBar('Новелла "$title" удалена');
      }
    } catch (e) {
      print('Delete book error: $e');
      if (mounted) {
        _showSnackBar('Ошибка удаления: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final theme = context.read<ThemeProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? theme.errorColor : theme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showDeleteDialog(int id, String title) {
    final theme = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Удалить новеллу?',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить новеллу "$title"?',
          style: TextStyle(color: theme.textSecondaryColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: TextStyle(color: theme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBook(id, title);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.errorColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _openChapters(dynamic book) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageChaptersScreen(
          token: widget.token,
          bookId: book['id'],
          bookTitle: book['title'] ?? 'Без названия',
        ),
      ),
    );
  }

  void _openAddBook() async {
    final added = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddBookScreen(token: widget.token),
      ),
    );
    if (added == true) {
      await _refreshBooks();
      if (mounted) {
        _showSnackBar('Новелла успешно добавлена');
      }
    }
  }

  void _openEditBook(dynamic book) async {
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
      await _refreshBooks();
      if (mounted) {
        _showSnackBar('Новелла успешно обновлена');
      }
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
              children: [
                // Заголовок
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.primaryColor.withValues(alpha: 0.15),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: theme.primaryColor,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Управление',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: theme.textPrimaryColor,
                              ),
                            ),
                            Text(
                              'Библиотека новелл',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Индикатор количества
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_bookCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Список новелл
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: _books,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 80,
                                color: theme.errorColor,
                              ),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Ошибка: ${snapshot.error}',
                                  style: TextStyle(
                                    color: theme.textSecondaryColor,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _refreshBooks,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Обновить'),
                                style: theme.getPrimaryButtonStyle(),
                              ),
                            ],
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
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
                                  Icons.menu_book_outlined,
                                  size: 80,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Нет новелл',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Добавьте первую новеллу',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final books = snapshot.data!;
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: RefreshIndicator(
                          onRefresh: _refreshBooks,
                          color: theme.primaryColor,
                          backgroundColor: theme.cardColor,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: books.length,
                            itemBuilder: (context, index) {
                              final book = books[index];
                              final title = book['title'] ?? 'Без названия';
                              final author = book['author'] ?? 'Без автора';
                              final bookId = book['id'];

                              return TweenAnimationBuilder(
                                duration: Duration(milliseconds: 300 + (index * 50)),
                                tween: Tween<double>(begin: 0, end: 1),
                                builder: (context, double value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 20 * (1 - value)),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: theme.getCardDecoration(),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: theme.primaryColor.withValues(alpha: 0.15),
                                      ),
                                      child: Icon(
                                        Icons.menu_book,
                                        color: theme.primaryColor,
                                        size: 26,
                                      ),
                                    ),
                                    title: Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.textPrimaryColor,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.person_outline,
                                            size: 14,
                                            color: theme.textSecondaryColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              author,
                                              style: TextStyle(
                                                color: theme.textSecondaryColor,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    onTap: () => _openChapters(book),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: theme.primaryColor.withValues(alpha: 0.15),
                                            ),
                                            child: Icon(
                                              Icons.list_alt,
                                              color: theme.primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                          onPressed: () => _openChapters(book),
                                          tooltip: 'Главы',
                                        ),
                                        IconButton(
                                          icon: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.blue.withValues(alpha: 0.15),
                                            ),
                                            child: const Icon(
                                              Icons.edit_outlined,
                                              color: Colors.blue,
                                              size: 20,
                                            ),
                                          ),
                                          onPressed: () => _openEditBook(book),
                                          tooltip: 'Редактировать',
                                        ),
                                        IconButton(
                                          icon: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: theme.errorColor.withValues(alpha: 0.15),
                                            ),
                                            child: Icon(
                                              Icons.delete_outline,
                                              color: theme.errorColor,
                                              size: 20,
                                            ),
                                          ),
                                          onPressed: () => _showDeleteDialog(bookId, title),
                                          tooltip: 'Удалить',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // FAB для добавления новеллы
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAddBook,
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            icon: const Icon(Icons.add),
            label: const Text(
              'Добавить',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
} 