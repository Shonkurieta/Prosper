import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prosper/widgets/comments_widget.dart';

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
    with TickerProviderStateMixin {
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
  
  late TabController _tabController;

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
    
    _tabController = TabController(length: 4, vsync: this);
    
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
    _tabController.dispose();
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
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                _buildSliverHeader(theme),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                        Tab(text: 'Главы'),
                        Tab(text: 'Комм.'),
                        Tab(text: 'Отзывы'),
                        Tab(text: 'О тайтле'),
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
                _buildChaptersTab(theme),
                _buildCommentsTab(theme),
                _buildReviewsTab(theme),
                _buildAboutTab(theme),
              ],
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
          child: const Icon(Icons.arrow_back_ios_new, color: accentColor, size: 18),
        ),
      ),
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleBookmark,
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                ),
                label: Text(_isBookmarked ? 'В закладках' : 'В закладки'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: const BorderSide(color: accentColor),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Consumer<NotificationProvider>(
                builder: (context, notificationProvider, child) {
                  final isSubscribed = notificationProvider.isSubscribed(widget.bookId);
                  return OutlinedButton.icon(
                    onPressed: () {
                      notificationProvider.toggleSubscription(widget.bookId);
                    },
                    icon: Icon(
                      isSubscribed ? Icons.notifications_active : Icons.notifications_none,
                      size: 18,
                    ),
                    label: const Text('Подписаться'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: const BorderSide(color: accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChaptersTab(ThemeProvider theme) {
    if (_chapters.isEmpty) {
      return Center(
        child: Text('Главы скоро появятся', style: TextStyle(color: theme.textSecondaryColor)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _chapters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final chapter = _chapters[index];
        final isCurrent = chapter['orderIndex'] == _currentChapter;
        return InkWell(
          onTap: () => _openReader(chapter['orderIndex']),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrent ? accentColor.withValues(alpha: 0.05) : theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent ? accentColor.withValues(alpha: 0.3) : Colors.transparent,
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
                      '${chapter['orderIndex']}',
                      style: TextStyle(
                        color: isCurrent ? Colors.white : theme.textSecondaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    chapter['title'] ?? 'Глава ${chapter['orderIndex']}',
                    style: TextStyle(
                      color: theme.textPrimaryColor,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: theme.textSecondaryColor.withValues(alpha: 0.5)),
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
    );
  }

  Widget _buildReviewsTab(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 48, color: theme.textSecondaryColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Здесь пока нету отзывов, будь первым',
            style: TextStyle(color: theme.textSecondaryColor, fontWeight: FontWeight.w300),
          ),
        ],
      ),
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
                  final String genreName = g is Map ? (g['name'] ?? '') : g.toString();
                  return Chip(
                    label: Text(genreName, style: const TextStyle(fontSize: 12, color: accentColor)),
                    backgroundColor: accentColor.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _chapters.isNotEmpty ? () => _openReader(_currentChapter) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                _currentChapter > 1 ? 'Продолжить чтение' : 'Начать чтение',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeProvider theme, String label, String value) {
    return Row(
      children: [
        Text('$label: ', style: TextStyle(color: theme.textSecondaryColor, fontWeight: FontWeight.w500)),
        Text(value, style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold)),
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
      child: const Center(child: Icon(Icons.book, color: accentColor, size: 40)),
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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
