import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/reading_progress_service.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class HistoryScreen extends StatefulWidget {
  final String token;

  const HistoryScreen({super.key, required this.token});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final BookService _bookService = BookService();
  final ReadingProgressService _progressService = ReadingProgressService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookService.getAllBooks(widget.token);
      final recentProgress = await _progressService.getRecentProgress(limit: 50);
      
      final enrichedProgress = <Map<String, dynamic>>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      const maxAgeMs = 24 * 60 * 60 * 1000;
      
      for (var progress in recentProgress) {
        final timestamp = progress['timestamp'] as int;
        if (now - timestamp > maxAgeMs) continue;
        
        final bookId = progress['bookId'] as int;
        final book = books.firstWhere(
          (b) => b['id'] == bookId,
          orElse: () => null,
        );
        
        if (book != null) {
          enrichedProgress.add({
            'book': book,
            'chapterOrder': progress['chapterOrder'],
            'timestamp': timestamp,
          });
        }
      }
      
      setState(() {
        _history = enrichedProgress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getTimeAgo(int timestamp) {
    final now = DateTime.now();
    final readTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(readTime);
    
    if (difference.inMinutes < 1) return 'только что';
    if (difference.inMinutes < 60) return '${difference.inMinutes} мин назад';
    return '${difference.inHours} ч назад';
  }

  void _openChapter(int bookId, int chapterOrder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          token: widget.token,
          bookId: bookId,
          chapterOrder: chapterOrder,
        ),
      ),
    ).then((_) => _loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    
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
          'История за 24 часа',
          style: TextStyle(
            color: theme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : _history.isEmpty
              ? _buildEmptyState(theme)
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: theme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return _buildHistoryCard(item, theme);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: theme.textSecondaryColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'История пуста',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Здесь появятся новеллы,\nкоторые вы читали за последние 24 часа',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item, ThemeProvider theme) {
    final book = item['book'];
    final chapterOrder = item['chapterOrder'];
    final timestamp = item['timestamp'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [theme.cardShadow],
      ),
      child: InkWell(
        onTap: () => _openChapter(book['id'], chapterOrder),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: book['coverUrl'] != null && book['coverUrl'].toString().isNotEmpty
                    ? Image.network(
                        ApiConstants.getCoverUrl(book['coverUrl']),
                        width: 70,
                        height: 100,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 70,
                        height: 100,
                        color: theme.primaryColor.withOpacity(0.1),
                        child: Icon(Icons.book, color: theme.primaryColor),
                      ),
              ),
              const SizedBox(width: 16),
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
                    const SizedBox(height: 8),
                    Text(
                      'Глава $chapterOrder',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: theme.textSecondaryColor),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeAgo(timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.textSecondaryColor),
            ],
          ),
        ),
      ),
    );
  }
}
