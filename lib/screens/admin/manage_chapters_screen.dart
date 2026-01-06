import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_constants.dart';

class ManageChaptersScreen extends StatefulWidget {
  final String token;
  final int bookId;
  final String bookTitle;

  const ManageChaptersScreen({
    super.key,
    required this.token,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<ManageChaptersScreen> createState() => _ManageChaptersScreenState();
}

class _ManageChaptersScreenState extends State<ManageChaptersScreen>
    with SingleTickerProviderStateMixin {
  late final String baseUrl;
  List<dynamic> chapters = [];
  bool loading = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    baseUrl = ApiConstants.adminUrl;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
    _loadChapters();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.token}',
      };

  Future<void> _loadChapters() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/books/${widget.bookId}/chapters'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        setState(() {
          chapters = jsonDecode(res.body);
          loading = false;
        });
      } else {
        throw Exception('Ошибка загрузки: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => loading = false);
      _showSnackBar('Ошибка: $e', isError: true);
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

  Future<void> _addOrEditChapter({Map<String, dynamic>? chapter}) async {
    final titleController = TextEditingController(text: chapter?['title'] ?? '');
    final contentController = TextEditingController(text: chapter?['content'] ?? '');
    final orderController = TextEditingController(
      text: chapter?['chapterOrder']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Color(0xFF4ECDC4)),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter == null ? 'Добавить главу' : 'Редактировать',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3436),
                  ),
                ),
                Text(
                  chapter == null ? 'Новая глава' : 'Изменить главу',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF636E72),
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Номер главы',
                  style: TextStyle(
                    color: Color(0xFF2D3436),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: orderController,
                    style: const TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 16,
                    ),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Введите номер главы',
                      hintStyle: TextStyle(
                        color: const Color(0xFF636E72).withValues(alpha: 0.5),
                      ),
                      prefixIcon: const Icon(
                        Icons.numbers,
                        color: Color(0xFF4ECDC4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Название главы',
                  style: TextStyle(
                    color: Color(0xFF2D3436),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: titleController,
                    style: const TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Введите название главы',
                      hintStyle: TextStyle(
                        color: const Color(0xFF636E72).withValues(alpha: 0.5),
                      ),
                      prefixIcon: const Icon(
                        Icons.title,
                        color: Color(0xFF4ECDC4),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Содержимое главы',
                  style: TextStyle(
                    color: Color(0xFF2D3436),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: contentController,
                    style: const TextStyle(
                      color: Color(0xFF2D3436),
                      fontSize: 15,
                      height: 1.6,
                    ),
                    maxLines: 20,
                    decoration: InputDecoration(
                      hintText: 'Введите текст главы...',
                      hintStyle: TextStyle(
                        color: const Color(0xFF636E72).withValues(alpha: 0.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: Color(0xFFE0E5EC),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(
                          color: Color(0xFF636E72),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final payload = {
                          'title': titleController.text.trim(),
                          'content': contentController.text.trim(),
                          'chapterOrder': int.tryParse(orderController.text.trim()) ?? 0,
                        };
                        Navigator.pop(ctx);
                        if (chapter == null) {
                          await _createChapter(payload);
                        } else {
                          await _updateChapter(chapter['id'], payload);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4ECDC4),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Сохранить',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createChapter(Map<String, dynamic> payload) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/books/${widget.bookId}/chapters'),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await _loadChapters();
        _showSnackBar('Глава успешно добавлена');
      } else {
        throw Exception('Ошибка: ${res.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Ошибка создания: $e', isError: true);
    }
  }

  Future<void> _updateChapter(int id, Map<String, dynamic> payload) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/books/${widget.bookId}/chapters/$id'),
        headers: headers,
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        await _loadChapters();
        _showSnackBar('Глава обновлена');
      } else {
        throw Exception('Ошибка: ${res.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Ошибка обновления: $e', isError: true);
    }
  }

  void _showDeleteDialog(int id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Удалить главу?',
          style: TextStyle(
            color: Color(0xFF2D3436),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить главу "$title"?',
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
              _deleteChapter(id, title);
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

  Future<void> _deleteChapter(int id, String title) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/books/${widget.bookId}/chapters/$id'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        await _loadChapters();
        _showSnackBar('Глава "$title" удалена');
      } else {
        throw Exception('Ошибка удаления: ${res.statusCode}');
      }
    } catch (e) {
      _showSnackBar('Ошибка удаления: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
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
                          'Главы',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                          ),
                        ),
                        Text(
                          widget.bookTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF636E72),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
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
                      '${chapters.length}',
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
            Expanded(
              child: loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4ECDC4),
                      ),
                    )
                  : chapters.isEmpty
                      ? Center(
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
                                'Нет глав',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3436),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Добавьте первую главу',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF636E72),
                                ),
                              ),
                            ],
                          ),
                        )
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: RefreshIndicator(
                            onRefresh: _loadChapters,
                            color: const Color(0xFF4ECDC4),
                            backgroundColor: Colors.white,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: chapters.length,
                              itemBuilder: (context, index) {
                                final c = chapters[index];
                                final title = c['title'] ?? 'Без названия';
                                final order = c['chapterOrder'] ?? 0;

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
                                        child: Center(
                                          child: Text(
                                            '$order',
                                            style: const TextStyle(
                                              color: Color(0xFF4ECDC4),
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
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
                                        child: Text(
                                          'Глава $order',
                                          style: const TextStyle(
                                            color: Color(0xFF636E72),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      onTap: () => _addOrEditChapter(chapter: c),
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
                                                Icons.edit_outlined,
                                                color: Color(0xFF4ECDC4),
                                                size: 20,
                                              ),
                                            ),
                                            onPressed: () => _addOrEditChapter(chapter: c),
                                            tooltip: 'Редактировать',
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
                                            onPressed: () => _showDeleteDialog(c['id'], title),
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
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditChapter(),
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text(
          'Добавить',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}