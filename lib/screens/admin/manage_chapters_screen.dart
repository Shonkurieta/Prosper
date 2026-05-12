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
import 'package:prosper/providers/notification_provider.dart';

class ManageChaptersScreen extends StatefulWidget {
  final String token;
  final int bookId;
  final String bookCover;
  final String bookTitle;

  const ManageChaptersScreen({
    super.key,
    required this.bookCover,
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

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    baseUrl = ApiConstants.adminUrl;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/books/${widget.bookId}/chapters'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final chaptersData = jsonDecode(res.body) as List;
        setState(() {
          chapters = chaptersData;
          loading = false;
        });
        _animController.forward(from: 0);
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
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : accentColor,
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
      } else {
        selectedChapterIds.add(id);
      }
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
        title: const Text('Удалить главы?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Вы уверены, что хотите удалить $count ${_getChapterWord(count)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bulkDeleteChapters();
            },
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
  }

  String _getChapterWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'главу';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) return 'главы';
    return 'глав';
  }

  Future<void> _bulkDeleteChapters() async {
    final theme = context.read<ThemeProvider>();
    int successCount = 0;
    int errorCount = 0;

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
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: accentColor),
              SizedBox(height: 16),
              Text('Удаление глав...'),
            ],
          ),
        ),
      ),
    );

    for (var chapterId in selectedChapterIds) {
      try {
        final res = await http.delete(
          Uri.parse('$baseUrl/books/${widget.bookId}/chapters/$chapterId'),
          headers: headers,
        );
        if (res.statusCode == 200) successCount++;
        else errorCount++;
      } catch (e) {
        errorCount++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      setState(() {
        isSelectionMode = false;
        selectedChapterIds.clear();
      });
      await _loadChapters();
      _showSnackBar(errorCount == 0 ? 'Удалено глав: $successCount' : 'Удалено: $successCount, Ошибок: $errorCount', isError: errorCount > successCount);
    }
  }

  // ========== EPUB PARSER ==========
  
  Future<void> _importFromEpub() async {
    final theme = context.read<ThemeProvider>();
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['epub'],
      );
      if (result == null) return;

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

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
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: accentColor),
                SizedBox(height: 16),
                Text('Обработка EPUB...'),
              ],
            ),
          ),
        ),
      );

      final extractedChapters = await _parseEpub(bytes);
      if (!mounted) return;
      Navigator.pop(context);
      _showEpubSelectionDialog(extractedChapters);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Ошибка EPUB: $e', isError: true);
      }
    }
  }

  Future<List<Map<String, String>>> _parseEpub(List<int> bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);
    final List<Map<String, String>> result = [];
    
    final containerFile = archive.findFile('META-INF/container.xml');
    if (containerFile == null) throw Exception('Invalid EPUB: no container.xml');
    
    final containerXml = XmlDocument.parse(utf8.decode(containerFile.content));
    final opfPath = containerXml.findAllElements('rootfile').first.getAttribute('full-path')!;
    
    final opfFile = archive.findFile(opfPath);
    if (opfFile == null) throw Exception('Invalid EPUB: no OPF file');
    
    final opfXml = XmlDocument.parse(utf8.decode(opfFile.content));
    final opfDir = opfPath.contains('/') ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1) : '';
    
    final manifest = opfXml.findAllElements('item');
    final Map<String, String> manifestMap = {};
    for (var item in manifest) {
      manifestMap[item.getAttribute('id')!] = item.getAttribute('href')!;
    }
    
    final spine = opfXml.findAllElements('itemref');
    int order = 1;
    for (var itemref in spine) {
      final idref = itemref.getAttribute('idref')!;
      final href = manifestMap[idref]!;
      final htmlFile = archive.findFile('$opfDir$href');
      
      if (htmlFile != null) {
        final htmlContent = utf8.decode(htmlFile.content);
        final document = XmlDocument.parse(htmlContent);
        
        String title = document.findAllElements('title').isEmpty 
            ? 'Глава $order' 
            : document.findAllElements('title').first.innerText;
            
        if (title.trim().isEmpty) title = 'Глава $order';
        
        String body = '';
        final bodyElements = document.findAllElements('body');
        if (bodyElements.isNotEmpty) {
          body = bodyElements.first.innerText.trim();
        }
        
        if (body.length > 50) {
          result.add({
            'title': title,
            'content': body,
            'order': order.toString(),
          });
          order++;
        }
      }
    }
    return result;
  }

  void _showEpubSelectionDialog(List<Map<String, String>> extractedChapters) {
    final theme = context.read<ThemeProvider>();
    List<bool> selectedChapters = List.generate(extractedChapters.length, (_) => true);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Выберите главы для импорта', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setDialogState(() => selectedChapters.fillRange(0, selectedChapters.length, true)),
                      child: const Text('Выбрать все', style: TextStyle(color: accentColor)),
                    ),
                    TextButton(
                      onPressed: () => setDialogState(() => selectedChapters.fillRange(0, selectedChapters.length, false)),
                      child: const Text('Снять все', style: TextStyle(color: Colors.grey)),
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
                        activeColor: accentColor,
                        onChanged: (v) => setDialogState(() => selectedChapters[index] = v ?? false),
                        title: Text(chapter['title']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('Глава ${chapter['order']} • ${chapter['content']!.length} симв.', style: const TextStyle(fontSize: 12)),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _importSelectedChapters(extractedChapters.asMap().entries.where((e) => selectedChapters[e.key]).map((e) => e.value).toList());
              },
              style: ElevatedButton.styleFrom(backgroundColor: accentColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Импортировать', style: TextStyle(color: Colors.white)),
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [CircularProgressIndicator(color: accentColor), SizedBox(height: 16), Text('Импорт глав...')],
          ),
        ),
      ),
    );

    for (var chapter in selectedChapters) {
      try {
        final payload = {'title': chapter['title']!, 'content': chapter['content']!, 'chapterOrder': int.parse(chapter['order']!)};
        final res = await http.post(Uri.parse('$baseUrl/books/${widget.bookId}/chapters'), headers: headers, body: jsonEncode(payload));
        if (res.statusCode == 200 || res.statusCode == 201) successCount++;
        else errorCount++;
      } catch (e) {
        errorCount++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      await _loadChapters();
      _showSnackBar(errorCount == 0 ? 'Импортировано глав: $successCount' : 'Импортировано: $successCount, Ошибок: $errorCount', isError: errorCount > successCount);
    }
  }

  Future<void> _addOrEditChapter({Map<String, dynamic>? chapter}) async {
    final theme = context.read<ThemeProvider>();
    final titleController = TextEditingController(text: chapter?['title'] ?? '');
    final contentController = TextEditingController(text: chapter?['content'] ?? '');
    final orderController = TextEditingController(text: chapter?['chapterOrder']?.toString() ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            elevation: 0,
            leading: IconButton(icon: const Icon(Icons.close, color: accentColor), onPressed: () => Navigator.pop(ctx)),
            title: Text(chapter == null ? 'Добавить главу' : 'Редактировать', style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold)),
            actions: [
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final content = contentController.text.trim();
                  final order = orderController.text.trim();
                  
                  if (title.isEmpty || content.isEmpty || order.isEmpty) {
                    _showSnackBar('Заполните все поля', isError: true);
                    return;
                  }

                  try {
                    final payload = {'title': title, 'content': content, 'chapterOrder': int.parse(order)};
                    final url = chapter == null 
                        ? '$baseUrl/books/${widget.bookId}/chapters'
                        : '$baseUrl/books/${widget.bookId}/chapters/${chapter['id']}';
                    
                    final res = chapter == null
                        ? await http.post(Uri.parse(url), headers: headers, body: jsonEncode(payload))
                        : await http.put(Uri.parse(url), headers: headers, body: jsonEncode(payload));

                    if (res.statusCode == 200 || res.statusCode == 201) {
                      Navigator.pop(ctx);
                      _loadChapters();
                      if (chapter == null) {
                        final notificationProvider = context.read<NotificationProvider>();
                        notificationProvider.addNotification(AppNotification(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: "Добавлена новая глава ($order)",
                          bookTitle: widget.bookTitle,
                          coverUrl: widget.bookCover,
                          chapterOrder: int.parse(order),
                          bookId: widget.bookId,
                          timestamp: DateTime.now(),
                        ));
                      }
                      _showSnackBar(chapter == null ? 'Глава добавлена' : 'Сохранено');
                    } else {
                      _showSnackBar('Ошибка: ${res.statusCode}', isError: true);
                    }
                  } catch (e) {
                    _showSnackBar('Ошибка: $e', isError: true);
                  }
                },
                child: const Text('Готово', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildInput(theme, 'Номер главы', orderController, keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              _buildInput(theme, 'Название', titleController),
              const SizedBox(height: 20),
              _buildInput(theme, 'Текст главы', contentController, maxLines: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(ThemeProvider theme, String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimaryColor.withOpacity(0.7))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.cardColor,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accentColor.withOpacity(0.3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: accentColor)),
          ),
        ),
      ],
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
            if (isSelectionMode) _buildSelectionBar(theme),
            _buildActionButtons(theme),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: accentColor))
                  : chapters.isEmpty
                      ? _buildEmptyState(theme)
                      : FadeTransition(
                          opacity: _fadeAnimation,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: chapters.length,
                            itemBuilder: (context, index) => _buildChapterCard(chapters[index], theme),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: !isSelectionMode ? FloatingActionButton(
        onPressed: () => _addOrEditChapter(),
        backgroundColor: accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 24, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: accentColor),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Главы',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -1, color: theme.textPrimaryColor),
                ),
                Text(
                  widget.bookTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: theme.textSecondaryColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(isSelectionMode ? Icons.close : Icons.checklist_rtl, color: isSelectionMode ? Colors.redAccent : accentColor),
            onPressed: _toggleSelectionMode,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Text('Выбрано: ${selectedChapterIds.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: accentColor)),
          const Spacer(),
          TextButton(onPressed: _selectAllChapters, child: const Text('Все', style: TextStyle(color: accentColor))),
          IconButton(onPressed: _showBulkDeleteDialog, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeProvider theme) {
    if (isSelectionMode) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.upload_file_outlined,
              label: 'Импорт EPUB',
              onTap: _importFromEpub,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, required ThemeProvider theme}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: accentColor),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterCard(dynamic chapter, ThemeProvider theme) {
    final id = chapter['id'] as int;
    final isSelected = selectedChapterIds.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? accentColor : Colors.transparent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text('${chapter['chapterOrder']}', style: const TextStyle(color: accentColor, fontWeight: FontWeight.bold))),
        ),
        title: Text(chapter['title'] ?? 'Без названия', style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold)),
        subtitle: Text('ID: $id', style: TextStyle(color: theme.textSecondaryColor, fontSize: 12)),
        trailing: isSelectionMode 
            ? Checkbox(value: isSelected, activeColor: accentColor, onChanged: (_) => _toggleChapterSelection(id))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue), onPressed: () => _addOrEditChapter(chapter: chapter)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                    onPressed: () {
                      selectedChapterIds = {id};
                      _showBulkDeleteDialog();
                    },
                  ),
                ],
              ),
        onTap: isSelectionMode ? () => _toggleChapterSelection(id) : null,
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 80, color: theme.textSecondaryColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text('Главы еще не добавлены', style: TextStyle(color: theme.textSecondaryColor, fontSize: 16)),
        ],
      ),
    );
  }
}
