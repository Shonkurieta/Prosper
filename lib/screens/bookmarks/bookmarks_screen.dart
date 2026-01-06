import 'package:flutter/material.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/screens/book/book_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  final String token;

  const BookmarksScreen({super.key, required this.token});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> with SingleTickerProviderStateMixin {
  final BookmarkService _bookmarkService = BookmarkService();
  
  List<dynamic> _bookmarks = [];
  bool _isLoading = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadBookmarks();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    try {
      final bookmarks = await _bookmarkService.getBookmarks(widget.token);
      setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      });
      _animController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Ошибка загрузки закладок: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFFF6B6B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _removeBookmark(int bookId) async {
    try {
      await _bookmarkService.removeBookmark(widget.token, bookId);
      _loadBookmarks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Удалено из закладок'),
              ],
            ),
            backgroundColor: const Color(0xFF4ECDC4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _openBookDetail(int bookId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookDetailScreen(
          token: widget.token,
          bookId: bookId,
        ),
      ),
    ).then((_) => _loadBookmarks());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF4ECDC4),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Закладки',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D3436),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Text(
                          'Сохранённые книги',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF636E72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_bookmarks.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4ECDC4),
                        strokeWidth: 2.5,
                      ),
                    )
                  : _bookmarks.isEmpty
                      ? _buildEmptyState()
                      : _buildBookmarksList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.bookmark_border_rounded,
              size: 100,
              color: Color(0xFF4ECDC4),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Нет сохранённых книг',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Добавляйте книги в закладки, чтобы быстро находить их',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF636E72),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildBookmarkCard(_bookmarks[index]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookmarkCard(Map<String, dynamic> bookmark) {
    final bookId = bookmark['id'] as int;
    final title = bookmark['title'] ?? 'Без названия';
    final author = bookmark['author'] ?? 'Неизвестный автор';
    final coverUrl = bookmark['coverUrl'];
    final currentChapter = bookmark['currentChapter'] ?? 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openBookDetail(bookId),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Cover
                Hero(
                  tag: 'book-$bookId',
                  child: Container(
                    width: 80,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: coverUrl != null
                          ? Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D3436),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        author,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF636E72),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4ECDC4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bookmark_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Глава $currentChapter',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Remove button
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                    ),
                    child: const Icon(
                      Icons.bookmark_remove_rounded,
                      color: Color(0xFFFF6B6B),
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text(
                          'Удалить закладку?',
                          style: TextStyle(
                            color: Color(0xFF2D3436),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        content: Text(
                          'Вы уверены, что хотите удалить "$title" из закладок?',
                          style: const TextStyle(
                            color: Color(0xFF636E72),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Отмена',
                              style: TextStyle(
                                color: Color(0xFF636E72),
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _removeBookmark(bookId);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6B6B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF4ECDC4).withValues(alpha: 0.1),
      ),
      child: const Center(
        child: Icon(
          Icons.book_rounded,
          size: 40,
          color: Color(0xFF4ECDC4),
        ),
      ),
    );
  }
}