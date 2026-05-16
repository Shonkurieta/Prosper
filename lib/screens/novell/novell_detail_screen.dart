import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NovellDetailScreen extends StatefulWidget {
  final String token;
  final int bookId;

  const NovellDetailScreen({
    super.key,
    required this.token,
    required this.bookId,
  });

  @override
  State<NovellDetailScreen> createState() => _NovellDetailScreenState();
}

class _NovellDetailScreenState extends State<NovellDetailScreen>
    with SingleTickerProviderStateMixin {
  final BookService _bookService = BookService();
  final BookmarkService _bookmarkService = BookmarkService();

  Map<String, dynamic>? _book;
  List<dynamic> _chapters = [];
  bool _isLoading = true;
  bool _isBookmarked = false;
  int _currentChapter = 1;
  String _currentUsername = 'Гость';
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    
    _loadBookDetails();
    _initUserInNotificationProvider();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUsername = prefs.getString('username') ?? 'Гость';
    });
  }

  Future<void> _initUserInNotificationProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('id')?.toString();
    if (mounted) {
      context.read<NotificationProvider>().setCurrentUser(userId);
    }
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
          currentUsername: _currentUsername,
        ),
      ),
    ).then((_) => _loadBookDetails());
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        body: const Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }

    if (_book == null) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: accentColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(child: Text('Новелла не найдена', style: TextStyle(color: theme.textPrimaryColor))),
      );
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              _buildSliverHeader(theme),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    _buildBookInfo(theme),
                    const SizedBox(height: 32),
                    _buildActionButtons(theme),
                    const SizedBox(height: 32),
                    _buildSectionLabel(theme, 'Описание'),
                    const SizedBox(height: 12),
                    _buildDescription(theme),
                    const SizedBox(height: 32),
                    _buildSectionLabel(theme, 'Главы (${_chapters.length})'),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
              _buildChaptersList(theme),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader(ThemeProvider theme) {
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      backgroundColor: theme.backgroundColor,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.backgroundColor.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_new, color: accentColor, size: 18),
        ),
      ),
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, child) {
            final isSubscribed = notificationProvider.isSubscribed(widget.bookId);
            return IconButton(
              onPressed: () {
                notificationProvider.toggleSubscription(widget.bookId);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isSubscribed 
                      ? 'Подписка отменена' 
                      : 'Вы подписались на уведомления о новых главах'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.backgroundColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSubscribed ? Icons.notifications_active : Icons.notifications_none,
                  color: accentColor,
                  size: 20,
                ),
              ),
            );
          },
        ),
        IconButton(
          onPressed: _toggleBookmark,
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.backgroundColor.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: accentColor,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              ApiConstants.getCoverUrl(_book!['coverUrl'] ?? ''),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: theme.cardColor),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.backgroundColor.withValues(alpha: 0.1),
                    theme.backgroundColor.withValues(alpha: 0.8),
                    theme.backgroundColor,
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 60),
                width: 160,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    ApiConstants.getCoverUrl(_book!['coverUrl'] ?? ''),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookInfo(ThemeProvider theme) {
    return Column(
      children: [
        Text(
          _book!['title'] ?? 'Без названия',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: theme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _book!['author'] ?? 'Автор неизвестен',
          style: const TextStyle(
            fontSize: 16,
            color: accentColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: (_book!['genres'] as List<dynamic>? ?? [])
              .map((g) {
                // Обрабатываем как Map {id, name}, так и plain string
                final String genreName = g is Map ? (g['name'] ?? '') : g.toString();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    genreName,
                    style: const TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              })
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeProvider theme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _chapters.isNotEmpty ? () => _openReader(_currentChapter) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              _currentChapter > 1 ? 'Продолжить чтение' : 'Начать чтение',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(ThemeProvider theme, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.textPrimaryColor,
      ),
    );
  }

  Widget _buildDescription(ThemeProvider theme) {
    return Text(
      _book!['description'] ?? 'Описание отсутствует',
      style: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: theme.textSecondaryColor,
      ),
    );
  }

  Widget _buildChaptersList(ThemeProvider theme) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final chapter = _chapters[index];
          final chapterNum = chapter['chapterOrder'];
          final isCurrent = chapterNum == _currentChapter;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: InkWell(
              onTap: () => _openReader(chapterNum),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrent ? accentColor.withValues(alpha: 0.05) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCurrent ? accentColor.withValues(alpha: 0.2) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCurrent ? accentColor : theme.backgroundColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$chapterNum',
                          style: TextStyle(
                            color: isCurrent ? Colors.white : theme.textPrimaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        chapter['title'] ?? 'Глава $chapterNum',
                        style: TextStyle(
                          color: theme.textPrimaryColor,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Icon(
                      isCurrent ? Icons.play_circle_filled : Icons.chevron_right,
                      color: isCurrent ? accentColor : theme.textSecondaryColor.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: _chapters.length,
      ),
    );
  }

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Container(
      color: theme.cardColor,
      child: Center(
        child: Icon(
          Icons.book_rounded,
          size: 60,
          color: theme.textSecondaryColor.withValues(alpha: 0.1),
        ),
      ),
    );
  }
}
