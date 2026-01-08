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
      
      // Группируем по статусу
      Map<String, List<dynamic>> grouped = {
        BookmarkService.READING: [],
        BookmarkService.COMPLETED: [],
        BookmarkService.FAVORITE: [],
        BookmarkService.DROPPED: [],
        BookmarkService.PLANNED: [],
      };
      
      for (var bookmark in allBookmarks) {
        String status = bookmark['status'] ?? BookmarkService.READING;
        grouped[status]?.add(bookmark);
      }
      
      setState(() {
        _bookmarksByStatus = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки: $e'),
            backgroundColor: theme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _changeStatus(dynamic bookmark, String newStatus) async {
    try {
      await _bookmarkService.updateBookmarkStatus(
        widget.token,
        bookmark['id'],
        newStatus,
      );
      await _loadBookmarks();
      
      if (mounted) {
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус изменен: ${BookmarkService.getStatusDisplayName(newStatus)}'),
            backgroundColor: theme.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: theme.errorColor,
          ),
        );
      }
    }
  }

  void _showStatusSelector(dynamic bookmark) {
    final theme = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Изменить статус',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusOption(theme, bookmark, BookmarkService.READING, Icons.auto_stories, theme.primaryColor),
                _buildStatusOption(theme, bookmark, BookmarkService.COMPLETED, Icons.check_circle, const Color(0xFF00B894)),
                _buildStatusOption(theme, bookmark, BookmarkService.FAVORITE, Icons.favorite, const Color(0xFFFF6B6B)),
                _buildStatusOption(theme, bookmark, BookmarkService.DROPPED, Icons.cancel, const Color(0xFF636E72)),
                _buildStatusOption(theme, bookmark, BookmarkService.PLANNED, Icons.schedule, const Color(0xFF6C5CE7)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusOption(ThemeProvider theme, dynamic bookmark, String status, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _changeStatus(bookmark, status);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Text(
              BookmarkService.getStatusDisplayName(status),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: theme.primaryColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Мои закладки',
              style: TextStyle(
                color: theme.textPrimaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: theme.primaryColor,
              indicatorWeight: 3,
              labelColor: theme.primaryColor,
              unselectedLabelColor: theme.textSecondaryColor,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: [
                _buildTab('📖 В процессе', _bookmarksByStatus[BookmarkService.READING]!.length),
                _buildTab('✅ Прочитано', _bookmarksByStatus[BookmarkService.COMPLETED]!.length),
                _buildTab('❤️ Любимое', _bookmarksByStatus[BookmarkService.FAVORITE]!.length),
                _buildTab('🚫 Брошено', _bookmarksByStatus[BookmarkService.DROPPED]!.length),
                _buildTab('📅 В планах', _bookmarksByStatus[BookmarkService.PLANNED]!.length),
              ],
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
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
      },
    );
  }

  Widget _buildTab(String label, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBookmarkList(ThemeProvider theme, String status) {
    final bookmarks = _bookmarksByStatus[status]!;
    
    if (bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              BookmarkService.getStatusIcon(status),
              style: const TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 16),
            Text(
              'Пусто',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Здесь будут новеллы со статусом\n"${BookmarkService.getStatusDisplayName(status)}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookmarks,
      color: theme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookmarks.length,
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
          final book = bookmark['book'];
          return _buildBookmarkCard(theme, bookmark, book);
        },
      ),
    );
  }

  Widget _buildBookmarkCard(ThemeProvider theme, dynamic bookmark, dynamic book) {
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    final currentChapter = bookmark['currentChapter'] ?? 1;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: theme.getCardDecoration(),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ReaderScreen(
                token: widget.token,
                bookId: book['id'],
                chapterOrder: currentChapter,
              ),
            ),
          ).then((_) => _loadBookmarks());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: book['coverUrl'] != null
                    ? Image.network(
                        coverUrl,
                        width: 60,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                      )
                    : _buildPlaceholder(theme),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'] ?? 'Без названия',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Глава $currentChapter',
                      style: TextStyle(
                        color: theme.textSecondaryColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Status button
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.more_vert, color: theme.primaryColor),
                ),
                onPressed: () => _showStatusSelector(bookmark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Container(
      width: 60,
      height: 90,
      color: theme.primaryColor.withOpacity(0.1),
      child: Icon(Icons.book, color: theme.primaryColor),
    );
  }
}