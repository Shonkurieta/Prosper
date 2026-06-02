import 'package:flutter/material.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:prosper/screens/novell/novell_detail_screen.dart';
import 'package:prosper/screens/auth/login_screen.dart';
import 'package:prosper/screens/auth/register_screen.dart';
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
    if (widget.token.isEmpty) return _buildGuestScreen(theme);
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
          return _buildBookCard(theme, b, book, b['currentChapter'] ?? 1, status);
        },
      ),
    );
  }

  Widget _buildBookCard(ThemeProvider theme, dynamic bookmark, dynamic book, int currentChapter, String currentStatus) {
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NovellDetailScreen(token: widget.token, bookId: book['id']))
      ).then((_) => _loadBookmarks()),
      onLongPress: () => _showBookmarkActions(theme, bookmark, book, currentStatus),
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

  void _showBookmarkActions(ThemeProvider theme, dynamic bookmark, dynamic book, String currentStatus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textSecondaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                book['title'] ?? 'Книга',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                BookmarkService.getStatusDisplayName(currentStatus),
                style: TextStyle(fontSize: 13, color: theme.textSecondaryColor),
              ),
              const SizedBox(height: 16),
              _buildSheetAction(
                theme,
                icon: Icons.swap_horiz_rounded,
                label: 'Перенести в категорию',
                color: accentColor,
                onTap: () {
                  Navigator.pop(context);
                  _showCategoryPicker(theme, bookmark, book, currentStatus);
                },
              ),
              const SizedBox(height: 8),
              _buildSheetAction(
                theme,
                icon: Icons.delete_outline_rounded,
                label: 'Удалить из закладок',
                color: Colors.redAccent,
                onTap: () async {
                  Navigator.pop(context);
                  await _removeBookmark(bookmark, book, currentStatus);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryPicker(ThemeProvider theme, dynamic bookmark, dynamic book, String currentStatus) {
    final categories = [
      (BookmarkService.READING, 'Читаю', Icons.menu_book_rounded),
      (BookmarkService.COMPLETED, 'Прочитано', Icons.check_circle_outline_rounded),
      (BookmarkService.FAVORITE, 'Любимое', Icons.favorite_outline_rounded),
      (BookmarkService.DROPPED, 'Брошено', Icons.cancel_outlined),
      (BookmarkService.PLANNED, 'В планах', Icons.bookmark_outline_rounded),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textSecondaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Перенести в категорию',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
              ...categories.map((cat) {
                final status = cat.$1;
                final label = cat.$2;
                final icon = cat.$3;
                final isCurrent = status == currentStatus;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? accentColor.withOpacity(0.15)
                            : theme.textSecondaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: isCurrent ? accentColor : theme.textSecondaryColor,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        color: isCurrent ? accentColor : theme.textPrimaryColor,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.check_rounded, color: accentColor, size: 18)
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: isCurrent
                        ? () => Navigator.pop(context)
                        : () async {
                            Navigator.pop(context);
                            await _moveBookmark(bookmark, book, currentStatus, status);
                          },
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetAction(
    ThemeProvider theme, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
    );
  }

  Future<void> _removeBookmark(dynamic bookmark, dynamic book, String status) async {
    final bookId = book['id'] as int;
    // Instant UI update
    setState(() {
      _bookmarksByStatus[status]?.removeWhere((b) => b['book']['id'] == bookId);
    });
    try {
      await _bookmarkService.removeBookmark(widget.token, bookId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${book['title']}" удалено из закладок'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (_) {
      // Revert on failure
      _loadBookmarks();
    }
  }

  Future<void> _moveBookmark(dynamic bookmark, dynamic book, String oldStatus, String newStatus) async {
    final bookmarkId = bookmark['id'] as int;
    final entry = Map<String, dynamic>.from(bookmark as Map);
    entry['status'] = newStatus;
    // Instant UI update
    setState(() {
      _bookmarksByStatus[oldStatus]?.removeWhere((b) => b['id'] == bookmarkId);
      _bookmarksByStatus[newStatus]?.add(entry);
    });
    try {
      await _bookmarkService.updateBookmarkStatus(widget.token, bookmarkId, newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Перенесено в "${BookmarkService.getStatusDisplayName(newStatus)}"'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(20),
        ));
      }
    } catch (_) {
      _loadBookmarks();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: accentColor.withOpacity(0.1),
      child: const Icon(Icons.book_rounded, color: accentColor, size: 32),
    );
  }

  Widget _buildGuestScreen(ThemeProvider theme) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bookmark_outline_rounded, color: accentColor, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  'Войдите в аккаунт',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'чтобы сохранять закладки и следить за прогрессом чтения',
                  style: TextStyle(fontSize: 14, color: theme.textSecondaryColor, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Войти', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                        context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: accentColor),
                      foregroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Зарегистрироваться', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
