import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:prosper/services/book_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/constants/api_constants.dart';

class EditBookScreen extends StatefulWidget {
  final String token;
  final Map<String, dynamic> book;

  const EditBookScreen({
    super.key,
    required this.token,
    required this.book,
  });

  @override
  State<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends State<EditBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  File? _coverImage;
  String? _existingCoverUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.book['title'] ?? '';
    _authorController.text = widget.book['author'] ?? '';
    _descriptionController.text = widget.book['description'] ?? '';
    _existingCoverUrl = widget.book['coverUrl'];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _coverImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateBook() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await BookService().updateBook(
        widget.token,
        widget.book['id'],
        _titleController.text.trim(),
        _authorController.text.trim(),
        _descriptionController.text.trim(),
        _coverImage,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: theme.backgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: theme.textPrimaryColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Редактировать новеллу',
              style: TextStyle(
                color: theme.textPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cover Image
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 300,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: theme.isDarkMode
                            ? Border.all(color: theme.borderColor, width: 1.5)
                            : null,
                        boxShadow: [theme.cardShadow],
                      ),
                      child: _coverImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                _coverImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : _existingCoverUrl != null && _existingCoverUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    ApiConstants.getCoverUrl(_existingCoverUrl!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                                  ),
                                )
                              : _buildPlaceholder(theme),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Нажмите для изменения обложки',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textSecondaryColor,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    style: TextStyle(color: theme.textPrimaryColor),
                    decoration: theme.getInputDecoration(
                      hintText: 'Название новеллы',
                      prefixIcon: Icons.book_outlined,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите название';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Author Field
                  TextFormField(
                    controller: _authorController,
                    style: TextStyle(color: theme.textPrimaryColor),
                    decoration: theme.getInputDecoration(
                      hintText: 'Автор',
                      prefixIcon: Icons.person_outline,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите автора';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Description Field
                  TextFormField(
                    controller: _descriptionController,
                    style: TextStyle(color: theme.textPrimaryColor),
                    decoration: theme.getInputDecoration(
                      hintText: 'Описание',
                      prefixIcon: Icons.description_outlined,
                    ),
                    maxLines: 5,
                  ),

                  const SizedBox(height: 32),

                  // Update Button
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateBook,
                      style: theme.getPrimaryButtonStyle(),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Сохранить изменения',
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
        );
      },
    );
  }

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 64,
            color: theme.textSecondaryColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Добавить обложку',
            style: TextStyle(
              color: theme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}