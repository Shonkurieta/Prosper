import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/admin_service.dart';
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

  void _showRelatedBooksModal(ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
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
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close, color: theme.textSecondaryColor),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _allBooks.length,
                  itemBuilder: (context, index) {
                    final book = _allBooks[index];
                    final bookId = book['id'];
                    final isSelected = _selectedRelatedBooks.any((b) => b['id'] == bookId);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            if (isSelected) {
                              _selectedRelatedBooks.removeWhere((b) => b['id'] == bookId);
                            } else {
                              _selectedRelatedBooks.add(book);
                            }
                          });
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? accentColor.withOpacity(0.1) : theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? accentColor : theme.textSecondaryColor.withOpacity(0.2),
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
                                        child: Image.network(book['coverUrl'], fit: BoxFit.cover),
                                      )
                                    : Center(
                                        child: Icon(Icons.book_outlined, color: theme.textSecondaryColor),
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
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle, color: accentColor, size: 24),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Готово',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
