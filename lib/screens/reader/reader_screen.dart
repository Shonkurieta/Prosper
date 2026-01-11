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
  double _brightness = 1.0;
  late AnimationController _controlsAnimController;
  late AnimationController _contentAnimController;
  late Animation<double> _controlsFadeAnimation;
  late Animation<Offset> _controlsSlideAnimation;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapterOrder;
    
    _controlsAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _contentAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
      final chapter = await _bookService.getChapter(
        widget.token,
        widget.bookId,
        _currentChapter,
      );
      final chapters = await _bookService.getBookChapters(widget.token, widget.bookId);
      
      await _bookmarkService.updateProgress(
        widget.token,
        widget.bookId,
        _currentChapter,
      );

      setState(() {
        _chapter = chapter;
        _totalChapters = chapters.length;
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
              appBar: _showControls
                  ? AppBar(
                      backgroundColor: theme.cardColor.withOpacity(0.95),
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
                  : null,
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
                      child: Stack(
                        children: [
                          // Content
                          Opacity(
                            opacity: _brightness,
                            child: AnimatedBuilder(
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
                                padding: EdgeInsets.fromLTRB(
                                  20,
                                  _showControls ? 100 : 60,
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
                                            color: theme.primaryColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: theme.primaryColor.withOpacity(0.3),
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
                                        color: theme.textPrimaryColor,
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

                                    // Content with custom font
                                    Text(
                                      _chapter?['content'] ?? '',
                                      style: fontProvider.getTextStyle(
                                        color: theme.textPrimaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Bottom navigation
                          if (_showControls)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: AnimatedBuilder(
                                animation: _controlsAnimController,
                                builder: (context, child) {
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
                                        color: theme.cardColor.withOpacity(0.9),
                                        border: Border(
                                          top: BorderSide(
                                            color: theme.borderColor,
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
                                                    ? theme.inputBackgroundColor
                                                    : theme.inputBackgroundColor.withOpacity(0.5),
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
                                                              ? theme.primaryColor
                                                              : theme.textSecondaryColor.withOpacity(0.3),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'Назад',
                                                          style: TextStyle(
                                                            fontSize: 15,
                                                            fontWeight: FontWeight.w700,
                                                            color: _currentChapter > 1
                                                                ? theme.primaryColor
                                                                : theme.textSecondaryColor.withOpacity(0.3),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            const SizedBox(width: 12),

                                            // Next button
                                            Expanded(
                                              child: Material(
                                                color: _currentChapter < _totalChapters
                                                    ? theme.primaryColor
                                                    : theme.inputBackgroundColor.withOpacity(0.5),
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
                                                                ? Colors.white
                                                                : theme.textSecondaryColor.withOpacity(0.3),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Icon(
                                                          Icons.arrow_forward_ios_rounded,
                                                          size: 18,
                                                          color: _currentChapter < _totalChapters
                                                              ? Colors.white
                                                              : theme.textSecondaryColor.withOpacity(0.3),
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
            );
          },
        );
      },
    );
  }

  void _showFontSettings(ThemeProvider theme, FontProvider fontProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.cardColor,
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
                      color: theme.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: theme.primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Настройки чтения',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: theme.textPrimaryColor,
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

                  const SizedBox(height: 20),

                  // Brightness
                  _buildSettingItem(
                    theme: theme,
                    icon: Icons.brightness_6_outlined,
                    title: 'Яркость',
                    value: _brightness,
                    displayValue: '${(_brightness * 100).round()}%',
                    min: 0.5,
                    max: 1.0,
                    color: theme.warningColor,
                    onChanged: (value) {
                      setState(() => _brightness = value);
                      setModalState(() {});
                    },
                  ),

                  const SizedBox(height: 28),

                  // Font Selection
                  Text(
                    'Выбор шрифта',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimaryColor,
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
        setState(() {}); // Update main screen too
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? theme.primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? theme.primaryColor 
                : theme.borderColor,
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
                  color: theme.textPrimaryColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: theme.primaryColor,
                size: 24,
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
        color: theme.inputBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
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
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: color == theme.warningColor 
                        ? theme.textPrimaryColor
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
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
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
}