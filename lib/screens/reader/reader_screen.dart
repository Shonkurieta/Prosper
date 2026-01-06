import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/bookmark_service.dart';

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

class _ReaderScreenState extends State<ReaderScreen> with SingleTickerProviderStateMixin {
  final BookService _bookService = BookService();
  final BookmarkService _bookmarkService = BookmarkService();
  final ScrollController _scrollController = ScrollController();

  Map<String, dynamic>? _chapter;
  int _currentChapter = 1;
  int _totalChapters = 0;
  bool _isLoading = true;
  bool _showControls = true;
  double _fontSize = 18;
  double _brightness = 1.0;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapterOrder;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadChapter();
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChapter() async {
    setState(() => _isLoading = true);
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
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Ошибка загрузки: $e')),
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
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              title: Text(
                _chapter?['title'] ?? 'Глава $_currentChapter',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2D3436),
                  fontWeight: FontWeight.w700,
                ),
              ),
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF4ECDC4)),
                  onPressed: () => Navigator.pop(context),
                  iconSize: 20,
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune_rounded, color: Color(0xFF4ECDC4)),
                    onPressed: _showFontSettings,
                    iconSize: 22,
                  ),
                ),
              ],
            )
          : null,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFF4ECDC4),
                strokeWidth: 2.5,
              ),
            )
          : GestureDetector(
              onTap: _toggleControls,
              child: Stack(
                children: [
                  // Decorative background
                  Positioned(
                    top: -size.height * 0.15,
                    left: -size.width * 0.25,
                    child: Container(
                      width: size.width * 0.8,
                      height: size.width * 0.8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFE66D).withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -size.height * 0.1,
                    right: -size.width * 0.2,
                    child: Container(
                      width: size.width * 0.7,
                      height: size.width * 0.7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
                      ),
                    ),
                  ),

                  // Content
                  Opacity(
                    opacity: _brightness,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        _showControls ? 24 : 80,
                        24,
                        120,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chapter badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_stories_outlined,
                                  color: Color(0xFF4ECDC4),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Глава $_currentChapter из $_totalChapters',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4ECDC4),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Chapter title
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _chapter?['title'] ?? 'Без названия',
                              style: TextStyle(
                                fontSize: _fontSize + 8,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF2D3436),
                                height: 1.3,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Content
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              _chapter?['content'] ?? '',
                              style: TextStyle(
                                fontSize: _fontSize,
                                height: 1.9,
                                color: const Color(0xFF2D3436),
                                letterSpacing: 0.2,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Navigation bottom bar
                  if (_showControls)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, 100 * (1 - _animController.value)),
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 20,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                // Previous button
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: _currentChapter > 1 ? _prevChapter : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _currentChapter > 1
                                            ? const Color(0xFFF5F7FA)
                                            : const Color(0xFFF5F7FA).withValues(alpha: 0.5),
                                        foregroundColor: _currentChapter > 1
                                            ? const Color(0xFF4ECDC4)
                                            : const Color(0xFF636E72).withValues(alpha: 0.3),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.chevron_left_rounded, size: 24),
                                          SizedBox(width: 4),
                                          Text(
                                            'Назад',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Chapter counter
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4ECDC4),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF4ECDC4).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '$_currentChapter/$_totalChapters',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),

                                // Next button
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: ElevatedButton(
                                      onPressed: _currentChapter < _totalChapters
                                          ? _nextChapter
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _currentChapter < _totalChapters
                                            ? const Color(0xFF4ECDC4)
                                            : const Color(0xFFF5F7FA).withValues(alpha: 0.5),
                                        foregroundColor: Colors.white,
                                        disabledForegroundColor:
                                            const Color(0xFF636E72).withValues(alpha: 0.3),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Text(
                                            'Вперёд',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.chevron_right_rounded, size: 24),
                                        ],
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
                ],
              ),
            ),
    );
  }

  void _showFontSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF636E72).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Настройки чтения',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2D3436),
                  ),
                ),
                const SizedBox(height: 32),

                // Font size
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.format_size_rounded,
                              color: Color(0xFF4ECDC4),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Размер шрифта',
                            style: TextStyle(
                              color: Color(0xFF2D3436),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ECDC4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_fontSize.round()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: const Color(0xFF4ECDC4),
                          inactiveTrackColor: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
                          thumbColor: const Color(0xFF4ECDC4),
                          overlayColor: const Color(0xFF4ECDC4).withValues(alpha: 0.2),
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _fontSize,
                          min: 14,
                          max: 28,
                          divisions: 7,
                          onChanged: (value) {
                            setState(() => _fontSize = value);
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Brightness
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE66D).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.wb_sunny_outlined,
                              color: Color(0xFFFFE66D),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Яркость',
                            style: TextStyle(
                              color: Color(0xFF2D3436),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE66D),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${(_brightness * 100).round()}%',
                              style: const TextStyle(
                                color: Color(0xFF2D3436),
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: const Color(0xFFFFE66D),
                          inactiveTrackColor: const Color(0xFFFFE66D).withValues(alpha: 0.2),
                          thumbColor: const Color(0xFFFFE66D),
                          overlayColor: const Color(0xFFFFE66D).withValues(alpha: 0.2),
                          trackHeight: 6,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        ),
                        child: Slider(
                          value: _brightness,
                          min: 0.5,
                          max: 1.0,
                          onChanged: (value) {
                            setState(() => _brightness = value);
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}