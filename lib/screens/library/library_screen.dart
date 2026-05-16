import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/reading_progress_service.dart';
import 'package:prosper/screens/novell/novell_detail_screen.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
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
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _searchResults = [];
  Map<String, dynamic>? _lastReadData;
  List<Map<String, dynamic>> _allProgressData = [];
  List<Map<String, dynamic>> _newBooksWithChapters = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _showAllNewBooks = false;
  bool _showAllContinueReading = false;
  String _currentUsername = 'Гость';

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUsername = prefs.getString('username') ?? 'Гость';

      final books = await _bookService.getAllBooks(widget.token);

      // Все записи прогресса (до 20)
      final progressList = await _progressService.getRecentProgress(limit: 20);
      Map<String, dynamic>? lastData;
      List<Map<String, dynamic>> allProgress = [];

      for (var p in progressList) {
        final book = books.firstWhere((b) => b['id'] == p['bookId'], orElse: () => null);
        if (book == null) continue;

        final chapters = await _bookService.getBookChapters(widget.token, book['id']);
        final entry = {
          'book': book,
          'chapterOrder': p['chapterOrder'],
          'totalChapters': chapters.length,
          'percent': chapters.isNotEmpty
              ? ((p['chapterOrder'] / chapters.length) * 100).toInt()
              : 0,
        };

        allProgress.add(entry);
        lastData ??= entry;
      }

      // Новинки с главами
      var sorted = List.from(books);
      sorted.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));

      List<Map<String, dynamic>> enrichedNewBooks = [];
      for (var book in sorted.take(6)) {
        try {
          final chapters = await _bookService.getBookChapters(widget.token, book['id']);
          enrichedNewBooks.add({
            'book': book,
            'lastChapter': chapters.isNotEmpty ? chapters.last['chapterOrder'] : 0,
          });
        } catch (e) {
          enrichedNewBooks.add({'book': book, 'lastChapter': 0});
        }
      }

      setState(() {
        _lastReadData = lastData;
        _allProgressData = allProgress;
        _newBooksWithChapters = enrichedNewBooks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = await _bookService.searchBooks(widget.token, query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
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
                      Text(
                        'Главная',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: theme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSearchBar(theme),
                      const SizedBox(height: 24),
                      if (_isSearching || _searchResults.isNotEmpty) ...[
                        _buildSectionHeader(theme, 'Результаты поиска', showAll: false),
                        const SizedBox(height: 16),
                        _buildSearchResults(theme),
                      ] else ...[
                        // Продолжить чтение
                        if (_lastReadData != null && !_showAllNewBooks) ...[
                          _buildSectionHeader(
                            theme,
                            _showAllContinueReading ? 'Все прочитанные' : 'Продолжить чтение',
                            onAllTap: () => setState(() => _showAllContinueReading = !_showAllContinueReading),
                            isAllActive: _showAllContinueReading,
                          ),
                          const SizedBox(height: 16),
                          _showAllContinueReading
                              ? _buildContinueReadingList(theme)
                              : _buildContinueReadingCard(theme, _lastReadData!),
                          const SizedBox(height: 28),
                        ],
                        // Новинки
                        if (!_showAllContinueReading) ...[
                          _buildSectionHeader(
                            theme,
                            _showAllNewBooks ? 'Все новинки' : 'Новинки',
                            onAllTap: () => setState(() => _showAllNewBooks = !_showAllNewBooks),
                            isAllActive: _showAllNewBooks,
                          ),
                          const SizedBox(height: 16),
                          _showAllNewBooks
                              ? _buildNewBooksList(theme)
                              : _buildNewBooksGrid(theme),
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
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
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
                hintStyle: TextStyle(
                  color: theme.textSecondaryColor.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeProvider theme,
    String title, {
    VoidCallback? onAllTap,
    bool isAllActive = false,
    bool showAll = true,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.textPrimaryColor,
          ),
        ),
        if (showAll)
          GestureDetector(
            onTap: onAllTap,
            child: Row(
              children: [
                Text(
                  isAllActive ? 'Назад' : 'Все',
                  style: const TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  isAllActive ? Icons.close : Icons.chevron_right,
                  color: accentColor,
                  size: 16,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContinueReadingCard(ThemeProvider theme, Map<String, dynamic> data) {
    final book = data['book'];
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NovellDetailScreen(token: widget.token, bookId: book['id']),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 110,
            height: 165,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(size: 30),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book['title'] ?? '',
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book['author'] ?? '',
                  style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Глава ${data['chapterOrder']} из ${data['totalChapters']}',
                      style: TextStyle(fontSize: 11, color: theme.textSecondaryColor),
                    ),
                    Text(
                      '${data['percent']}%',
                      style: TextStyle(fontSize: 11, color: theme.textSecondaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: data['percent'] / 100,
                  backgroundColor: accentColor.withValues(alpha: 0.1),
                  valueColor: const AlwaysStoppedAnimation(accentColor),
                  minHeight: 2,
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(
                        token: widget.token,
                        bookId: book['id'],
                        chapterOrder: data['chapterOrder'],
                        currentUsername: _currentUsername,
                      ),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Продолжить чтение',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
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

  Widget _buildContinueReadingList(ThemeProvider theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _allProgressData.length,
      itemBuilder: (context, index) {
        final data = _allProgressData[index];
        final book = data['book'];
        final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReaderScreen(
                token: widget.token,
                bookId: book['id'],
                chapterOrder: data['chapterOrder'],
                currentUsername: _currentUsername,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 50,
                    height: 75,
                    child: Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book['title'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Глава ${data['chapterOrder']} • ${data['percent']}%',
                        style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: accentColor, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewBooksGrid(ThemeProvider theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _newBooksWithChapters.length,
      itemBuilder: (context, index) => _buildBookItemGrid(theme, _newBooksWithChapters[index]['book']),
    );
  }

  Widget _buildNewBooksList(ThemeProvider theme) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _newBooksWithChapters.length,
      itemBuilder: (context, index) => _buildBookItemList(theme, _newBooksWithChapters[index]),
    );
  }

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

  Widget _buildBookItemGrid(ThemeProvider theme, dynamic book) {
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NovellDetailScreen(token: widget.token, bookId: book['id']),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book['title'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.textPrimaryColor,
            ),
          ),
          Text(
            book['author'] ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBookItemList(ThemeProvider theme, Map<String, dynamic> data) {
    final book = data['book'];
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NovellDetailScreen(token: widget.token, bookId: book['id']),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 50,
                height: 75,
                child: Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildPlaceholder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book['author'] ?? '',
                    style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Глава ${data['lastChapter']}',
                style: const TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder({double size = 20}) {
    return Container(
      color: accentColor.withValues(alpha: 0.05),
      child: Center(
        child: Icon(Icons.book_rounded, color: accentColor.withValues(alpha: 0.3), size: size),
      ),
    );
  }
}
