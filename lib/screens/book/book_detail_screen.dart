import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class BookDetailScreen extends StatefulWidget {
  final String token;
  final int bookId;

  const BookDetailScreen({
    super.key,
    required this.token,
    required this.bookId,
  });

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen>
    with SingleTickerProviderStateMixin {
  final BookService _bookService = BookService();
  final BookmarkService _bookmarkService = BookmarkService();

  Map<String, dynamic>? _book;
  List<dynamic> _chapters = [];
  bool _isLoading = true;
  bool _isBookmarked = false;
  int _currentChapter = 1;
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
      curve: Curves.easeInOut,
    );
    _loadBookDetails();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadBookDetails() async {
    try {
      final book = await _bookService.getBookById(widget.token, widget.bookId);
      final chapters = await _bookService.getBookChapters(widget.token, widget.bookId);
      final progress = await _bookmarkService.getProgress(
        widget.token,
        widget.bookId,
      );

      setState(() {
        _book = book;
        _chapters = chapters;
        _currentChapter = progress['currentChapter'] ?? 1;
        _isBookmarked = progress['isBookmarked'] ?? false;
        _isLoading = false;
      });
      _animController.forward();
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

  Future<void> _toggleBookmark() async {
    final theme = context.read<ThemeProvider>();
    try {
      if (_isBookmarked) {
        await _bookmarkService.removeBookmark(widget.token, widget.bookId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.bookmark_remove, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Удалено из закладок'),
                ],
              ),
              backgroundColor: theme.warningColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(20),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        await _bookmarkService.addBookmark(widget.token, widget.bookId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.bookmark_added, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Добавлено в закладки'),
                ],
              ),
              backgroundColor: theme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(20),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
      setState(() => _isBookmarked = !_isBookmarked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _openReader(int chapterOrder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          token: widget.token,
          bookId: widget.bookId,
          chapterOrder: chapterOrder,
        ),
      ),
    ).then((_) => _loadBookDetails());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        if (_isLoading) {
          return Scaffold(
            backgroundColor: theme.backgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: theme.primaryColor,
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        if (_book == null) {
          return Scaffold(
            backgroundColor: theme.backgroundColor,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              title: const Text('Ошибка'),
            ),
            body: Center(
              child: Text(
                'Новелла не найдена',
                style: TextStyle(color: theme.textPrimaryColor),
              ),
            ),
          );
        }

        // Проверяем, есть ли главы
        final hasChapters = _chapters.isNotEmpty;

        return Scaffold(
          backgroundColor: theme.backgroundColor,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [theme.cardShadow],
                ),
                child: Icon(Icons.arrow_back, color: theme.primaryColor),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [theme.cardShadow],
                  ),
                  child: Icon(
                    _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: _isBookmarked ? theme.primaryColor : theme.textSecondaryColor,
                  ),
                ),
                onPressed: _toggleBookmark,
              ),
            ],
          ),
          body: FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                // Hero cover
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.only(top: 120, bottom: 30),
                    child: Column(
                      children: [
                        Hero(
                          tag: 'book-${widget.bookId}',
                          child: Container(
                            width: 200,
                            height: 300,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor,
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: _book!['coverUrl'] != null && _book!['coverUrl'].toString().isNotEmpty
                                  ? Image.network(
                                      ApiConstants.getCoverUrl(_book!['coverUrl']),
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Container(
                                          color: theme.cardColor,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              color: theme.primaryColor,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return _buildPlaceholder(theme);
                                      },
                                    )
                                  : _buildPlaceholder(theme),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              Text(
                                _book!['title'] ?? 'Без названия',
                                style: TextStyle(
                                  color: theme.textPrimaryColor,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _book!['author'] ?? 'Неизвестный автор',
                                style: TextStyle(
                                  color: theme.textSecondaryColor,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: hasChapters ? () => _openReader(_currentChapter) : null,
                            icon: Icon(
                              hasChapters ? Icons.play_arrow_rounded : Icons.menu_book_outlined,
                            ),
                            label: Text(
                              hasChapters
                                  ? (_currentChapter > 1
                                      ? 'Продолжить (гл. $_currentChapter)'
                                      : 'Начать читать')
                                  : 'Нет глав',
                            ),
                            style: hasChapters
                                ? theme.getPrimaryButtonStyle().copyWith(
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  )
                                : ElevatedButton.styleFrom(
                                    backgroundColor: theme.textSecondaryColor.withOpacity(0.3),
                                    foregroundColor: theme.textSecondaryColor,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 56,
                          width: 56,
                          decoration: theme.getCardDecoration(),
                          child: IconButton(
                            onPressed: _toggleBookmark,
                            icon: Icon(
                              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                              color: _isBookmarked ? theme.primaryColor : theme.textSecondaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Description
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Описание',
                          style: TextStyle(
                            color: theme.textPrimaryColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _book!['description'] ?? 'Описание отсутствует',
                          style: TextStyle(
                            color: theme.textSecondaryColor,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Главы',
                              style: TextStyle(
                                color: theme.textPrimaryColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: hasChapters
                                    ? theme.primaryColor.withValues(alpha: 0.15)
                                    : theme.textSecondaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                hasChapters ? '${_chapters.length} глав' : 'Нет глав',
                                style: TextStyle(
                                  color: hasChapters
                                      ? theme.primaryColor
                                      : theme.textSecondaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Chapters list or empty state
                hasChapters
                    ? SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final chapter = _chapters[index];
                            final chapterNum = chapter['chapterOrder'];
                            final isCurrent = chapterNum == _currentChapter;

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrent ? theme.primaryColor : theme.cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: theme.isDarkMode && !isCurrent
                                    ? Border.all(color: theme.borderColor, width: 1.5)
                                    : null,
                                boxShadow: [theme.cardShadow],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isCurrent
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : theme.primaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$chapterNum',
                                      style: TextStyle(
                                        color: isCurrent
                                            ? Colors.white
                                            : theme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  chapter['title'] ?? 'Глава $chapterNum',
                                  style: TextStyle(
                                    color: isCurrent
                                        ? Colors.white
                                        : theme.textPrimaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Icon(
                                  isCurrent
                                      ? Icons.play_circle_filled_rounded
                                      : Icons.arrow_forward_ios_rounded,
                                  color: isCurrent
                                      ? Colors.white
                                      : theme.textSecondaryColor,
                                  size: isCurrent ? 24 : 16,
                                ),
                                onTap: () => _openReader(chapterNum),
                              ),
                            );
                          },
                          childCount: _chapters.length,
                        ),
                      )
                    : SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.borderColor,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: theme.primaryColor.withValues(alpha: 0.1),
                                  ),
                                  child: Icon(
                                    Icons.menu_book_outlined,
                                    size: 60,
                                    color: theme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Главы отсутствуют',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: theme.textPrimaryColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Эта новелла пока не содержит глав для чтения',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textSecondaryColor,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 40),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
      ),
      child: Center(
        child: Icon(
          Icons.book_rounded,
          size: 80,
          color: theme.primaryColor,
        ),
      ),
    );
  }
}