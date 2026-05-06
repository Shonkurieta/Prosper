import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/admin_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/models/genre.dart';

class AddNovellScreen extends StatefulWidget {
  final String token;
  const AddNovellScreen({super.key, required this.token});

  @override
  State<AddNovellScreen> createState() => _AddNovellScreenState();
}

class _AddNovellScreenState extends State<AddNovellScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descController = TextEditingController();
  List<Genre> _availableGenres = [];
  List<String> _selectedGenres = [];
  File? _cover;
  bool _loading = false;
  bool _loadingGenres = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
    _fetchGenres();
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

  void _showGenrePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = context.read<ThemeProvider>();
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.textSecondaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Выберите жанры',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: _loadingGenres
                        ? const Center(child: CircularProgressIndicator(color: accentColor))
                        : _availableGenres.isEmpty
                            ? Center(child: Text('Жанры не найдены', style: TextStyle(color: theme.textSecondaryColor)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _availableGenres.length,
                                itemBuilder: (context, index) {
                                  final genre = _availableGenres[index];
                                  final isSelected = _selectedGenres.contains(genre.name);
                                  return CheckboxListTile(
                                    title: Text(genre.name, style: TextStyle(color: theme.textPrimaryColor)),
                                    value: isSelected,
                                    activeColor: accentColor,
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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Готово', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
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
      await svc.addBookMultipart(
        title: _titleController.text.trim(),
        author: _authorController.text.trim(),
        description: _descController.text.trim(),
        coverFile: _cover,
        genres: _selectedGenres,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(theme),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // Обложка в стиле карточки
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 160,
                            height: 220,
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: _cover == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.add_photo_alternate_outlined, size: 48, color: accentColor),
                                      const SizedBox(height: 8),
                                      Text('Добавить обложку', style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
                                    ],
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(_cover!, fit: BoxFit.cover),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildField(theme, _titleController, 'Название новеллы', 'Например: Путь меча'),
                      const SizedBox(height: 20),
                      
                      _buildField(theme, _authorController, 'Автор', 'Имя автора или псевдоним'),
                      const SizedBox(height: 20),
                      
                      // Жанры в стиле AdminNovellScreen
                      Text(
                        'Жанры',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimaryColor.withOpacity(0.7)),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _showGenrePicker,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accentColor.withOpacity(0.5), width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.category_outlined, size: 20, color: theme.textPrimaryColor.withOpacity(0.7)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _selectedGenres.isEmpty ? 'Выберите жанры' : _selectedGenres.join(', '),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _selectedGenres.isEmpty 
                                        ? theme.textSecondaryColor.withOpacity(0.5) 
                                        : theme.textPrimaryColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: accentColor),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      _buildField(theme, _descController, 'Описание', 'О чем эта история...', maxLines: 5),
                      const SizedBox(height: 40),
                      
                      // Кнопка в стиле AdminNovellScreen
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading 
                              ? const CircularProgressIndicator(color: Colors.white) 
                              : const Text(
                                  'Создать новеллу', 
                                  style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 24, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: accentColor),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Новая новелла',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: theme.textPrimaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(ThemeProvider theme, TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimaryColor.withOpacity(0.7)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.4), fontSize: 14),
            filled: true,
            fillColor: theme.cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor.withOpacity(0.3), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: accentColor, width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1),
            ),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Это поле обязательно' : null,
        ),
      ],
    );
  }
}
