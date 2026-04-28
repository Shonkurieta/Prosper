import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/admin_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/models/genre.dart';

class AddBookScreen extends StatefulWidget {
  final String token;
  const AddBookScreen({super.key, required this.token});

  @override
  State<AddBookScreen> createState() => _AddBookScreenState();
}

class _AddBookScreenState extends State<AddBookScreen> with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Добавить новеллу', style: TextStyle(color: theme.textPrimaryColor)),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Обложка
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 140,
                    height: 190,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
                    ),
                    child: _cover == null
                        ? Icon(Icons.add_a_photo, size: 40, color: theme.primaryColor)
                        : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_cover!, fit: BoxFit.cover)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildField(theme, _titleController, 'Название', 'Введите название'),
              const SizedBox(height: 20),
              _buildField(theme, _authorController, 'Автор', 'Введите автора'),
              const SizedBox(height: 20),
              
              // Жанры (после автора)
              Text('Жанры', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
              const SizedBox(height: 8),
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
                          _selectedGenres.isEmpty ? 'Выберите жанры' : _selectedGenres.join(', '),
                          style: TextStyle(color: _selectedGenres.isEmpty ? theme.textSecondaryColor.withOpacity(0.5) : theme.textPrimaryColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: theme.primaryColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              _buildField(theme, _descController, 'Описание', 'Введите описание', maxLines: 4),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Добавить новеллу', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(ThemeProvider theme, TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: theme.textPrimaryColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5)),
            filled: true,
            fillColor: theme.cardColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          validator: (v) => v == null || v.isEmpty ? 'Обязательное поле' : null,
        ),
      ],
    );
  }
}
