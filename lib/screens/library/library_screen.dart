import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/reading_progress_service.dart';
import 'package:prosper/screens/book/book_detail_screen.dart';
import 'package:prosper/screens/reader/reader_screen.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

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
  final PageController _pageController = PageController();
  
  List<dynamic> _latestChapters = [];
  List<Map<String, dynamic>> _continueReading = [];
  List<dynamic> _newBooks = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookService.getAllBooks(widget.token);
      
      Map<int, Map<String, dynamic>> latestChaptersMap = {};
      
      for (var book in books) {
        try {
          final chapters = await _bookService.getBookChapters(widget.token, book['id']);
          if (chapters.isNotEmpty) {
            var lastChapter = chapters.reduce((a, b) => 
              (a['chapterOrder'] ?? 0) > (b['chapterOrder'] ?? 0) ? a : b
            );
            
            latestChaptersMap[book['id']] = {
              'book': book,
              'chapter': lastChapter,
              'chapterId': lastChapter['id'],
              'chapterOrder': lastChapter['chapterOrder'],
              'chapterTitle': lastChapter['title'],
            };
          }
        } catch (e) {
          debugPrint('Error loading chapters for book ${book['id']}: $e');
        }
      }
      
      var sortedChapters = latestChaptersMap.values.toList();
      sortedChapters.sort((a, b) => (b['chapterId'] as int).compareTo(a['chapterId'] as int));
      
      var recentBooks = List<dynamic>.from(books);
      recentBooks.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      
      // Загружаем прогресс чтения пользователя
      final continueReading = await _progressService.getRecentProgress(limit: 10);
      
      // Обогащаем данные прогресса информацией о книге
      final enrichedProgress = <Map<String, dynamic>>[];
      final now = DateTime.now().millisecondsSinceEpoch;
      const maxAgeHours = 24; // Максимальный возраст в часах
      const maxAgeMs = maxAgeHours * 60 * 60 * 1000; // Переводим в миллисекунды
      
      for (var progress in continueReading) {
        try {
          final timestamp = progress['timestamp'] as int;
          
          // Пропускаем прогресс старше 24 часов
          if (now - timestamp > maxAgeMs) {
            continue;
          }
          
          final bookId = progress['bookId'] as int;
          final book = books.firstWhere(
            (b) => b['id'] == bookId,
            orElse: () => null,
          );
          
          if (book != null) {
            // Загружаем главы для получения названия главы
            final chapters = await _bookService.getBookChapters(widget.token, bookId);
            final chapter = chapters.firstWhere(
              (ch) => ch['chapterOrder'] == progress['chapterOrder'],
              orElse: () => null,
            );
            
            enrichedProgress.add({
              'book': book,
              'chapterOrder': progress['chapterOrder'],
              'chapterTitle': chapter?['title'] ?? 'Глава ${progress['chapterOrder']}',
              'timestamp': timestamp,
            });
          }
        } catch (e) {
          debugPrint('Error enriching progress for book ${progress['bookId']}: $e');
        }
      }
      
      setState(() {
        _latestChapters = sortedChapters.take(27).toList();
        _continueReading = enrichedProgress;
        _newBooks = recentBooks.take(9).toList();
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

  Future<void> _searchBooks(String query) async {
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
    ).then((_) {
      // Обновляем данные после возврата из ридера
      _loadData();
    });
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
    );
  }

  String _getTimeAgo(int timestamp) {
    final now = DateTime.now();
    final readTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final difference = now.difference(readTime);
    
    if (difference.inMinutes < 1) {
      return 'только что';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин назад';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ч назад';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} дн назад';
    } else {
      return '${(difference.inDays / 7).floor()} нед назад';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: RefreshIndicator(
            onRefresh: _loadData,
            color: theme.primaryColor,
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: theme.backgroundColor,
                  elevation: 0,
                  expandedHeight: 140,
                  collapsedHeight: 140,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Главная',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: theme.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: theme.isDarkMode 
                                  ? Border.all(color: theme.borderColor, width: 1.5)
                                  : null,
                              boxShadow: [theme.cardShadow],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _searchBooks,
                              style: TextStyle(
                                color: theme.textPrimaryColor,
                                fontSize: 15,
                              ),
                              decoration: theme.getInputDecoration(
                                hintText: 'Быстрый поиск...',
                                prefixIcon: Icons.search_rounded,
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.close_rounded,
                                          color: theme.textSecondaryColor,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          _searchBooks('');
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                if (_isSearching || _searchResults.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final book = _searchResults[index];
                          return _buildNewBookItem(book, theme);
                        },
                        childCount: _searchResults.length,
                      ),
                    ),
                  )
                else if (_isLoading)
                  SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(color: theme.primaryColor),
                    ),
                  )
                else ...[
                  // Последние главы
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: theme.primaryGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Последние главы',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _latestChapters.length,
                            itemBuilder: (context, index) {
                              final item = _latestChapters[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index < _latestChapters.length - 1 ? 12 : 0,
                                ),
                                child: _buildChapterCard(item, theme),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  
                  // Продолжить чтение
                  if (_continueReading.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: theme.primaryGradient,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Продолжить чтение',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: theme.textPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _continueReading.length,
                              itemBuilder: (context, index) {
                                final item = _continueReading[index];
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: index < _continueReading.length - 1 ? 12 : 0,
                                  ),
                                  child: _buildContinueReadingCard(item, theme),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_continueReading.isNotEmpty)
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),

                  // Новинки
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: theme.primaryGradient,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Новинки',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: theme.textPrimaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 300,
                          child: PageView.builder(
                            controller: _pageController,
                            padEnds: false,
                            itemCount: 3,
                            itemBuilder: (context, pageIndex) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  left: pageIndex == 0 ? 20 : 6,
                                  right: pageIndex == 2 ? 20 : 6,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(3, (rowIndex) {
                                    final bookIndex = pageIndex * 3 + rowIndex;
                                    if (bookIndex >= _newBooks.length) {
                                      return const SizedBox(height: 92);
                                    }
                                    final book = _newBooks[bookIndex];
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom: rowIndex < 2 ? 12 : 0,
                                      ),
                                      child: _buildCompactNewBookCard(book, theme),
                                    );
                                  }),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChapterCard(Map<String, dynamic> item, ThemeProvider theme) {
    final book = item['book'];
    final chapterOrder = item['chapterOrder'];
    final bookId = book['id'];

    return GestureDetector(
      onTap: () => _openChapter(bookId, chapterOrder),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: theme.isDarkMode 
              ? Border.all(color: theme.borderColor, width: 1)
              : null,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: book['coverUrl'] != null && book['coverUrl'].toString().isNotEmpty
                    ? Image.network(
                        ApiConstants.getCoverUrl(book['coverUrl']),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                      )
                    : _buildPlaceholder(theme),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book['title'] ?? 'Без названия',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.textPrimaryColor,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Гл. $chapterOrder',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueReadingCard(Map<String, dynamic> item, ThemeProvider theme) {
    final book = item['book'];
    final chapterOrder = item['chapterOrder'];
    final chapterTitle = item['chapterTitle'] ?? 'Глава $chapterOrder';
    final timestamp = item['timestamp'] as int;
    final bookId = book['id'];

    return GestureDetector(
      onTap: () => _openChapter(bookId, chapterOrder),
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: theme.isDarkMode 
              ? Border.all(color: theme.borderColor, width: 1.5)
              : null,
          boxShadow: [theme.cardShadow],
        ),
        child: Row(
          children: [
            // Cover
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: book['coverUrl'] != null && book['coverUrl'].toString().isNotEmpty
                  ? Image.network(
                      ApiConstants.getCoverUrl(book['coverUrl']),
                      width: 100,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildMediumPlaceholder(theme),
                    )
                  : _buildMediumPlaceholder(theme),
            ),
            
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book['title'] ?? 'Без названия',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimaryColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        chapterTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: theme.textSecondaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getTimeAgo(timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_filled_rounded,
                          size: 16,
                          color: theme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Продолжить',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactNewBookCard(Map<String, dynamic> book, ThemeProvider theme) {
    final bookId = book['id'];
    
    return GestureDetector(
      onTap: () => _openBookDetail(bookId),
      child: Container(
        width: double.infinity,
        height: 92,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: theme.isDarkMode 
              ? Border.all(color: theme.borderColor, width: 1.5)
              : null,
          boxShadow: [theme.cardShadow],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              child: book['coverUrl'] != null && book['coverUrl'].toString().isNotEmpty
                  ? Image.network(
                      ApiConstants.getCoverUrl(book['coverUrl']),
                      width: 65,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildCompactPlaceholder(theme),
                    )
                  : _buildCompactPlaceholder(theme),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book['title'] ?? 'Без названия',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimaryColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book['author'] ?? 'Неизвестный автор',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewBookItem(Map<String, dynamic> book, ThemeProvider theme) {
    final bookId = book['id'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: theme.isDarkMode 
            ? Border.all(color: theme.borderColor, width: 1.5)
            : null,
        boxShadow: [theme.cardShadow],
      ),
      child: InkWell(
        onTap: () => _openBookDetail(bookId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: book['coverUrl'] != null && book['coverUrl'].toString().isNotEmpty
                    ? Image.network(
                        ApiConstants.getCoverUrl(book['coverUrl']),
                        width: 50,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildSmallPlaceholder(theme),
                      )
                    : _buildSmallPlaceholder(theme),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book['title'] ?? 'Без названия',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      book['author'] ?? 'Неизвестный автор',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Container(
      color: theme.primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.book,
        color: theme.primaryColor,
        size: 30,
      ),
    );
  }

  Widget _buildMediumPlaceholder(ThemeProvider theme) {
    return Container(
      width: 100,
      height: 150,
      color: theme.primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.book,
        color: theme.primaryColor,
        size: 40,
      ),
    );
  }

  Widget _buildSmallPlaceholder(ThemeProvider theme) {
    return Container(
      width: 50,
      height: 70,
      color: theme.primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.book,
        color: theme.primaryColor,
        size: 20,
      ),
    );
  }

  Widget _buildCompactPlaceholder(ThemeProvider theme) {
    return Container(
      width: 65,
      height: 92,
      color: theme.primaryColor.withOpacity(0.1),
      child: Icon(
        Icons.book,
        color: theme.primaryColor,
        size: 30,
      ),
    );
  }
}