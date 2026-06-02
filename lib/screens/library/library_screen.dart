import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/reading_progress_service.dart';
import 'package:prosper/services/review_service.dart';
import 'package:prosper/screens/novell/novell_detail_screen.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
import 'package:prosper/screens/all_reviews_screen.dart';
import 'package:prosper/screens/review_detail_screen.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LibraryScreen extends StatefulWidget {
  final String token;
  const LibraryScreen({super.key, required this.token});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final BookService _bookService = BookService();
  final ReadingProgressService _progressService = ReadingProgressService();
  final ReviewService _reviewService = ReviewService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _searchResults = [];
  List<dynamic> _recentChapters = [];
  List<dynamic> _newestBooks = [];
  List<dynamic> _recentReviews = [];
  Map<String, dynamic>? _lastReadData;
  bool _isLoading = true;
  bool _isSearching = false;
  String _currentUsername = 'Гость';

  static const Color accentColor = Color(0xFFD46A4F);

  bool get _isGuest => widget.token.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUsername = prefs.getString('username') ?? 'Гость';

      final futures = await Future.wait([
        _bookService.getRecentChapters(widget.token, limit: 20),
        _bookService.getNewestBooks(widget.token, limit: 6),
        _reviewService.getRecentReviews(widget.token, limit: 4),
      ]);

      _recentChapters = futures[0] as List<dynamic>;
      _newestBooks = futures[1] as List<dynamic>;
      _recentReviews = futures[2] as List<dynamic>;

      // Continue reading (only for authenticated)
      if (!_isGuest) {
        try {
          final progressList = await _progressService.getRecentProgress(limit: 5);
          if (progressList.isNotEmpty) {
            final p = progressList.first;
            final bookId = p['bookId'] as int;
            // Launch both requests in parallel
            final bookFuture = _bookService.getBookById(widget.token, bookId);
            final chaptersFuture = _bookService.getBookChapters(widget.token, bookId);
            final book = await bookFuture;
            final chapters = await chaptersFuture;
            _lastReadData = {
              'book': book,
              'chapterOrder': p['chapterOrder'],
              'totalChapters': chapters.length,
              'percent': chapters.isNotEmpty
                  ? ((p['chapterOrder'] / chapters.length) * 100).toInt()
                  : 0,
            };
          }
        } catch (_) {}
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _bookService.searchBooks(widget.token, query);
      setState(() { _searchResults = results; _isSearching = false; });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: accentColor,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: accentColor))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text('Главная',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: theme.textPrimaryColor)),
                      const SizedBox(height: 16),
                      _buildSearchBar(theme),
                      const SizedBox(height: 16),
                      if (_isSearching || _searchResults.isNotEmpty) ...[
                        _buildSectionHeader(theme, 'Результаты поиска'),
                        const SizedBox(height: 12),
                        _buildSearchResults(theme),
                      ] else ...[
                        // 1. Последние главы
                        if (_recentChapters.isNotEmpty) ...[
                          _buildSectionHeader(theme, 'Последние главы'),
                          const SizedBox(height: 12),
                          _buildRecentChapters(theme),
                          const SizedBox(height: 24),
                        ],

                        // 2. Продолжить читать (только для авторизованных)
                        if (!_isGuest && _lastReadData != null) ...[
                          _buildSectionHeader(theme, 'Продолжить чтение'),
                          const SizedBox(height: 12),
                          _buildContinueReadingCard(theme, _lastReadData!),
                          const SizedBox(height: 24),
                        ],

                        // 3. Новинки (3 карточки)
                        if (_newestBooks.isNotEmpty) ...[
                          _buildSectionHeader(theme, 'Новинки',
                              onAllTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => _AllNovelsScreen(
                                      token: widget.token, books: _newestBooks)))),
                          const SizedBox(height: 12),
                          _buildNewBooksGrid(theme, _newestBooks.take(3).toList()),
                          const SizedBox(height: 24),
                        ],

                        // 4. Последние отзывы
                        if (_recentReviews.isNotEmpty) ...[
                          _buildSectionHeader(theme, 'Последние отзывы',
                              onAllTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => AllReviewsScreen(token: widget.token)))),
                          const SizedBox(height: 12),
                          _buildRecentReviews(theme),
                        ],
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeProvider theme) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Поиск новелл...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.4), fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeProvider theme, String title, {VoidCallback? onAllTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
        if (onAllTap != null)
          GestureDetector(
            onTap: onAllTap,
            child: Row(
              children: [
                Text('Все →', style: const TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Последние главы ───────────────────────────────────────────────────────
  Widget _buildRecentChapters(ThemeProvider theme) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentChapters.length,
        itemBuilder: (context, index) => _buildChapterCard(theme, _recentChapters[index]),
      ),
    );
  }

  Widget _buildChapterCard(ThemeProvider theme, dynamic chapter) {
    final coverUrl = ApiConstants.getCoverUrl(chapter['bookCoverUrl'] ?? '');
    final bookTitle = chapter['bookTitle'] ?? '';
    final chapterOrder = chapter['chapterOrder'] ?? 0;
    final bookId = chapter['bookId'] as int?;

    return GestureDetector(
      onTap: () {
        if (bookId != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ReaderScreen(
              token: widget.token,
              bookId: bookId,
              chapterOrder: chapterOrder,
              currentUsername: _currentUsername,
            ),
          ));
        }
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 100,
                      height: double.infinity,
                      child: Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: accentColor.withOpacity(0.1),
                          child: const Center(child: Icon(Icons.book_rounded, color: accentColor)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Глава $chapterOrder',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bookTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: theme.textPrimaryColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Продолжить чтение ─────────────────────────────────────────────────────
  Widget _buildContinueReadingCard(ThemeProvider theme, Map<String, dynamic> data) {
    final book = data['book'];
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => NovellDetailScreen(token: widget.token, bookId: book['id']),
      )),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(coverUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder()),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book['title'] ?? '', maxLines: 2,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
                const SizedBox(height: 4),
                Text(book['author'] ?? '', style: TextStyle(fontSize: 12, color: theme.textSecondaryColor)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Глава ${data['chapterOrder']} из ${data['totalChapters']}',
                        style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
                    Text('${data['percent']}%',
                        style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (data['percent'] as int) / 100.0,
                  backgroundColor: accentColor.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation(accentColor),
                  minHeight: 2,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      token: widget.token,
                      bookId: book['id'],
                      chapterOrder: data['chapterOrder'],
                      currentUsername: _currentUsername,
                    ),
                  )),
                  child: const Row(
                    children: [
                      Text('Продолжить чтение',
                          style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: accentColor, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Новинки ───────────────────────────────────────────────────────────────
  Widget _buildNewBooksGrid(ThemeProvider theme, List<dynamic> books) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) => _buildBookItemGrid(theme, books[index]),
    );
  }

  Widget _buildBookItemGrid(ThemeProvider theme, dynamic book) {
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => NovellDetailScreen(token: widget.token, bookId: book['id']),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(coverUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder()),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(book['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
          Text(book['author'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: theme.textSecondaryColor)),
        ],
      ),
    );
  }

  // ─── Последние отзывы ──────────────────────────────────────────────────────
  Widget _buildRecentReviews(ThemeProvider theme) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recentReviews.length,
        itemBuilder: (context, index) => _buildReviewCard(theme, _recentReviews[index]),
      ),
    );
  }

  Widget _buildReviewCard(ThemeProvider theme, dynamic review) {
    final user = review['user'] as Map<String, dynamic>? ?? {};
    final date = DateTime.tryParse(review['createdAt'] ?? '');
    final timeAgo = _formatTime(date);
    final title = review['title'] as String?;
    final content = review['content'] as String? ?? '';
    final likeCount = review['likeCount'] as int? ?? 0;
    final viewCount = review['viewCount'] as int? ?? 0;
    final nickname = user['nickname'] as String? ?? '?';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ReviewDetailScreen(review: review, token: widget.token),
      )),
      child: Container(
        width: 260,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: accentColor.withOpacity(0.1),
                  child: Text(nickname[0].toUpperCase(),
                      style: const TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nickname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
                      Row(
                        children: [
                          Text(review['type'] == 'REVIEW' ? 'Отзыв' : 'Рецензия',
                              style: const TextStyle(color: accentColor, fontSize: 9)),
                          const SizedBox(width: 4),
                          Text(timeAgo, style: TextStyle(fontSize: 9, color: theme.textSecondaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (title?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text(title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
            ],
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: theme.textSecondaryColor, height: 1.35),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                const SizedBox(width: 3),
                Text('${review['rating']}/10',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ReviewDetailScreen(review: review, token: widget.token),
                  )),
                  child: const Text('Читать →',
                      style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Icon(Icons.visibility_outlined, size: 12, color: theme.textSecondaryColor),
                const SizedBox(width: 2),
                Text('$viewCount', style: TextStyle(fontSize: 10, color: theme.textSecondaryColor)),
                const SizedBox(width: 6),
                Icon(Icons.thumb_up_outlined, size: 12, color: theme.textSecondaryColor),
                const SizedBox(width: 2),
                Text('$likeCount', style: TextStyle(fontSize: 10, color: theme.textSecondaryColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search results ────────────────────────────────────────────────────────
  Widget _buildSearchResults(ThemeProvider theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) => _buildBookItemGrid(theme, _searchResults[index]),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: accentColor.withOpacity(0.05),
      child: Center(child: Icon(Icons.book_rounded, color: accentColor.withOpacity(0.3), size: 24)),
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes}м';
    if (diff.inDays < 1) return '${diff.inHours}ч';
    if (diff.inDays < 7) return '${diff.inDays}д';
    return DateFormat('dd.MM').format(date);
  }
}

// ─── All Novels Screen ─────────────────────────────────────────────────────
class _AllNovelsScreen extends StatelessWidget {
  final String token;
  final List<dynamic> books;
  static const Color accentColor = Color(0xFFD46A4F);

  const _AllNovelsScreen({required this.token, required this.books});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: theme.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Новинки',
            style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold)),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => NovellDetailScreen(token: token, bookId: book['id']),
            )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(coverUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: accentColor.withOpacity(0.1),
                          child: const Center(child: Icon(Icons.book_rounded, color: accentColor)),
                        )),
                  ),
                ),
                const SizedBox(height: 6),
                Text(book['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
                Text(book['author'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: theme.textSecondaryColor)),
              ],
            ),
          );
        },
      ),
    );
  }
}
