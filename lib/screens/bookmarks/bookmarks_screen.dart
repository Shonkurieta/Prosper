import 'package:flutter/material.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:prosper/screens/novell/novell_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class BookmarksScreen extends StatefulWidget {
  final String token;

  const BookmarksScreen({super.key, required this.token});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> with SingleTickerProviderStateMixin {
  final BookmarkService _bookmarkService = BookmarkService();
  late TabController _tabController;
  
  Map<String, List<dynamic>> _bookmarksByStatus = {
    BookmarkService.READING: [],
    BookmarkService.COMPLETED: [],
    BookmarkService.FAVORITE: [],
    BookmarkService.DROPPED: [],
    BookmarkService.PLANNED: [],
  };
  
  bool _isLoading = true;
  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadBookmarks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final allBookmarks = await _bookmarkService.getBookmarks(widget.token);
      Map<String, List<dynamic>> grouped = {
        BookmarkService.READING: [],
        BookmarkService.COMPLETED: [],
        BookmarkService.FAVORITE: [],
        BookmarkService.DROPPED: [],
        BookmarkService.PLANNED: [],
      };
      for (var b in allBookmarks) {
        grouped[b['status'] ?? BookmarkService.READING]?.add(b);
      }
      if (mounted) {
        setState(() {
          _bookmarksByStatus = grouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Закладки',
                style: TextStyle(
                  color: theme.textPrimaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: accentColor,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: accentColor,
              unselectedLabelColor: theme.textSecondaryColor.withOpacity(0.5),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Читаю'),
                Tab(text: 'Прочитано'),
                Tab(text: 'Любимое'),
                Tab(text: 'Брошено'),
                Tab(text: 'В планах'),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: accentColor))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBookmarkGrid(theme, BookmarkService.READING),
                        _buildBookmarkGrid(theme, BookmarkService.COMPLETED),
                        _buildBookmarkGrid(theme, BookmarkService.FAVORITE),
                        _buildBookmarkGrid(theme, BookmarkService.DROPPED),
                        _buildBookmarkGrid(theme, BookmarkService.PLANNED),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkGrid(ThemeProvider theme, String status) {
    final bookmarks = _bookmarksByStatus[status]!;
    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 64, color: theme.textSecondaryColor.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
              'Здесь пока пусто',
              style: TextStyle(color: theme.textSecondaryColor, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadBookmarks,
      color: accentColor,
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
          crossAxisSpacing: 12,
          mainAxisSpacing: 20,
        ),
        itemCount: bookmarks.length,
        itemBuilder: (context, index) {
          final b = bookmarks[index];
          final book = b['book'];
          return _buildBookCard(theme, book, b['currentChapter'] ?? 1);
        },
      ),
    );
  }

  Widget _buildBookCard(ThemeProvider theme, dynamic book, int currentChapter) {
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    return GestureDetector(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(builder: (_) => NovellDetailScreen(token: widget.token, bookId: book['id']))
      ).then((_) => _loadBookmarks()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    coverUrl.isNotEmpty
                        ? Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                          ),
                        ),
                        child: Text(
                          'Гл. $currentChapter',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            book['title'] ?? 'Без названия',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.textPrimaryColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            book['author'] ?? 'Автор',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: theme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: accentColor.withOpacity(0.1),
      child: const Icon(Icons.book_rounded, color: accentColor, size: 32),
    );
  }
}
