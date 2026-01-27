import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
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
  
  // Режим множественного выбора
  bool isSelectionMode = false;
  Set<int> selectedChapterIds = {};

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
        final chaptersData = jsonDecode(res.body) as List;
        print('📚 Loaded ${chaptersData.length} chapters');
        
        // Проверяем типы ID
        if (chaptersData.isNotEmpty) {
          print('   Sample chapter: ${chaptersData.first}');
          print('   Chapter ID type: ${chaptersData.first['id'].runtimeType}');
        }
        
        setState(() {
          chapters = chaptersData;
          loading = false;
        });
      } else {
        throw Exception('Ошибка загрузки: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => loading = false);
      _showSnackBar('Ошибка: $e', isError: true);
      print('❌ Error loading chapters: $e');
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

  // ========== РЕЖИМ ВЫБОРА ==========
  
  void _toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedChapterIds.clear();
      }
    });
  }

  void _selectAllChapters() {
    setState(() {
      selectedChapterIds = chapters.map((c) => c['id'] as int).toSet();
      print('✅ Selected all chapters: ${selectedChapterIds.length} items');
      print('   IDs: $selectedChapterIds');
    });
  }

  void _deselectAllChapters() {
    setState(() {
      selectedChapterIds.clear();
    });
  }

  void _toggleChapterSelection(int id) {
    setState(() {
      if (selectedChapterIds.contains(id)) {
        selectedChapterIds.remove(id);
        print('➖ Deselected chapter ID: $id');
      } else {
        selectedChapterIds.add(id);
        print('➕ Selected chapter ID: $id');
      }
      print('   Total selected: ${selectedChapterIds.length}');
    });
  }

  void _showBulkDeleteDialog() {
    if (selectedChapterIds.isEmpty) {
      _showSnackBar('Выберите главы для удаления', isError: true);
      return;
    }

    final theme = context.read<ThemeProvider>();
    final count = selectedChapterIds.length;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Удалить главы?',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить $count ${_getChapterWord(count)}?',
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
              _bulkDeleteChapters();
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

  String _getChapterWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'главу';
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'главы';
    } else {
      return 'глав';
    }
  }

  Future<void> _bulkDeleteChapters() async {
    final theme = context.read<ThemeProvider>();
    int successCount = 0;
    int errorCount = 0;

    // Показываем прогресс
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Удаление глав...',
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (var chapterId in selectedChapterIds) {
      try {
        print('🗑️ Deleting chapter ID: $chapterId');
        final res = await http.delete(
          Uri.parse('$baseUrl/books/${widget.bookId}/chapters/$chapterId'),
          headers: headers,
        );
        
        print('   Response status: ${res.statusCode}');
        print('   Response body: ${res.body}');
        
        if (res.statusCode == 200) {
          successCount++;
          print('   ✅ Chapter $chapterId deleted successfully');
        } else {
          errorCount++;
          print('   ❌ Failed to delete chapter $chapterId');
        }
      } catch (e) {
        errorCount++;
        print('   ❌ Exception deleting chapter $chapterId: $e');
      }
    }

    if (mounted) {
      Navigator.pop(context);
      setState(() {
        isSelectionMode = false;
        selectedChapterIds.clear();
      });
      await _loadChapters();
      
      if (errorCount == 0) {
        _showSnackBar('Удалено глав: $successCount');
      } else {
        _showSnackBar(
          'Удалено: $successCount, Ошибок: $errorCount',
          isError: errorCount > successCount,
        );
      }
    }
  }

  // ========== EPUB PARSER ==========
  
  Future<void> _importFromEpub() async {
    final theme = context.read<ThemeProvider>();
    
    try {
      // Выбираем файл
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );

      if (result == null) return;

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      // Показываем индикатор загрузки
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: theme.primaryColor),
                const SizedBox(height: 16),
                Text(
                  'Обработка EPUB файла...',
                  style: TextStyle(
                    color: theme.textPrimaryColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Парсим EPUB
      final extractedChapters = await _parseEpub(bytes);
      
      if (!mounted) return;
      Navigator.pop(context); // Закрываем индикатор

      if (extractedChapters.isEmpty) {
        _showSnackBar('В файле не найдено глав', isError: true);
        return;
      }

      // Показываем диалог выбора глав
      await _showChapterSelectionDialog(extractedChapters);
      
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        _showSnackBar('Ошибка импорта: $e', isError: true);
      }
    }
  }

  Future<List<Map<String, String>>> _parseEpub(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final chapters = <Map<String, String>>[];

    // Ищем content.opf для получения порядка глав
    ArchiveFile? opfFile;
    for (var file in archive) {
      if (file.name.endsWith('.opf')) {
        opfFile = file;
        break;
      }
    }

    if (opfFile == null) {
      throw Exception('Не найден файл content.opf');
    }

    final opfContent = utf8.decode(opfFile.content as List<int>);
    final opfDoc = XmlDocument.parse(opfContent);

    // Получаем список глав из spine
    final spineItems = opfDoc.findAllElements('itemref');
    int chapterOrder = 1;

    for (var item in spineItems) {
      final idref = item.getAttribute('idref');
      if (idref == null) continue;

      // Находим соответствующий item в manifest
      final manifestItem = opfDoc
          .findAllElements('item')
          .firstWhere(
            (el) => el.getAttribute('id') == idref,
            orElse: () => XmlElement(XmlName('item')),
          );

      final href = manifestItem.getAttribute('href');
      if (href == null || !href.endsWith('.html') && !href.endsWith('.xhtml')) {
        continue;
      }

      // Находим файл главы
      final chapterFile = archive.firstWhere(
        (f) => f.name.endsWith(href),
        orElse: () => ArchiveFile('', 0, []),
      );

      if (chapterFile.content.isEmpty) continue;

      final chapterContent = utf8.decode(chapterFile.content as List<int>);
      final chapterDoc = XmlDocument.parse(chapterContent);

      // Извлекаем заголовок
      String title = 'Глава $chapterOrder';
      final h1 = chapterDoc.findAllElements('h1').firstOrNull;
      final h2 = chapterDoc.findAllElements('h2').firstOrNull;
      final titleEl = chapterDoc.findAllElements('title').firstOrNull;
      
      if (h1 != null && h1.innerText.isNotEmpty) {
        title = h1.innerText.trim();
      } else if (h2 != null && h2.innerText.isNotEmpty) {
        title = h2.innerText.trim();
      } else if (titleEl != null && titleEl.innerText.isNotEmpty) {
        title = titleEl.innerText.trim();
      }

      // Извлекаем текст (убираем HTML теги)
      final bodyElements = chapterDoc.findAllElements('body');
      String content = '';
      
      if (bodyElements.isNotEmpty) {
        content = bodyElements.first.innerText;
      } else {
        // Если нет body, берем весь текст
        content = chapterDoc.innerText;
      }

      // Очищаем текст
      content = content
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'\n\s*\n'), '\n\n')
          .trim();

      if (content.length > 50) {
        chapters.add({
          'title': title,
          'content': content,
          'order': chapterOrder.toString(),
        });
        chapterOrder++;
      }
    }

    return chapters;
  }

  Future<void> _showChapterSelectionDialog(List<Map<String, String>> extractedChapters) async {
    final theme = context.read<ThemeProvider>();
    final selectedChapters = List<bool>.filled(extractedChapters.length, true);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Выберите главы для импорта',
            style: TextStyle(
              color: theme.textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          for (int i = 0; i < selectedChapters.length; i++) {
                            selectedChapters[i] = true;
                          }
                        });
                      },
                      child: Text('Выбрать все', style: TextStyle(color: theme.primaryColor)),
                    ),
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          for (int i = 0; i < selectedChapters.length; i++) {
                            selectedChapters[i] = false;
                          }
                        });
                      },
                      child: Text('Снять все', style: TextStyle(color: theme.textSecondaryColor)),
                    ),
                  ],
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: extractedChapters.length,
                    itemBuilder: (context, index) {
                      final chapter = extractedChapters[index];
                      return CheckboxListTile(
                        value: selectedChapters[index],
                        onChanged: (value) {
                          setDialogState(() {
                            selectedChapters[index] = value ?? false;
                          });
                        },
                        title: Text(
                          chapter['title']!,
                          style: TextStyle(
                            color: theme.textPrimaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Глава ${chapter['order']} • ${chapter['content']!.length} символов',
                          style: TextStyle(
                            color: theme.textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                        activeColor: theme.primaryColor,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Отмена',
                style: TextStyle(color: theme.textSecondaryColor),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                
                final selectedCount = selectedChapters.where((e) => e).length;
                if (selectedCount == 0) {
                  _showSnackBar('Выберите хотя бы одну главу', isError: true);
                  return;
                }

                // Импортируем выбранные главы
                await _importSelectedChapters(
                  extractedChapters
                      .asMap()
                      .entries
                      .where((e) => selectedChapters[e.key])
                      .map((e) => e.value)
                      .toList(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Импортировать'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importSelectedChapters(List<Map<String, String>> selectedChapters) async {
    final theme = context.read<ThemeProvider>();
    int successCount = 0;
    int errorCount = 0;

    // Показываем прогресс
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.primaryColor),
              const SizedBox(height: 16),
              Text(
                'Импорт глав...',
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    for (var chapter in selectedChapters) {
      try {
        final payload = {
          'title': chapter['title']!,
          'content': chapter['content']!,
          'chapterOrder': int.parse(chapter['order']!),
        };

        final res = await http.post(
          Uri.parse('$baseUrl/books/${widget.bookId}/chapters'),
          headers: headers,
          body: jsonEncode(payload),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          successCount++;
        } else {
          errorCount++;
        }
      } catch (e) {
        errorCount++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      await _loadChapters();
      
      if (errorCount == 0) {
        _showSnackBar('Импортировано глав: $successCount');
      } else {
        _showSnackBar(
          'Импортировано: $successCount, Ошибок: $errorCount',
          isError: errorCount > successCount,
        );
      }
    }
  }

  // Валидация данных главы
  String? _validateChapterData({
    required String title,
    required String content,
    required String order,
  }) {
    if (order.trim().isEmpty) {
      return 'Укажите номер главы';
    }
    
    final orderNum = int.tryParse(order.trim());
    if (orderNum == null) {
      return 'Номер главы должен быть числом';
    }
    
    if (orderNum <= 0) {
      return 'Номер главы должен быть больше 0';
    }

    if (title.trim().isEmpty) {
      return 'Введите название главы';
    }

    if (title.trim().length < 3) {
      return 'Название должно содержать минимум 3 символа';
    }

    if (content.trim().isEmpty) {
      return 'Введите содержимое главы';
    }

    if (content.trim().length < 10) {
      return 'Содержимое должно содержать минимум 10 символов';
    }

    return null;
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
                        final validationError = _validateChapterData(
                          title: titleController.text,
                          content: contentController.text,
                          order: orderController.text,
                        );

                        if (validationError != null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(validationError)),
                                ],
                              ),
                              backgroundColor: theme.errorColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(20),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                          return;
                        }

                        final payload = {
                          'title': titleController.text.trim(),
                          'content': contentController.text.trim(),
                          'chapterOrder': int.parse(orderController.text.trim()),
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
                      if (chapters.isNotEmpty && !isSelectionMode)
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
                      if (isSelectionMode)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.errorColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${selectedChapterIds.length}',
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
                
                // Панель управления выбором
                if (isSelectionMode)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _selectAllChapters,
                            icon: Icon(Icons.check_box, color: theme.primaryColor, size: 20),
                            label: Text(
                              'Все',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: theme.borderColor,
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _deselectAllChapters,
                            icon: Icon(
                              Icons.check_box_outline_blank,
                              color: theme.textSecondaryColor,
                              size: 20,
                            ),
                            label: Text(
                              'Снять',
                              style: TextStyle(
                                color: theme.textSecondaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: theme.borderColor,
                        ),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: _showBulkDeleteDialog,
                            icon: Icon(Icons.delete_outline, color: theme.errorColor, size: 20),
                            label: Text(
                              'Удалить',
                              style: TextStyle(
                                color: theme.errorColor,
                                fontWeight: FontWeight.w600,
                              ),
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
                                    'Добавьте первую главу или импортируйте EPUB',
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
                                    final id = c['id'] as int;
                                    final isSelected = selectedChapterIds.contains(id);

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
                                        decoration: theme.getCardDecoration().copyWith(
                                          border: isSelected
                                              ? Border.all(
                                                  color: theme.errorColor,
                                                  width: 2,
                                                )
                                              : null,
                                        ),
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          leading: isSelectionMode
                                              ? Checkbox(
                                                  value: isSelected,
                                                  onChanged: (_) => _toggleChapterSelection(id),
                                                  activeColor: theme.errorColor,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                )
                                              : Container(
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
                                          onTap: () {
                                            if (isSelectionMode) {
                                              _toggleChapterSelection(id);
                                            } else {
                                              _addOrEditChapter(chapter: c);
                                            }
                                          },
                                          onLongPress: () {
                                            if (!isSelectionMode) {
                                              setState(() {
                                                isSelectionMode = true;
                                                selectedChapterIds.add(id);
                                              });
                                            }
                                          },
                                          trailing: isSelectionMode
                                              ? null
                                              : Row(
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
          floatingActionButton: isSelectionMode
              ? FloatingActionButton.extended(
                  heroTag: 'cancel_selection',
                  onPressed: _toggleSelectionMode,
                  backgroundColor: theme.textSecondaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  icon: const Icon(Icons.close),
                  label: const Text(
                    'Отмена',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chapters.isNotEmpty)
                      FloatingActionButton(
                        heroTag: 'selection_mode',
                        onPressed: _toggleSelectionMode,
                        backgroundColor: theme.errorColor.withValues(alpha: 0.9),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        child: const Icon(Icons.checklist),
                      ),
                    if (chapters.isNotEmpty) const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'import_epub',
                      onPressed: _importFromEpub,
                      backgroundColor: theme.primaryColor.withValues(alpha: 0.9),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      child: const Icon(Icons.upload_file),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'add_chapter',
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
                  ],
                ),
        );
      },
    );
  }
}