import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/screens/admin/add_book_screen.dart';
import 'package:prosper/screens/admin/manage_chapters_screen.dart';

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
        _showSnackBar('Книга "$title" удалена');
      }
    } catch (e) {
      print('Delete book error: $e');
      if (mounted) {
        _showSnackBar('Ошибка удаления: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
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
        backgroundColor: isError ? const Color(0xFFFF6B6B) : const Color(0xFF4ECDC4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showDeleteDialog(int id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Удалить книгу?',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить книгу "$title"?',
          style: const TextStyle(color: Color(0xFF636E72)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF636E72)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBook(id, title);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
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
        _showSnackBar('Книга успешно добавлена');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                      color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF4ECDC4),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Управление',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        const Text(
                          'Библиотека книг',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF636E72),
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
                      color: const Color(0xFF4ECDC4),
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

            // Список книг
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: _books,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4ECDC4),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 80,
                            color: Color(0xFFFF6B6B),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Ошибка: ${snapshot.error}',
                              style: const TextStyle(
                                color: Color(0xFF636E72),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _refreshBooks,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Обновить'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4ECDC4),
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
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
                              color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              size: 80,
                              color: Color(0xFF4ECDC4),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Нет книг',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Добавьте первую книгу',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF636E72),
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
                      color: const Color(0xFF4ECDC4),
                      backgroundColor: Colors.white,
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
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
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
                                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book,
                                    color: Color(0xFF4ECDC4),
                                    size: 26,
                                  ),
                                ),
                                title: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3436),
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline,
                                        size: 14,
                                        color: Color(0xFF636E72),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          author,
                                          style: const TextStyle(
                                            color: Color(0xFF636E72),
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
                                          color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                                        ),
                                        child: const Icon(
                                          Icons.list_alt,
                                          color: Color(0xFF4ECDC4),
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
                                          color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline,
                                          color: Color(0xFFFF6B6B),
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
      // FAB для добавления книги
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddBook,
        backgroundColor: const Color(0xFF4ECDC4),
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
  }
}