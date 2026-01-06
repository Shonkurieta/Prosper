import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/admin_service.dart';

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
  File? _cover;
  bool _loading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _animController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _descController.dispose();
    super.dispose();
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
      );
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Книга успешно добавлена'),
            ],
          ),
          backgroundColor: const Color(0xFF4ECDC4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Ошибка: $e')),
            ],
          ),
          backgroundColor: const Color(0xFFFF6B6B),
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
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                color: const Color(0xFFFFE66D).withValues(alpha: 0.2),
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
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
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
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Color(0xFF4ECDC4),
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
                                    Icons.library_add_rounded,
                                    size: 72,
                                    color: Color.lerp(
                                      const Color(0xFF4ECDC4),
                                      const Color(0xFF44A08D),
                                      value,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Title
                          const Text(
                            'Добавить книгу',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2D3436),
                              height: 1.1,
                            ),
                          ),

                          const SizedBox(height: 8),

                          const Text(
                            'Создайте новую книгу в библиотеке',
                            style: TextStyle(
                              fontSize: 17,
                              color: Color(0xFF636E72),
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: _cover == null
                                      ? Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(20),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
                                              ),
                                              child: const Icon(
                                                Icons.add_photo_alternate_rounded,
                                                size: 50,
                                                color: Color(0xFF4ECDC4),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Выбрать обложку',
                                              style: TextStyle(
                                                color: Color(0xFF636E72),
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Stack(
                                          children: [
                                            Image.file(
                                              _cover!,
                                              width: double.infinity,
                                              height: double.infinity,
                                              fit: BoxFit.cover,
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.1),
                                                      blurRadius: 8,
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.edit,
                                                  color: Color(0xFF4ECDC4),
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Title field
                          _buildMinimalTextField(
                            controller: _titleController,
                            label: 'Название книги',
                            hint: 'Введите название',
                            icon: Icons.book_rounded,
                            validator: (v) => v!.isEmpty ? 'Введите название' : null,
                          ),

                          const SizedBox(height: 20),

                          // Author field
                          _buildMinimalTextField(
                            controller: _authorController,
                            label: 'Автор',
                            hint: 'Введите автора',
                            icon: Icons.person_rounded,
                            validator: (v) => v!.isEmpty ? 'Введите автора' : null,
                          ),

                          const SizedBox(height: 20),

                          // Description field
                          _buildMinimalTextField(
                            controller: _descController,
                            label: 'Описание',
                            hint: 'Введите описание книги',
                            icon: Icons.description_rounded,
                            maxLines: 5,
                          ),

                          const SizedBox(height: 40),

                          // Submit button
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4ECDC4),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                disabledBackgroundColor: const Color(0xFF4ECDC4).withValues(alpha: 0.6),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Сохранить книгу',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),
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
  }

  Widget _buildMinimalTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3436),
            ),
          ),
        ),
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
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              color: Color(0xFF2D3436),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: const Color(0xFF636E72).withValues(alpha: 0.5),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF4ECDC4),
                size: 22,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF4ECDC4),
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFF6B6B),
                  width: 2,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFFF6B6B),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              errorStyle: const TextStyle(
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}