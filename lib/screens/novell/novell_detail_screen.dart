import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prosper/widgets/comments_widget.dart';
import 'package:prosper/widgets/reviews_widget.dart';
import 'package:prosper/services/related_book_service.dart';
import 'package:prosper/services/rating_service.dart';

class NovellDetailScreen extends StatefulWidget {
  final String token;
  final int bookId;
  final int initialTab;
  final int? scrollToCommentId;

  const NovellDetailScreen({
    super.key,
    required this.token,
    required this.bookId,
    this.initialTab = 0,
    this.scrollToCommentId,
  });

  @override
  State<NovellDetailScreen> createState() => _NovellDetailScreenState();
}

class _NovellDetailScreenState extends State<NovellDetailScreen>
    with TickerProviderStateMixin {
  final BookService _bookService = BookService();
  final BookmarkService _bookmarkService = BookmarkService();

  Map<String, dynamic>? _book;
  List<dynamic> _chapters = [];
  List<dynamic> _relatedBooks = [];
  Map<String, dynamic>? _ratingData;
  bool _isLoading = true;
  bool _isBookmarked = false;
  bool _isSubscribed = false;
  String? _currentStatus;
  int _currentChapter = 1;
  String _currentUsername = 'Гость';

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late TabController _tabController;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });

    if (widget.initialTab != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tabController.animateTo(widget.initialTab);
      });
    }

    _loadBookDetails();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUsername = prefs.getString('username') ?? 'Гость';
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookDetails() async {
    try {
      final relatedBookService = RelatedBookService();

      // Launch all 5 requests simultaneously — none awaited until all are in flight
      final bookFuture = _bookService.getBookById(widget.token, widget.bookId);
      final chaptersFuture = _bookService.getBookChapters(widget.token, widget.bookId);
      final progressFuture = widget.token.isEmpty
          ? Future.value(<String, dynamic>{})
          : _bookmarkService.getProgress(widget.token, widget.bookId);
      final relatedFuture = relatedBookService.getRelatedBooks(widget.token, widget.bookId);
      final ratingFuture = RatingService.getRating(widget.token, widget.bookId);

      final book = await bookFuture;
      final chapters = await chaptersFuture;
      final progress = await progressFuture;

      List<dynamic> relatedBooks = [];
      try { relatedBooks = await relatedFuture; } catch (_) {}

      Map<String, dynamic>? ratingData;
      try { ratingData = await ratingFuture; } catch (_) {}

      setState(() {
        _book = book;
        _chapters = chapters;
        _relatedBooks = relatedBooks;
        _ratingData = ratingData;
        _currentChapter = progress['currentChapter'] ?? 1;
        _isBookmarked = progress['isBookmarked'] ?? false;
        _isSubscribed = progress['isSubscribed'] ?? false;
        _currentStatus = progress['status'];
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  void _showBookmarkCategories() {
    final theme = context.read<ThemeProvider>();
    final statuses = [
      {'id': BookmarkService.READING, 'name': 'Читаю'},
      {'id': BookmarkService.PLANNED, 'name': 'В планах'},
      {'id': BookmarkService.COMPLETED, 'name': 'Прочитано'},
      {'id': BookmarkService.FAVORITE, 'name': 'Любимое'},
      {'id': BookmarkService.DROPPED, 'name': 'Брошено'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Выберите категорию',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimaryColor,
                  ),
                ),
              ),
              ...statuses.map((status) {
                final isSelected =
                    _currentStatus == status['id'] && _isBookmarked;
                return ListTile(
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? accentColor : Colors.grey,
                  ),
                  title: Text(
                    status['name']!,
                    style: TextStyle(
                      color: isSelected ? accentColor : theme.textPrimaryColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _updateBookmark(status['id']!);
                  },
                );
              }),
              if (_isBookmarked)
                ListTile(
                  leading: const Icon(Icons.delete_outline,
                      color: Colors.redAccent),
                  title: const Text('Удалить из закладок',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeBookmark();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateBookmark(String status) async {
    final theme = context.read<ThemeProvider>();
    try {
      await _bookmarkService.addBookmark(widget.token, widget.bookId,
          status: status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Добавлено в "${BookmarkService.getStatusDisplayName(status)}"'),
            backgroundColor: theme.successColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      _loadBookDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _subscribe() async {
    final theme = context.read<ThemeProvider>();
    try {
      await _bookmarkService.subscribe(widget.token, widget.bookId);
      if (mounted) {
        setState(() => _isSubscribed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Подписаны! Вы будете получать уведомления о новых главах'),
            backgroundColor: theme.successColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подписки: $e')),
        );
      }
    }
  }

  Future<void> _unsubscribe() async {
    final theme = context.read<ThemeProvider>();
    try {
      await _bookmarkService.unsubscribe(widget.token, widget.bookId);
      if (mounted) {
        setState(() => _isSubscribed = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Вы отписались от уведомлений'),
            backgroundColor: theme.warningColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отписки: $e')),
        );
      }
    }
  }

  Future<void> _removeBookmark() async {
    final theme = context.read<ThemeProvider>();
    try {
      await _bookmarkService.removeBookmark(widget.token, widget.bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Удалено из закладок'),
            backgroundColor: theme.warningColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      _loadBookDetails();
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
        body: const Center(
            child: CircularProgressIndicator(color: accentColor)),
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
        body: Center(
            child: Text('Новелла не найдена',
                style: TextStyle(color: theme.textPrimaryColor))),
      );
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  _buildSliverHeader(theme),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      child: _buildConstantArea(theme),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        labelColor: accentColor,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: accentColor,
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: const [
                          Tab(text: 'О тайтле'),
                          Tab(text: 'Главы'),
                          Tab(text: 'Комм.'),
                          Tab(text: 'Отзывы'),
                        ],
                      ),
                      theme.backgroundColor,
                    ),
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(theme),
                  _buildChaptersTab(theme),
                  _buildCommentsTab(theme),
                  _buildReviewsTab(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader(ThemeProvider theme) {
    return SliverAppBar(
      expandedHeight: 280,
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
          child: const Icon(Icons.arrow_back_ios_new,
              color: accentColor, size: 18),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              ApiConstants.getCoverUrl(_book!['coverUrl'] ?? ''),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: theme.cardColor),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.backgroundColor.withValues(alpha: 0.1),
                    theme.backgroundColor.withValues(alpha: 0.6),
                    theme.backgroundColor,
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 40),
                width: 140,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    ApiConstants.getCoverUrl(_book!['coverUrl'] ?? ''),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildPlaceholder(theme),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRatingCount(int count) {
    if (count < 1000) return '$count';
    final k = count / 1000;
    if (k < 10) return '${k.toStringAsFixed(1)}к';
    return '${k.toStringAsFixed(0)}к';
  }

    void _showRatingModal() {
    final userRating = _ratingData?['userRating'] as int?;
    int selectedRating = userRating ?? 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Dialog(
              backgroundColor: context.read<ThemeProvider>().cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: context.read<ThemeProvider>().borderColor, width: 1),
              ),
              // Ограничиваем максимальную ширину диалога
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(ctx).size.width * 0.9,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Заголовок
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: accentColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Оценка тайтла',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context
                                  .read<ThemeProvider>()
                                  .textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Адаптивные звёздочки через LayoutBuilder
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Считаем доступную ширину и вычисляем размер иконки
                          final availableWidth = constraints.maxWidth;
                          // 10 звёздочек + горизонтальные паддинги (2*2=4 на каждую)
                          final starSize =
                              ((availableWidth - 10 * 4) / 10).clamp(18.0, 32.0);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(10, (i) {
                              final starNum = i + 1;
                              final isActive = starNum <= selectedRating;
                              return GestureDetector(
                                onTap: () => setModalState(
                                    () => selectedRating = starNum),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: Icon(
                                    isActive
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: isActive
                                        ? accentColor
                                        : context
                                            .read<ThemeProvider>()
                                            .textSecondaryColor
                                            .withValues(alpha: 0.4),
                                    size: starSize,
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),

                      if (selectedRating > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$selectedRating / 10',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Кнопки
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(
                              'Отмена',
                              style: TextStyle(
                                  color: context.read<ThemeProvider>().textPrimaryColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: ElevatedButton(
                              onPressed: selectedRating == 0
                                  ? null
                                  : () async {
                                      Navigator.of(ctx).pop();
                                      try {
                                        final result = await RatingService.rateBook(
                                          widget.token,
                                          widget.bookId,
                                          selectedRating,
                                        );
                                        setState(() => _ratingData = result);
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Ошибка: $e')),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                userRating != null ? 'Изменить' : 'Оценить',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildRatingBlock(ThemeProvider theme) {
    final avg = (_ratingData?['averageRating'] as num?);
    final count = (_ratingData?['ratingCount'] as num?)?.toInt() ?? 0;
    final userRating = _ratingData?['userRating'] as int?;

    return GestureDetector(
      onTap: _showRatingModal,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.borderColor, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              userRating != null ? Icons.star : Icons.star_border,
              color: accentColor,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              avg != null ? avg.toStringAsFixed(1) : '—',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.textPrimaryColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${_formatRatingCount(count)})',
              style: TextStyle(
                fontSize: 13,
                color: theme.textSecondaryColor,
              ),
            ),
            if (userRating != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Вы: $userRating',
                  style: const TextStyle(
                    fontSize: 11,
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConstantArea(ThemeProvider theme) {
    return Column(
      children: [
        Text(
          _book!['title'] ?? 'Без названия',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: theme.textPrimaryColor,
          ),
        ),
        const SizedBox(height: 12),
        _buildRatingBlock(theme),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.token.isEmpty
                    ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Войдите в аккаунт, чтобы добавлять новеллы в закладки')))
                    : _showBookmarkCategories,
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(_isBookmarked
                    ? BookmarkService.getStatusDisplayName(
                        _currentStatus ?? '')
                    : 'В закладки'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: const BorderSide(color: accentColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.token.isEmpty
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Войдите в аккаунт, чтобы подписываться на обновления')))
                    : (_isSubscribed ? _unsubscribe : _subscribe),
                icon: Icon(
                  _isSubscribed
                      ? Icons.notifications_active
                      : Icons.notifications_none,
                  size: 18,
                ),
                label: Text(_isSubscribed ? 'Подписан' : 'Подписаться'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: const BorderSide(color: accentColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _chapters.isNotEmpty ? () => _openReader(_currentChapter) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(
              _currentChapter > 1 ? 'Продолжить чтение' : 'Начать чтение',
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChaptersTab(ThemeProvider theme) {
    if (_chapters.isEmpty) {
      return Center(
        child: Text('Главы скоро появятся',
            style: TextStyle(color: theme.textSecondaryColor)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _chapters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        final isCurrent = chapter['chapterOrder'] == _currentChapter;
        return InkWell(
          onTap: () => _openReader(chapter['chapterOrder']),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrent
                  ? accentColor.withValues(alpha: 0.05)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent
                    ? accentColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCurrent ? accentColor : theme.backgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${chapter['chapterOrder']}',
                      style: TextStyle(
                        color: isCurrent
                            ? Colors.white
                            : theme.textSecondaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    chapter['title'] ?? 'Глава ${chapter['chapterOrder']}',
                    style: TextStyle(
                      color: theme.textPrimaryColor,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 14,
                    color: theme.textSecondaryColor.withValues(alpha: 0.5)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentsTab(ThemeProvider theme) {
    return CommentsWidget(
      token: widget.token,
      bookId: widget.bookId,
      currentUsername: _currentUsername,
      scrollToCommentId: widget.scrollToCommentId,
    );
  }

  Widget _buildReviewsTab(ThemeProvider theme) {
    return ReviewsWidget(
      token: widget.token,
      bookId: widget.bookId,
      currentUsername: _currentUsername,
    );
  }

  Widget _buildAboutTab(ThemeProvider theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(theme, 'Автор', _book!['author'] ?? 'Неизвестен'),
          const SizedBox(height: 16),
          _buildSectionLabel(theme, 'Жанры'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_book!['genres'] as List<dynamic>? ?? [])
                .map((g) {
                  final String genreName =
                      g is Map ? (g['name'] ?? '') : g.toString();
                  return Chip(
                    label: Text(genreName,
                        style: const TextStyle(
                            fontSize: 12, color: accentColor)),
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  );
                })
                .toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionLabel(theme, 'Аннотация'),
          const SizedBox(height: 8),
          Text(
            _book!['description'] ?? 'Нет описания',
            style: TextStyle(
              color: theme.textSecondaryColor,
              height: 1.6,
              fontSize: 15,
              fontWeight: FontWeight.w300,
            ),
          ),
          if (_relatedBooks.isNotEmpty) ...[
            const SizedBox(height: 32),
            _buildSectionLabel(theme, 'Связанное'),
            const SizedBox(height: 12),
            _buildRelatedBooksSection(theme),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildRelatedBooksSection(ThemeProvider theme) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _relatedBooks.length,
        itemBuilder: (_, index) {
          final related = _relatedBooks[index];
          final String relationType = related['relationType'] ?? 'SEQUEL';

          final String typeLabel = relationType == 'SEQUEL'
              ? 'Сиквел'
              : relationType == 'PREQUEL'
                  ? 'Приквел'
                  : 'Побочная';

          final Color badgeColor = relationType == 'SEQUEL'
              ? accentColor
              : relationType == 'PREQUEL'
                  ? const Color(0xFF5B8FD4)
                  : const Color(0xFF8F6BC4);

          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 10,
              right: index == _relatedBooks.length - 1 ? 0 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                final relatedId = related['relatedBookId'];
                if (relatedId == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NovellDetailScreen(
                      token: widget.token,
                      bookId: relatedId as int,
                    ),
                  ),
                );
              },
              child: SizedBox(
                width: 110,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover + badge overlay
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            ApiConstants.getCoverUrl(
                                related['relatedBookCoverUrl'] ?? ''),
                            height: 158,
                            width: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 158,
                              width: 110,
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.book_outlined,
                                  color: theme.textSecondaryColor, size: 32),
                            ),
                          ),
                        ),
                        // Type badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Text(
                              typeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Title
                    Text(
                      related['relatedBookTitle'] ?? 'Без названия',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimaryColor,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(ThemeProvider theme, String label, String value) {
    return Row(
      children: [
        Text('$label: ',
            style: TextStyle(
                color: theme.textSecondaryColor,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: TextStyle(
                color: theme.textPrimaryColor,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSectionLabel(ThemeProvider theme, String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: theme.textPrimaryColor,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Container(
      color: theme.cardColor,
      child:
          const Center(child: Icon(Icons.book, color: accentColor, size: 40)),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar, this._backgroundColor);

  final TabBar _tabBar;
  final Color _backgroundColor;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: _backgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}