import 'package:flutter/material.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
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
      setState(() {
        _bookmarksByStatus = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Закладки',
          style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.w900, fontSize: 24),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          labelColor: accentColor,
          unselectedLabelColor: theme.textSecondaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          tabs: [
            Tab(text: 'Читаю'),
            Tab(text: 'Прочитано'),
            Tab(text: 'Любимое'),
            Tab(text: 'Брошено'),
            Tab(text: 'В планах'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookmarkList(theme, BookmarkService.READING),
                _buildBookmarkList(theme, BookmarkService.COMPLETED),
                _buildBookmarkList(theme, BookmarkService.FAVORITE),
                _buildBookmarkList(theme, BookmarkService.DROPPED),
                _buildBookmarkList(theme, BookmarkService.PLANNED),
              ],
            ),
    );
  }

  Widget _buildBookmarkList(ThemeProvider theme, String status) {
    final bookmarks = _bookmarksByStatus[status]!;
    if (bookmarks.isEmpty) {
      return Center(
        child: Text('Здесь пока пусто', style: TextStyle(color: theme.textSecondaryColor)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: bookmarks.length,
      itemBuilder: (context, index) {
        final b = bookmarks[index];
        final book = b['book'];
        return _buildBookmarkCard(theme, book);
      },
    );
  }

  Widget _buildBookmarkCard(ThemeProvider theme, dynamic book) {
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 50,
            height: 70,
            child: coverUrl.isNotEmpty
                ? Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                : _buildPlaceholder(),
          ),
        ),
        title: Text(
          book['title'] ?? 'Без названия',
          style: TextStyle(fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
        ),
        subtitle: Text(
          book['author'] ?? 'Автор неизвестен',
          style: TextStyle(color: theme.textSecondaryColor, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: accentColor),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(token: widget.token, bookId: book['id'], chapterOrder: 1))),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(color: accentColor.withOpacity(0.1), child: const Icon(Icons.book, color: accentColor, size: 24));
  }
}
