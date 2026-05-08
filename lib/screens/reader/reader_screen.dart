import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/services/reading_progress_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/font_provider.dart';
import 'dart:ui';

class ReaderScreen extends StatefulWidget {
  final String token;
  final int bookId;
  final int chapterOrder;

  const ReaderScreen({
    super.key,
    required this.token,
    required this.bookId,
    required this.chapterOrder,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> with TickerProviderStateMixin {
  final BookService _bookService = BookService();
  final BookmarkService _bookmarkService = BookmarkService();
  final ReadingProgressService _progressService = ReadingProgressService();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _chapter;
  int _currentChapter = 1;
  int _totalChapters = 0;
  bool _isLoading = true;
  bool _showControls = true;
  TextAlign _textAlign = TextAlign.left;
  bool _enableIndent = false;
  Color? _customTextColor;
  Color? _customBackgroundColor;
  late AnimationController _controlsAnimController;
  late AnimationController _contentAnimController;
  late Animation<double> _controlsFadeAnimation;
  late Animation<Offset> _controlsSlideAnimation;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapterOrder;
    
    _controlsAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _contentAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _controlsFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controlsAnimController,
        curve: Curves.easeInOut,
      ),
    );
    _controlsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controlsAnimController,
      curve: Curves.easeOutCubic,
    ));
    
    _controlsAnimController.forward();
    _loadChapter();
  }

  @override
  void dispose() {
    _controlsAnimController.dispose();
    _contentAnimController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapter() async {
    setState(() => _isLoading = true);
    _contentAnimController.reset();
    
    try {
      final chapters = await _bookService.getBookChapters(widget.token, widget.bookId);
      
      setState(() {
        _totalChapters = chapters.length;
      });

      if (chapters.isEmpty) {
        setState(() {
          _chapter = null;
          _isLoading = false;
        });
        return;
      }

      final chapterExists = chapters.any((ch) => ch['chapterOrder'] == _currentChapter);
      
      if (!chapterExists) {
        setState(() {
          _chapter = null;
          _isLoading = false;
        });
        
        if (mounted) {
          final theme = context.read<ThemeProvider>();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Глава $_currentChapter не найдена')),
                ],
              ),
              backgroundColor: theme.warningColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(20),
            ),
          );
        }
        return;
      }

      final chapter = await _bookService.getChapter(
        widget.token,
        widget.bookId,
        _currentChapter,
      );
      
      final book = await _bookService.getBookById(widget.token, widget.bookId);
      
      await _bookmarkService.updateProgress(
        widget.token,
        widget.bookId,
        _currentChapter,
      );
      
      await _progressService.saveProgress(
        bookId: widget.bookId,
        chapterOrder: _currentChapter,
        bookTitle: book['title'] ?? 'Без названия',
        coverUrl: book['coverUrl'],
      );

      setState(() {
        _chapter = chapter;
        _isLoading = false;
      });
      
      _contentAnimController.forward();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Ошибка загрузки: $e')),
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
  }

  void _nextChapter() {
    if (_currentChapter < _totalChapters) {
      setState(() => _currentChapter++);
      _loadChapter();
    }
  }

  void _prevChapter() {
    if (_currentChapter > 1) {
      setState(() => _currentChapter--);
      _loadChapter();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _controlsAnimController.forward();
    } else {
      _controlsAnimController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final fontProvider = context.watch<FontProvider>();
    
    return Scaffold(
      backgroundColor: _customBackgroundColor ?? theme.backgroundColor,
      body: Stack(
        children: [
          // Content
          GestureDetector(
            onTap: _toggleControls,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: accentColor))
                : _buildContent(theme, fontProvider),
          ),

          // Top Bar
          _buildTopBar(theme, fontProvider),

          // Bottom Controls
          _buildBottomControls(theme),
        ],
      ),
    );
  }

  Widget _buildTopBar(ThemeProvider theme, FontProvider fontProvider) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: FadeTransition(
        opacity: _controlsFadeAnimation,
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 8),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.9),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new, color: accentColor, size: 20),
              ),
              Expanded(
                child: Text(
                  _chapter?['title'] ?? 'Глава $_currentChapter',
                  style: TextStyle(
                    color: theme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => _showFontSettings(theme, fontProvider),
                icon: const Icon(Icons.text_fields_rounded, color: accentColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeProvider theme, FontProvider fontProvider) {
    if (_chapter == null) {
      return Center(
        child: Text('Контент отсутствует', style: TextStyle(color: theme.textPrimaryColor)),
      );
    }

    return FadeTransition(
      opacity: _contentAnimController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + 80,
          20,
          MediaQuery.of(context).padding.bottom + 120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chapter?['title'] ?? '',
              style: TextStyle(
                fontSize: fontProvider.fontSize + 8,
                fontWeight: FontWeight.w900,
                color: _customTextColor ?? theme.textPrimaryColor,
                fontFamily: fontProvider.fontFamily,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _chapter?['content'] ?? '',
              textAlign: _textAlign,
              style: TextStyle(
                fontSize: fontProvider.fontSize,
                height: 1.6,
                color: _customTextColor ?? theme.textPrimaryColor,
                fontFamily: fontProvider.fontFamily,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(ThemeProvider theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _controlsSlideAnimation,
        child: FadeTransition(
          opacity: _controlsFadeAnimation,
          child: Container(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavButton(
                  icon: Icons.skip_previous_rounded,
                  label: 'Пред.',
                  onTap: _currentChapter > 1 ? _prevChapter : null,
                  theme: theme,
                ),
                Text(
                  '$_currentChapter / $_totalChapters',
                  style: TextStyle(
                    color: theme.textPrimaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                _buildNavButton(
                  icon: Icons.skip_next_rounded,
                  label: 'След.',
                  onTap: _currentChapter < _totalChapters ? _nextChapter : null,
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required ThemeProvider theme,
  }) {
    final bool isDisabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDisabled ? theme.backgroundColor.withOpacity(0.3) : accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (icon == Icons.skip_previous_rounded) Icon(icon, color: isDisabled ? Colors.grey : accentColor, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isDisabled ? Colors.grey : accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            if (icon == Icons.skip_next_rounded) Icon(icon, color: isDisabled ? Colors.grey : accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  void _showFontSettings(ThemeProvider theme, FontProvider fontProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Настройки текста',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimaryColor,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: accentColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSettingRow(
                    'Размер шрифта',
                    Row(
                      children: [
                        _buildCircleButton(Icons.remove, () {
                          fontProvider.setFontSize(fontProvider.fontSize - 1);
                          setModalState(() {});
                        }, theme),
                        const SizedBox(width: 16),
                        Text(
                          '${fontProvider.fontSize.toInt()}',
                          style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 16),
                        _buildCircleButton(Icons.add, () {
                          fontProvider.setFontSize(fontProvider.fontSize + 1);
                          setModalState(() {});
                        }, theme),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSettingRow(
                    'Выравнивание',
                    Row(
                      children: [
                        _buildIconButton(Icons.format_align_left_rounded, _textAlign == TextAlign.left, () {
                          setState(() => _textAlign = TextAlign.left);
                          setModalState(() {});
                        }, theme),
                        const SizedBox(width: 8),
                        _buildIconButton(Icons.format_align_center_rounded, _textAlign == TextAlign.center, () {
                          setState(() => _textAlign = TextAlign.center);
                          setModalState(() {});
                        }, theme),
                        const SizedBox(width: 8),
                        _buildIconButton(Icons.format_align_right_rounded, _textAlign == TextAlign.right, () {
                          setState(() => _textAlign = TextAlign.right);
                          setModalState(() {});
                        }, theme),
                        const SizedBox(width: 8),
                        _buildIconButton(Icons.format_align_justify_rounded, _textAlign == TextAlign.justify, () {
                          setState(() => _textAlign = TextAlign.justify);
                          setModalState(() {});
                        }, theme),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingRow(String label, Widget action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        action,
      ],
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap, ThemeProvider theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: accentColor, size: 20),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, bool isActive, VoidCallback onTap, ThemeProvider theme) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? accentColor : theme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isActive ? Colors.white : theme.textSecondaryColor, size: 20),
      ),
    );
  }

  void _showColorPicker(String title, Color currentColor, Function(Color) onColorSelected) {
    // Simplified for brevity, keeping existing functionality in mind
  }
}
