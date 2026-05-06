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
  bool _loadingGenres = true; // <-- добавлено
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Genre> _availableGenres = [];
  List<String> _selectedGenres = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.book.title);
    _authorController = TextEditingController(text: widget.book.author);
    _descController = TextEditingController(text: widget.book.description);
    _selectedGenres = List.from(widget.book.genres);

    _animController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
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

  // ✅ Новый метод — диалог с чекбоксами как в AddNovellScreen
  void _showGenrePicker() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = context.read<ThemeProvider>();
            return AlertDialog(
              backgroundColor: theme.cardColor,
              title: Text('Выберите жанры', style: TextStyle(color: theme.textPrimaryColor)),
              content: SizedBox(
                width: double.maxFinite,
                child: _loadingGenres
                    ? const Center(child: CircularProgressIndicator())
                    : _availableGenres.isEmpty
                        ? const Text('Жанры не найдены')
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableGenres.length,
                            itemBuilder: (context, index) {
                              final genre = _availableGenres[index];
                              final isSelected = _selectedGenres.contains(genre.name);
                              return CheckboxListTile(
                                title: Text(genre.name, style: TextStyle(color: theme.textPrimaryColor)),
                                value: isSelected,
                                activeColor: theme.primaryColor,
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
                  child: Text('Готово', style: TextStyle(color: theme.primaryColor)),
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
          backgroundColor: theme.successColor,
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
    final size = MediaQuery.of(context).size;

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: Stack(
            children: [
              // Decorative background shapes
              Positioned(
                top: -size.height * 0.15,
                left: -size.width * 0.2,
                child: Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle2,
                  ),
                ),
              ),
              Positioned(
                bottom: -size.height * 0.1,
                right: -size.width * 0.25,
                child: Container(
                  width: size.width * 0.7,
                  height: size.width * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.decorativeCircle1,
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Back button
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  decoration: theme.getCardDecoration(),
                                  child: IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(
                                      Icons.arrow_back_ios_new,
                                      color: theme.primaryColor,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Icon
                              Center(
                                child: TweenAnimationBuilder(
                                  duration: const Duration(milliseconds: 1200),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Transform.rotate(
                                      angle: value * 0.1,
                                      child: Icon(
                                        Icons.edit_note,
                                        size: 72,
                                        color: theme.primaryColor,
                                      ),
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 32),

                              Text(
                                'Редактировать новеллу',
                                style: TextStyle(
                                  fontSize: 28,        // было 44
                                  fontWeight: FontWeight.w700, // было w900
                                  color: theme.textPrimaryColor,
                                  height: 1.1,
                                ),
                              ),

                              const SizedBox(height: 8),

                              Text(
                                'Измените информацию о новелле',
                                style: TextStyle(
                                  fontSize: 17,
                                  color: theme.textSecondaryColor,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Cover image section
                              Center(
                                child: GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    width: 180,
                                    height: 240,
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: theme.isDarkMode
                                          ? Border.all(color: theme.borderColor, width: 1.5)
                                          : null,
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.shadowColor,
                                          blurRadius: 20,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: _cover == null
                                          ? (widget.book.coverUrl.isNotEmpty
                                              ? Image.network(
                                                  ApiConstants.baseUrl + widget.book.coverUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => Icon(
                                                    Icons.broken_image,
                                                    size: 50,
                                                    color: theme.textSecondaryColor,
                                                  ),
                                                )
                                              : Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(20),
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: theme.primaryColor.withOpacity(0.1),
                                                      ),
                                                      child: Icon(
                                                        Icons.add_photo_alternate_rounded,
                                                        size: 50,
                                                        color: theme.primaryColor,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Добавить обложку',
                                                      style: TextStyle(
                                                        color: theme.textSecondaryColor,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ))
                                          : Image.file(
                                              _cover!,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Title field
                              TextFormField(
                                controller: _titleController,
                                decoration: theme.getInputDecoration(
                                  hintText: 'Название новеллы',
                                  prefixIcon: Icons.title,
                                ),
                                style: TextStyle(color: theme.textPrimaryColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Пожалуйста, введите название';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Author field
                              TextFormField(
                                controller: _authorController,
                                decoration: theme.getInputDecoration(
                                  hintText: 'Автор новеллы',
                                  prefixIcon: Icons.person,
                                ),
                                style: TextStyle(color: theme.textPrimaryColor),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Пожалуйста, введите автора';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              Text(
                                'Жанры',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              InkWell(
                                onTap: _showGenrePicker,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedGenres.isEmpty
                                              ? 'Выберите жанры'
                                              : _selectedGenres.join(', '),
                                          style: TextStyle(
                                            color: _selectedGenres.isEmpty
                                                ? theme.textSecondaryColor.withOpacity(0.5)
                                                : theme.textPrimaryColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(Icons.arrow_drop_down, color: theme.primaryColor),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),


                              // Description field
                              TextFormField(
                                controller: _descController,
                                maxLines: 5,
                                decoration: theme.getInputDecoration(
                                  hintText: 'Описание новеллы',
                                  prefixIcon: Icons.description,
                                ),
                                style: TextStyle(color: theme.textPrimaryColor),
                              ),

                              const SizedBox(height: 40),

                              // Submit button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submit,
                                  style: theme.getPrimaryButtonStyle(),
                                  child: _loading
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text('Сохранить изменения'),
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}