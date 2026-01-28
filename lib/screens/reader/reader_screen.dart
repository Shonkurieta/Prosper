import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/bookmark_service.dart';
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

      // Проверяем, есть ли главы вообще
      if (chapters.isEmpty) {
        setState(() {
          _chapter = null;
          _isLoading = false;
        });
        return;
      }

      // Проверяем, существует ли запрашиваемая глава
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
      
      await _bookmarkService.updateProgress(
        widget.token,
        widget.bookId,
        _currentChapter,
      );

      setState(() {
        _chapter = chapter;
        _isLoading = false;
      });
      
      _contentAnimController.forward();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
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
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Consumer<FontProvider>(
          builder: (context, fontProvider, child) {
            return Scaffold(
              backgroundColor: theme.backgroundColor,
              extendBodyBehindAppBar: true,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: AnimatedBuilder(
                  animation: _controlsAnimController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _controlsAnimController.value,
                      child: Transform.translate(
                        offset: Offset(0, -kToolbarHeight * (1 - _controlsAnimController.value)),
                        child: _showControls || _controlsAnimController.value > 0
                            ? AppBar(
                                backgroundColor: theme.cardColor.withValues(alpha: 0.95),
                                elevation: 0,
                                title: Text(
                                  _chapter?['title'] ?? 'Глава $_currentChapter',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: theme.textPrimaryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                leading: Container(
                                  margin: const EdgeInsets.all(8),
                                  child: Material(
                                    color: theme.inputBackgroundColor,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      onTap: () => Navigator.pop(context),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: theme.primaryColor,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                actions: [
                                  Container(
                                    margin: const EdgeInsets.all(8),
                                    child: Material(
                                      color: theme.inputBackgroundColor,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () => _showFontSettings(theme, fontProvider),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(10),
                                          child: Icon(
                                            Icons.settings_outlined,
                                            color: theme.primaryColor,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                flexibleSpace: ClipRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                    child: Container(color: Colors.transparent),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  },
                ),
              ),
              body: _isLoading
                  ? Center(
                      child: TweenAnimationBuilder(
                        duration: const Duration(milliseconds: 1000),
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (context, double value, child) {
                          return Transform.scale(
                            scale: 0.8 + (value * 0.2),
                            child: Opacity(
                              opacity: value,
                              child: CircularProgressIndicator(
                                color: theme.primaryColor,
                                strokeWidth: 3,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : GestureDetector(
                      onTap: _toggleControls,
                      child: Container(
                        color: _customBackgroundColor ?? theme.backgroundColor,
                        child: Stack(
                          children: [
                            // Content
                            AnimatedBuilder(
                              animation: _contentAnimController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _contentAnimController.value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - _contentAnimController.value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  100,
                                  20,
                                  140,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Progress indicator
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: theme.borderColor,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: _currentChapter / _totalChapters,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: theme.primaryGradient,
                                                  ),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.primaryColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: theme.primaryColor.withValues(alpha: 0.3),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            '$_currentChapter/$_totalChapters',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.primaryColor,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 32),

                                    // Chapter title
                                    Text(
                                      _chapter?['title'] ?? 'Без названия',
                                      style: TextStyle(
                                        fontSize: fontProvider.fontSize + 10,
                                        fontWeight: FontWeight.w900,
                                        color: _customTextColor ?? theme.textPrimaryColor,
                                        height: 1.2,
                                        letterSpacing: 0.5,
                                        fontFamily: fontProvider.fontFamily == FontProvider.defaultFont 
                                            ? null 
                                            : fontProvider.fontFamily,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 8),
                                    
                                    Container(
                                      height: 3,
                                      width: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: theme.primaryGradient,
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),

                                    const SizedBox(height: 32),

                                    // Content with custom font and alignment
                                    _enableIndent 
                                        ? _buildTextWithIndent(fontProvider, theme)
                                        : Text(
                                            _chapter?['content'] ?? '',
                                            textAlign: _textAlign,
                                            style: fontProvider.getTextStyle(
                                              color: _customTextColor ?? theme.textPrimaryColor,
                                            ),
                                          ),
                                    
                                    const SizedBox(height: 48),

                                    // End of chapter navigation
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: (_customBackgroundColor ?? theme.backgroundColor).computeLuminance() > 0.5
                                            ? Colors.black.withValues(alpha: 0.05)
                                            : Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: (_customTextColor ?? theme.textPrimaryColor).withValues(alpha: 0.1),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.menu_book_rounded,
                                            color: (_customTextColor ?? theme.textPrimaryColor).withValues(alpha: 0.6),
                                            size: 32,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Конец главы $_currentChapter',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: (_customTextColor ?? theme.textPrimaryColor).withValues(alpha: 0.8),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Row(
                                            children: [
                                              // Previous chapter button
                                              if (_currentChapter > 1)
                                                Expanded(
                                                  child: Material(
                                                    color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: InkWell(
                                                      onTap: _prevChapter,
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: Container(
                                                        height: 48,
                                                        alignment: Alignment.center,
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(
                                                              Icons.arrow_back_ios_new_rounded,
                                                              size: 16,
                                                              color: _customTextColor ?? theme.primaryColor,
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              'Предыдущая',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w700,
                                                                color: _customTextColor ?? theme.primaryColor,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              
                                              if (_currentChapter > 1 && _currentChapter < _totalChapters)
                                                const SizedBox(width: 12),

                                              // Next chapter button
                                              if (_currentChapter < _totalChapters)
                                                Expanded(
                                                  child: Material(
                                                    color: _customTextColor ?? theme.primaryColor,
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: InkWell(
                                                      onTap: _nextChapter,
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: Container(
                                                        height: 48,
                                                        alignment: Alignment.center,
                                                        child: Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text(
                                                              'Следующая',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w700,
                                                                color: (_customTextColor ?? theme.primaryColor).computeLuminance() > 0.5
                                                                    ? Colors.black
                                                                    : Colors.white,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Icon(
                                                              Icons.arrow_forward_ios_rounded,
                                                              size: 16,
                                                              color: (_customTextColor ?? theme.primaryColor).computeLuminance() > 0.5
                                                                  ? Colors.black
                                                                  : Colors.white,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Bottom navigation
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: AnimatedBuilder(
                                animation: _controlsAnimController,
                                builder: (context, child) {
                                  if (!_showControls && _controlsAnimController.value == 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return SlideTransition(
                                    position: _controlsSlideAnimation,
                                    child: FadeTransition(
                                      opacity: _controlsFadeAnimation,
                                      child: child,
                                    ),
                                  );
                                },
                                  child: ClipRect(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: (_customBackgroundColor ?? theme.cardColor).withValues(alpha: 0.95),
                                          border: Border(
                                            top: BorderSide(
                                              color: (_customTextColor ?? theme.borderColor).withValues(alpha: 0.2),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: SafeArea(
                                          top: false,
                                          child: Row(
                                            children: [
                                              // Previous button
                                              Expanded(
                                                child: Material(
                                                  color: _currentChapter > 1
                                                      ? (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.1)
                                                      : (_customTextColor ?? theme.inputBackgroundColor).withValues(alpha: 0.3),
                                                  borderRadius: BorderRadius.circular(14),
                                                  child: InkWell(
                                                    onTap: _currentChapter > 1 ? _prevChapter : null,
                                                    borderRadius: BorderRadius.circular(14),
                                                    child: Container(
                                                      height: 54,
                                                      alignment: Alignment.center,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            Icons.arrow_back_ios_new_rounded,
                                                            size: 18,
                                                            color: _currentChapter > 1
                                                                ? (_customTextColor ?? theme.primaryColor)
                                                                : (_customTextColor ?? theme.textSecondaryColor).withValues(alpha: 0.3),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text(
                                                            'Назад',
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w700,
                                                              color: _currentChapter > 1
                                                                  ? (_customTextColor ?? theme.primaryColor)
                                                                  : (_customTextColor ?? theme.textSecondaryColor).withValues(alpha: 0.3),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 12),

                                              // Settings button
                                              Material(
                                                color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(14),
                                                child: InkWell(
                                                  onTap: () => _showFontSettings(theme, fontProvider),
                                                  borderRadius: BorderRadius.circular(14),
                                                  child: Container(
                                                    width: 54,
                                                    height: 54,
                                                    alignment: Alignment.center,
                                                    child: Icon(
                                                      Icons.tune_rounded,
                                                      color: _customTextColor ?? theme.primaryColor,
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 12),

                                              // Next button
                                              Expanded(
                                                child: Material(
                                                  color: _currentChapter < _totalChapters
                                                      ? (_customTextColor ?? theme.primaryColor)
                                                      : (_customTextColor ?? theme.inputBackgroundColor).withValues(alpha: 0.3),
                                                  borderRadius: BorderRadius.circular(14),
                                                  child: InkWell(
                                                    onTap: _currentChapter < _totalChapters
                                                        ? _nextChapter
                                                        : null,
                                                    borderRadius: BorderRadius.circular(14),
                                                    child: Container(
                                                      height: 54,
                                                      alignment: Alignment.center,
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Text(
                                                            'Вперёд',
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.w700,
                                                              color: _currentChapter < _totalChapters
                                                                  ? ((_customTextColor ?? theme.primaryColor).computeLuminance() > 0.5
                                                                      ? Colors.black
                                                                      : Colors.white)
                                                                  : (_customTextColor ?? theme.textSecondaryColor).withValues(alpha: 0.3),
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Icon(
                                                            Icons.arrow_forward_ios_rounded,
                                                            size: 18,
                                                            color: _currentChapter < _totalChapters
                                                                ? ((_customTextColor ?? theme.primaryColor).computeLuminance() > 0.5
                                                                    ? Colors.black
                                                                    : Colors.white)
                                                                : (_customTextColor ?? theme.textSecondaryColor).withValues(alpha: 0.3),
                                                          ),
                                                        ],
                                                      ),
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
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  void _showFontSettings(ThemeProvider theme, FontProvider fontProvider) {
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _customBackgroundColor ?? theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: (_customTextColor ?? theme.borderColor).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      // Back button
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: _customTextColor ?? theme.primaryColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: _customTextColor ?? theme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Настройки чтения',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _customTextColor ?? theme.textPrimaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 28),

                  // Font Size
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.format_size_rounded,
                    title: 'Размер шрифта',
                    value: fontProvider.fontSize,
                    displayValue: '${fontProvider.fontSize.round()}',
                    min: 12,
                    max: 28,
                    divisions: 8,
                    color: theme.primaryColor,
                    onChanged: (value) {
                      fontProvider.setFontSize(value);
                      setModalState(() {});
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 28),

                  // Color Themes Section
                  Text(
                    'Цветовая тема',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _customTextColor ?? theme.textPrimaryColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Preset color themes - all in one row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildColorThemeButton(
                        theme: theme,
                        backgroundColor: const Color(0xFFF5F5F5),
                        textColor: const Color(0xFF1A1A1A),
                        isSelected: _customBackgroundColor == const Color(0xFFF5F5F5) && 
                                   _customTextColor == const Color(0xFF1A1A1A),
                        onTap: () {
                          setState(() {
                            _customBackgroundColor = const Color(0xFFF5F5F5);
                            _customTextColor = const Color(0xFF1A1A1A);
                          });
                          setModalState(() {});
                        },
                      ),
                      _buildColorThemeButton(
                        theme: theme,
                        backgroundColor: const Color(0xFFE8E5D9),
                        textColor: const Color(0xFF2D2D2D),
                        isSelected: _customBackgroundColor == const Color(0xFFE8E5D9) && 
                                   _customTextColor == const Color(0xFF2D2D2D),
                        onTap: () {
                          setState(() {
                            _customBackgroundColor = const Color(0xFFE8E5D9);
                            _customTextColor = const Color(0xFF2D2D2D);
                          });
                          setModalState(() {});
                        },
                      ),
                      _buildColorThemeButton(
                        theme: theme,
                        backgroundColor: const Color(0xFFFDF6E3),
                        textColor: const Color(0xFF5C4A2E),
                        isSelected: _customBackgroundColor == const Color(0xFFFDF6E3) && 
                                   _customTextColor == const Color(0xFF5C4A2E),
                        onTap: () {
                          setState(() {
                            _customBackgroundColor = const Color(0xFFFDF6E3);
                            _customTextColor = const Color(0xFF5C4A2E);
                          });
                          setModalState(() {});
                        },
                      ),
                      _buildColorThemeButton(
                        theme: theme,
                        backgroundColor: const Color(0xFFF4ECD8),
                        textColor: const Color(0xFF3E2723),
                        isSelected: _customBackgroundColor == const Color(0xFFF4ECD8) && 
                                   _customTextColor == const Color(0xFF3E2723),
                        onTap: () {
                          setState(() {
                            _customBackgroundColor = const Color(0xFFF4ECD8);
                            _customTextColor = const Color(0xFF3E2723);
                          });
                          setModalState(() {});
                        },
                      ),
                      _buildColorThemeButton(
                        theme: theme,
                        backgroundColor: const Color(0xFF2E3440),
                        textColor: const Color(0xFFECEFF4),
                        isSelected: _customBackgroundColor == const Color(0xFF2E3440) && 
                                   _customTextColor == const Color(0xFFECEFF4),
                        onTap: () {
                          setState(() {
                            _customBackgroundColor = const Color(0xFF2E3440);
                            _customTextColor = const Color(0xFFECEFF4);
                          });
                          setModalState(() {});
                        },
                      ),
                      _buildColorThemeButton(
                        theme: theme,
                        backgroundColor: const Color(0xFF1A1A1A),
                        textColor: const Color(0xFFE0E0E0),
                        isSelected: _customBackgroundColor == const Color(0xFF1A1A1A) && 
                                   _customTextColor == const Color(0xFFE0E0E0),
                        onTap: () {
                          setState(() {
                            _customBackgroundColor = const Color(0xFF1A1A1A);
                            _customTextColor = const Color(0xFFE0E0E0);
                          });
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Custom Colors Section
                  Text(
                    'Свои цвета',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _customTextColor ?? theme.textPrimaryColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Text Color
                  _buildColorPicker(
                    theme: theme,
                    icon: Icons.format_color_text_rounded,
                    title: 'Цвет текста',
                    currentColor: _customTextColor ?? theme.textPrimaryColor,
                    onTap: () => _showColorPickerDialog(
                      parentContext,
                      theme,
                      'Цвет текста',
                      _customTextColor ?? theme.textPrimaryColor,
                      (color) {
                        setState(() => _customTextColor = color);
                        setModalState(() {});
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Background Color
                  _buildColorPicker(
                    theme: theme,
                    icon: Icons.format_color_fill_rounded,
                    title: 'Цвет фона',
                    currentColor: _customBackgroundColor ?? theme.backgroundColor,
                    onTap: () => _showColorPickerDialog(
                      parentContext,
                      theme,
                      'Цвет фона',
                      _customBackgroundColor ?? theme.backgroundColor,
                      (color) {
                        setState(() => _customBackgroundColor = color);
                        setModalState(() {});
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Font Selection
                  Text(
                    'Выбор шрифта',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _customTextColor ?? theme.textPrimaryColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildFontOption(
                    theme,
                    fontProvider,
                    FontProvider.defaultFont,
                    setModalState,
                  ),
                  _buildFontOption(
                    theme,
                    fontProvider,
                    FontProvider.timesNewRoman,
                    setModalState,
                  ),
                  _buildFontOption(
                    theme,
                    fontProvider,
                    FontProvider.montserrat,
                    setModalState,
                  ),
                  _buildFontOption(
                    theme,
                    fontProvider,
                    FontProvider.cormorantGaramond,
                    setModalState,
                  ),
                  _buildFontOption(
                    theme,
                    fontProvider,
                    FontProvider.merriweather,
                    setModalState,
                  ),

                  const SizedBox(height: 28),

                  // Text Alignment
                  Text(
                    'Выравнивание текста',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _customTextColor ?? theme.textPrimaryColor,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildAlignmentOption(
                          theme: theme,
                          icon: Icons.format_align_left,
                          label: 'Слева',
                          alignment: TextAlign.left,
                          isSelected: _textAlign == TextAlign.left,
                          onTap: () {
                            setState(() => _textAlign = TextAlign.left);
                            setModalState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAlignmentOption(
                          theme: theme,
                          icon: Icons.format_align_justify,
                          label: 'По ширине',
                          alignment: TextAlign.justify,
                          isSelected: _textAlign == TextAlign.justify,
                          onTap: () {
                            setState(() => _textAlign = TextAlign.justify);
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Paragraph Indent Toggle
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.format_indent_increase,
                            color: _customTextColor ?? theme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Отступ абзаца',
                                style: TextStyle(
                                  color: _customTextColor ?? theme.textPrimaryColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Красная строка',
                                style: TextStyle(
                                  color: (_customTextColor ?? theme.textSecondaryColor).withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _enableIndent,
                          onChanged: (value) {
                            setState(() => _enableIndent = value);
                            setModalState(() {});
                          },
                          activeColor: _customTextColor ?? theme.primaryColor,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFontOption(
    ThemeProvider theme,
    FontProvider fontProvider,
    String font,
    StateSetter setModalState,
  ) {
    final isSelected = fontProvider.fontFamily == font;
    
    return InkWell(
      onTap: () {
        fontProvider.setFontFamily(font);
        setModalState(() {});
        setState(() {});
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? (_customTextColor ?? theme.primaryColor)
                : (_customTextColor ?? theme.borderColor).withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                FontProvider.getFontDisplayName(font),
                style: TextStyle(
                  fontFamily: font == FontProvider.defaultFont ? null : font,
                  fontSize: 16,
                  color: _customTextColor ?? theme.textPrimaryColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: _customTextColor ?? theme.primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextWithIndent(FontProvider fontProvider, ThemeProvider theme) {
    final content = _chapter?['content'] ?? '';
    final baseStyle = fontProvider.getTextStyle(color: _customTextColor ?? theme.textPrimaryColor);
    
    return RichText(
      textAlign: _textAlign,
      text: TextSpan(
        children: [
          // Добавляем отступ в начале текста
          TextSpan(
            text: '        ', // 8 пробелов для красной строки
            style: baseStyle,
          ),
          TextSpan(
            text: content,
            style: baseStyle,
          ),
        ],
      ),
    );
  }

  Widget _buildAlignmentOption({
    required ThemeProvider theme,
    required IconData icon,
    required String label,
    required TextAlign alignment,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.15)
              : (_customTextColor ?? theme.inputBackgroundColor).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? (_customTextColor ?? theme.primaryColor) 
                : (_customTextColor ?? theme.borderColor).withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? (_customTextColor ?? theme.primaryColor) 
                  : (_customTextColor ?? theme.textSecondaryColor).withValues(alpha: 0.6),
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected 
                    ? (_customTextColor ?? theme.primaryColor) 
                    : (_customTextColor ?? theme.textSecondaryColor).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required double value,
    required String displayValue,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (_customTextColor ?? color).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_customTextColor ?? color).withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_customTextColor ?? color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _customTextColor ?? color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: _customTextColor ?? theme.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _customTextColor ?? color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: (_customTextColor ?? color).computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _customTextColor ?? color,
              inactiveTrackColor: (_customTextColor ?? color).withValues(alpha: 0.2),
              thumbColor: _customTextColor ?? color,
              overlayColor: (_customTextColor ?? color).withValues(alpha: 0.2),
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorThemeButton({
    required ThemeProvider theme,
    required Color backgroundColor,
    required Color textColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.borderColor.withValues(alpha: 0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            'А',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorPicker({
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required Color currentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_customTextColor ?? theme.primaryColor).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _customTextColor ?? theme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: _customTextColor ?? theme.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_customTextColor ?? theme.borderColor).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPickerDialog(
    BuildContext context,
    ThemeProvider theme,
    String title,
    Color currentColor,
    Function(Color) onColorSelected,
  ) {
    Color selectedColor = currentColor;
    double hue = HSVColor.fromColor(currentColor).hue;
    double saturation = HSVColor.fromColor(currentColor).saturation;
    double value = HSVColor.fromColor(currentColor).value;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: theme.textPrimaryColor,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: Icon(
                            Icons.close_rounded,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Цветовая панель с градиентом
                    SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanUpdate: (details) {
                              final width = constraints.maxWidth;
                              final height = constraints.maxHeight;
                              final localX = details.localPosition.dx.clamp(0.0, width);
                              final localY = details.localPosition.dy.clamp(0.0, height);
                              
                              setDialogState(() {
                                saturation = (localX / width).clamp(0.0, 1.0);
                                value = 1.0 - (localY / height).clamp(0.0, 1.0);
                                selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
                              });
                            },
                            onTapDown: (details) {
                              final width = constraints.maxWidth;
                              final height = constraints.maxHeight;
                              final localX = details.localPosition.dx.clamp(0.0, width);
                              final localY = details.localPosition.dy.clamp(0.0, height);
                              
                              setDialogState(() {
                                saturation = (localX / width).clamp(0.0, 1.0);
                                value = 1.0 - (localY / height).clamp(0.0, 1.0);
                                selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor(),
                                  ],
                                ),
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black,
                                    ],
                                  ),
                                ),
                                child: CustomPaint(
                                  painter: _ColorPickerIndicator(
                                    saturation: saturation,
                                    value: value,
                                  ),
                                  size: const Size(double.infinity, 250),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Слайдер оттенка (Hue) с радужным градиентом
                    SizedBox(
                      height: 40,
                      width: double.infinity,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            onPanUpdate: (details) {
                              final width = constraints.maxWidth;
                              final localX = details.localPosition.dx.clamp(0.0, width);
                              
                              setDialogState(() {
                                hue = (localX / width * 360).clamp(0.0, 360.0);
                                selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
                              });
                            },
                            onTapDown: (details) {
                              final width = constraints.maxWidth;
                              final localX = details.localPosition.dx.clamp(0.0, width);
                              
                              setDialogState(() {
                                hue = (localX / width * 360).clamp(0.0, 360.0);
                                selectedColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF0000), // Red
                                    Color(0xFFFFFF00), // Yellow
                                    Color(0xFF00FF00), // Green
                                    Color(0xFF00FFFF), // Cyan
                                    Color(0xFF0000FF), // Blue
                                    Color(0xFFFF00FF), // Magenta
                                    Color(0xFFFF0000), // Red
                                  ],
                                ),
                              ),
                              child: CustomPaint(
                                painter: _HueSliderIndicator(hue: hue),
                                size: const Size(double.infinity, 40),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Превью выбранного цвета
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.borderColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Пример',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: selectedColor.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Кнопки
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: theme.inputBackgroundColor,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => Navigator.pop(dialogContext),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 50,
                                alignment: Alignment.center,
                                child: Text(
                                  'Отмена',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textSecondaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Material(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () {
                                onColorSelected(selectedColor);
                                Navigator.pop(dialogContext);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                height: 50,
                                alignment: Alignment.center,
                                child: const Text(
                                  'Принять',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Custom painter для индикатора на цветовой панели
class _ColorPickerIndicator extends CustomPainter {
  final double saturation;
  final double value;

  _ColorPickerIndicator({
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final dx = saturation * size.width;
    final dy = (1 - value) * size.height;

    canvas.drawCircle(Offset(dx, dy), 10, paint);
    
    paint.color = Colors.black;
    paint.strokeWidth = 1.5;
    canvas.drawCircle(Offset(dx, dy), 10, paint);
  }

  @override
  bool shouldRepaint(_ColorPickerIndicator oldDelegate) {
    return oldDelegate.saturation != saturation || oldDelegate.value != value;
  }
}

// Custom painter для индикатора на слайдере оттенка
class _HueSliderIndicator extends CustomPainter {
  final double hue;

  _HueSliderIndicator({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final dx = (hue / 360) * size.width;
    final center = Offset(dx, size.height / 2);

    canvas.drawCircle(center, 12, paint);
    
    paint.color = Colors.black;
    paint.strokeWidth = 1.5;
    canvas.drawCircle(center, 12, paint);
  }

  @override
  bool shouldRepaint(_HueSliderIndicator oldDelegate) {
    return oldDelegate.hue != hue;
  }
}