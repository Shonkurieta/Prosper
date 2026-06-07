import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/admin_service.dart';
import 'package:prosper/services/related_book_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/models/book.dart';
import 'package:prosper/models/genre.dart';
import 'package:prosper/constants/api_constants.dart';

class EditNovellScreen extends StatefulWidget {
  final String token;
  final Book book;

  const EditNovellScreen({super.key, required this.token, required this.book});

  @override
  State<EditNovellScreen> createState() => _EditNovellScreenState();
}

class _EditNovellScreenState extends State<EditNovellScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _descController;
  File? _cover;
  bool _loading = false;
  bool _loadingGenres = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Genre> _availableGenres = [];
  List<String> _selectedGenres = [];
  List<dynamic> _allBooks = [];
  List<Map<String, dynamic>> _selectedRelatedBooks = [];
  List<Map<String, dynamic>> _originalRelatedBooks = [];

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.author);
    _descController = TextEditingController(text: widget.book.description);
    _selectedGenres = List.from(widget.book.genres);

    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    
    _animController.forward();
    _fetchGenres();
    _fetchAllBooks();
    _fetchExistingRelatedBooks();
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchGenres() async {
    try {
      final svc = AdminService(widget.token);
      final genres = await svc.getGenres();
      if (mounted) {
        setState(() {
          _availableGenres = genres;
          _loadingGenres = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingGenres = false);
    }
  }

  Future<void> _fetchAllBooks() async {
    try {
      final svc = AdminService(widget.token);
      final books = await svc.getBooks();
      if (mounted) {
        setState(() {
          _allBooks = books;
        });
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _fetchExistingRelatedBooks() async {
    try {
      final svc = RelatedBookService();
      final existing = await svc.getRelatedBooks(widget.token, widget.book.id);
      if (!mounted) return;
      final mapped = existing.map<Map<String, dynamic>>((r) => {
        'id': r['relatedBookId'],           // ID of the related novel (for display / re-adding)
        'relationId': r['id'],              // ID of the relation row (for safe deletion)
        'title': r['relatedBookTitle'],
        'author': r['relatedBookAuthor'],
        'coverUrl': r['relatedBookCoverUrl'],
        'relationType': r['relationType'] ?? 'SEQUEL',
      }).toList();
      setState(() {
        _selectedRelatedBooks = mapped;
        _originalRelatedBooks = List.from(mapped);
      });
    } catch (_) {}
  }

  void _showGenrePicker() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = context.read<ThemeProvider>();
            return AlertDialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Выберите жанры', 
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontWeight: FontWeight.bold,
                )
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: _loadingGenres
                    ? const Center(child: CircularProgressIndicator(color: accentColor))
                    : _availableGenres.isEmpty
                        ? Text('Жанры не найдены', style: TextStyle(color: theme.textSecondaryColor))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableGenres.length,
                            itemBuilder: (context, index) {
                              final genre = _availableGenres[index];
                              final isSelected = _selectedGenres.contains(genre.name);
                              return CheckboxListTile(
                                title: Text(genre.name, style: TextStyle(color: theme.textPrimaryColor)),
                                value: isSelected,
                                activeColor: accentColor,
                                checkColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      _selectedGenres.add(genre.name);
                                    } else {
                                      _selectedGenres.remove(genre.name);
                                    }
                                  });
                                  setState(() {});
                                },
                              );
                            },
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Готово', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _cover = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final svc = AdminService(widget.token);
      await svc.updateBookMultipart(
        bookId: widget.book.id,
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        description: _descController.text.trim(),
        coverFile: _cover,
        genres: _selectedGenres,
      );

      final relatedSvc = RelatedBookService();
      debugPrint('[EditScreen] _submit: originals=${_originalRelatedBooks.length}, selected=${_selectedRelatedBooks.length}');
      for (final original in _originalRelatedBooks) {
        try {
          final relationId = original['relationId'] as int?;
          if (relationId != null) {
            debugPrint('[EditScreen] deleting relation row id=$relationId');
            await relatedSvc.deleteRelatedBookById(widget.token, relationId);
          }
        } catch (e) {
          debugPrint('[EditScreen] delete error: $e');
        }
      }
      for (final selected in _selectedRelatedBooks) {
        try {
          debugPrint('[EditScreen] adding relation: bookId=${widget.book.id}, relatedId=${selected['id']}, type=${selected['relationType']}');
          await relatedSvc.addRelatedBook(
            widget.token,
            widget.book.id,
            selected['id'] as int,
            selected['relationType'] as String? ?? 'SEQUEL',
          );
        } catch (e) {
          debugPrint('[EditScreen] add error: $e');
        }
      }

      if (!mounted) return;

      final theme = context.read<ThemeProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Новелла успешно обновлена'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;

      final theme = context.read<ThemeProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Ошибка: $e')),
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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              slivers: [
                _buildSliverHeader(theme),
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCoverSection(theme),
                            const SizedBox(height: 32),
                            _buildSectionLabel(theme, 'Основная информация'),
                            const SizedBox(height: 16),
                            _buildTextField(
                              theme: theme,
                              controller: _titleController,
                              hint: 'Название новеллы',
                              icon: Icons.book_outlined,
                              validator: (v) => v?.isEmpty ?? true ? 'Введите название' : null,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              theme: theme,
                              controller: _authorController,
                              hint: 'Автор',
                              icon: Icons.person_outline,
                              validator: (v) => v?.isEmpty ?? true ? 'Введите автора' : null,
                            ),
                            const SizedBox(height: 24),
                            _buildSectionLabel(theme, 'Жанры'),
                            const SizedBox(height: 12),
                            _buildGenreSelector(theme),
                            const SizedBox(height: 24),
                            _buildSectionLabel(theme, 'Описание'),
                            const SizedBox(height: 12),
                            _buildTextField(
                              theme: theme,
                              controller: _descController,
                              hint: 'Описание новеллы...',
                              icon: Icons.description_outlined,
                              maxLines: 6,
                            ),
                            const SizedBox(height: 24),
                            _buildSectionLabel(theme, 'Связанные новеллы'),
                            const SizedBox(height: 12),
                            _buildRelatedBooksSelector(theme),
                            const SizedBox(height: 40),
                            _buildSubmitButton(theme),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader(ThemeProvider theme) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: theme.backgroundColor,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new, color: accentColor, size: 20),
      ),
      title: Text(
        'Редактирование',
        style: TextStyle(
          color: theme.textPrimaryColor,
          fontWeight: FontWeight.w900,
          fontSize: 24,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildCoverSection(ThemeProvider theme) {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            Container(
              width: 140,
              height: 210,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _cover != null
                    ? Image.file(_cover!, fit: BoxFit.cover)
                    : Image.network(
                        ApiConstants.getCoverUrl(widget.book.coverUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 40,
                          color: theme.textSecondaryColor.withOpacity(0.3),
                        ),
                      ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(ThemeProvider theme, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: theme.textPrimaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required ThemeProvider theme,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: TextStyle(color: theme.textPrimaryColor, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: accentColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.4)),
        ),
      ),
    );
  }

  Widget _buildGenreSelector(ThemeProvider theme) {
    return InkWell(
      onTap: _showGenrePicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.category_outlined, color: accentColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedGenres.isEmpty ? 'Выберите жанры' : _selectedGenres.join(', '),
                style: TextStyle(
                  color: _selectedGenres.isEmpty
                      ? theme.textSecondaryColor.withOpacity(0.4)
                      : theme.textPrimaryColor,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedBooksSelector(ThemeProvider theme) {
    return InkWell(
      onTap: () => _showRelatedBooksModal(theme),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_outlined, color: accentColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedRelatedBooks.isEmpty
                    ? 'Добавить связанные новеллы'
                    : '${_selectedRelatedBooks.length} связанн${_selectedRelatedBooks.length == 1 ? "ая" : "ых"}',
                style: TextStyle(
                  color: _selectedRelatedBooks.isEmpty
                      ? theme.textSecondaryColor.withOpacity(0.4)
                      : theme.textPrimaryColor,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRelationType(
    BuildContext ctx,
    Map<String, dynamic> book,
    StateSetter setDialogState,
  ) async {
    String selectedType = 'SEQUEL';
    final confirmed = await showDialog<String>(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx2, setAlertState) => AlertDialog(
          backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Тип связи',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(ctx).textTheme.bodyLarge?.color,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in const [
                ('SEQUEL', 'Сиквел'),
                ('PREQUEL', 'Приквел'),
                ('SIDE_STORY', 'Побочная история'),
              ])
                RadioListTile<String>(
                  value: entry.$1,
                  groupValue: selectedType,
                  onChanged: (v) => setAlertState(() => selectedType = v!),
                  title: Text(entry.$2),
                  activeColor: accentColor,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx2),
              child: Text('Отмена', style: TextStyle(color: accentColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dialogCtx2, selectedType),
              child: const Text('Добавить', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != null) {
      setDialogState(() {
        _selectedRelatedBooks.add({
          'id': book['id'],
          'title': book['title'],
          'author': book['author'],
          'coverUrl': book['coverUrl'],
          'relationType': confirmed,
        });
      });
      setState(() {});
    }
  }

  void _showRelatedBooksModal(ThemeProvider theme) {
    String searchQuery = '';
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = searchQuery.isEmpty
              ? _allBooks
              : _allBooks
                  .where((b) => (b['title'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()))
                  .toList();

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.82,
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Связанные новеллы',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimaryColor,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Icon(Icons.close, color: theme.textSecondaryColor),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: TextField(
                    controller: searchController,
                    onChanged: (v) => setDialogState(() => searchQuery = v),
                    style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Поиск по названию...',
                      hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5)),
                      prefixIcon: Icon(Icons.search, color: theme.textSecondaryColor, size: 20),
                      suffixIcon: searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                searchController.clear();
                                setDialogState(() => searchQuery = '');
                              },
                              child: Icon(Icons.clear, color: theme.textSecondaryColor, size: 18),
                            )
                          : null,
                      filled: true,
                      fillColor: theme.cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Ничего не найдено',
                            style: TextStyle(color: theme.textSecondaryColor),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            final book = filtered[index];
                            final bookId = book['id'];
                            final selectedEntry = _selectedRelatedBooks
                                .where((b) => b['id'] == bookId)
                                .firstOrNull;
                            final isSelected = selectedEntry != null;
                            final typeLabel = isSelected
                                ? _relationLabel(selectedEntry['relationType'] ?? 'SEQUEL')
                                : null;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GestureDetector(
                                onTap: () {
                                  if (isSelected) {
                                    setDialogState(() {
                                      _selectedRelatedBooks
                                          .removeWhere((b) => b['id'] == bookId);
                                    });
                                    setState(() {});
                                  } else {
                                    _pickRelationType(ctx, book, setDialogState);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accentColor.withOpacity(0.1)
                                        : theme.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? accentColor
                                          : theme.textSecondaryColor.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: theme.backgroundColor,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: book['coverUrl'] != null
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                    ApiConstants.getCoverUrl(
                                                        book['coverUrl'] ?? ''),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Center(
                                                      child: Icon(Icons.book_outlined,
                                                          color: theme.textSecondaryColor),
                                                    ),
                                                  ),
                                              )
                                            : Center(
                                                child: Icon(Icons.book_outlined,
                                                    color: theme.textSecondaryColor),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              book['title'] ?? 'Новелла',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: theme.textPrimaryColor,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              book['author'] ?? 'Неизвестный автор',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: theme.textSecondaryColor,
                                              ),
                                            ),
                                            if (typeLabel != null) ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: accentColor.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  typeLabel,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: accentColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle,
                                            color: accentColor, size: 24),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Готово',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _relationLabel(String type) {
    switch (type) {
      case 'SEQUEL':
        return 'Сиквел';
      case 'PREQUEL':
        return 'Приквел';
      case 'SIDE_STORY':
        return 'Побочная история';
      default:
        return type;
    }
  }

  Widget _buildSubmitButton(ThemeProvider theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _loading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Сохранить изменения',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
