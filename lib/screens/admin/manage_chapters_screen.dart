import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

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

  Future<void> _addOrEditChapter({Map<String, dynamic>? chapter}) async {
    final theme = context.read<ThemeProvider>();
    final titleController = TextEditingController(text: chapter?['title'] ?? '');
    final contentController = TextEditingController(text: chapter?['content'] ?? '');
    final orderController = TextEditingController(
      text: chapter?['chapterOrder']?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.close, color: theme.primaryColor),
              onPressed: () => Navigator.pop(ctx),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter == null ? 'Добавить главу' : 'Редактировать',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimaryColor,
                  ),
                ),
                Text(
                  chapter == null ? 'Новая глава' : 'Изменить главу',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textSecondaryColor,
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
                Text(
                  'Номер главы',
                  style: TextStyle(
                    color: theme.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: theme.getCardDecoration(),
                  child: TextField(
                    controller: orderController,
                    style: TextStyle(
                      color: theme.textPrimaryColor,
                      fontSize: 16,
                    ),
                    keyboardType: TextInputType.number,
                    decoration: theme.getInputDecoration(
                      hintText: 'Введите номер главы',
                      prefixIcon: Icons.numbers,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Название главы',
                  style: TextStyle(
                    color: theme.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: theme.getCardDecoration(),
                  child: TextField(
                    controller: titleController,
                    style: TextStyle(
                      color: theme.textPrimaryColor,
                      fontSize: 16,
                    ),
                    decoration: theme.getInputDecoration(
                      hintText: 'Введите название главы',
                      prefixIcon: Icons.title,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Содержимое главы',
                  style: TextStyle(
                    color: theme.textPrimaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: theme.getCardDecoration(),
                  child: TextField(
                    controller: contentController,
                    style: TextStyle(
                      color: theme.textPrimaryColor,
                      fontSize: 15,
                      height: 1.6,
                    ),
                    maxLines: 20,
                    decoration: InputDecoration(
                      hintText: 'Введите текст главы...',
                      hintStyle: TextStyle(
                        color: theme.textSecondaryColor.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w400,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      filled: true,
                      fillColor: theme.inputBackgroundColor,
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
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor,
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
                        side: BorderSide(
                          color: theme.borderColor,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Отмена',
                        style: TextStyle(
                          color: theme.textSecondaryColor,
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
                      style: theme.getPrimaryButtonStyle().copyWith(
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 16),
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
    final theme = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Удалить главу?',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить главу "$title"?',
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
              _deleteChapter(id, title);
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
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
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
                              'Главы',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: theme.textPrimaryColor,
                              ),
                            ),
                            Text(
                              widget.bookTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textSecondaryColor,
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
                          color: theme.primaryColor,
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
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.primaryColor,
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
                                    'Нет глав',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textPrimaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Добавьте первую главу',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: theme.textSecondaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: RefreshIndicator(
                                onRefresh: _loadChapters,
                                color: theme.primaryColor,
                                backgroundColor: theme.cardColor,
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
                                            child: Center(
                                              child: Text(
                                                '$order',
                                                style: TextStyle(
                                                  color: theme.primaryColor,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
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
                                            child: Text(
                                              'Глава $order',
                                              style: TextStyle(
                                                color: theme.textSecondaryColor,
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
                                                    color: theme.primaryColor.withValues(alpha: 0.15),
                                                  ),
                                                  child: Icon(
                                                    Icons.edit_outlined,
                                                    color: theme.primaryColor,
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
                                                    color: theme.errorColor.withValues(alpha: 0.15),
                                                  ),
                                                  child: Icon(
                                                    Icons.delete_outline,
                                                    color: theme.errorColor,
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
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            icon: const Icon(Icons.add),
            label: const Text(
              'Добавить',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }
}