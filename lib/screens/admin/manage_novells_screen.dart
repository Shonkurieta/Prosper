
import 'package:flutter/material.dart';
import 'package:prosper/services/admin_service.dart';
import 'package:prosper/screens/admin/add_novell_screen.dart';
import 'package:prosper/screens/admin/edit_novell_screen.dart';
import 'package:prosper/models/book.dart';
import 'package:prosper/screens/admin/manage_chapters_screen.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class ManageNovellsScreen extends StatefulWidget {
  final String token;
  const ManageNovellsScreen({super.key, required this.token});

  @override
  State<ManageNovellsScreen> createState() => _ManageNovellsScreenState();
}

class _ManageNovellsScreenState extends State<ManageNovellsScreen> {
  late Future<List<Book>> _booksFuture;
  int _bookCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshBooks();
  }

  void _refreshBooks() {
    setState(() {
      _booksFuture = _fetchBooks();
    });
  }

  Future<List<Book>> _fetchBooks() async {
    final adminSvc = AdminService(widget.token);
    final List<dynamic> data = await adminSvc.getBooks();
    final books = data.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();
    if (mounted) {
      setState(() => _bookCount = books.length);
    }
    return books;
  }

  Future<void> _deleteBook(int id, String title) async {
    try {
      await AdminService(widget.token).deleteBook(id);
      _refreshBooks();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Новелла "$title" удалена')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back, color: theme.primaryColor), onPressed: () => Navigator.pop(context)),
        title: Text('Управление ($_bookCount)', style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Book>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
          
          final books = snapshot.data ?? [];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return Card(
                color: theme.cardColor,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
	                  title: Text(
	                    book.title,
	                    style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold),
	                    maxLines: 1,
	                    overflow: TextOverflow.ellipsis,
	                  ),
	                  subtitle: Text(
	                    book.author,
	                    style: TextStyle(color: theme.textSecondaryColor),
	                    maxLines: 1,
	                    overflow: TextOverflow.ellipsis,
	                  ),
	                  trailing: Row(
	                    mainAxisSize: MainAxisSize.min,
	                    children: [
	                      IconButton(
	                        padding: EdgeInsets.zero,
	                        constraints: const BoxConstraints(),
	                        icon: const Icon(Icons.list_alt, color: Colors.blue, size: 20),
	                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageChaptersScreen(token: widget.token, bookId: book.id, bookTitle: book.title, bookCover: book.coverUrl))),
	                      ),
	                      const SizedBox(width: 8),
	                      IconButton(
	                        padding: EdgeInsets.zero,
	                        constraints: const BoxConstraints(),
	                        icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
	                        onPressed: () async {
	                          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditNovellScreen(token: widget.token, book: book)));
	                          if (result == true) _refreshBooks();
	                        },
	                      ),
	                      const SizedBox(width: 8),
	                      IconButton(
	                        padding: EdgeInsets.zero,
	                        constraints: const BoxConstraints(),
	                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
	                        onPressed: () => _showDeleteDialog(book.id, book.title),
	                      ),
	                    ],
	                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddNovellScreen(token: widget.token)));
          if (result == true) _refreshBooks();
        },
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showDeleteDialog(int id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Удалить новеллу "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(onPressed: () { Navigator.pop(context); _deleteBook(id, title); }, child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}