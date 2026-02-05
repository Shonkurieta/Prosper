import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/screens/book/book_detail_screen.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  final String token;

  const HomeScreen({super.key, required this.token});
  
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final BookService _bookService = BookService();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _allBooks = [];
  List<dynamic> _filteredBooks = [];
  bool _isLoading = true;
  bool _isSearching = false;
  
  late AnimationController _headerAnimController;
  late AnimationController _contentAnimController;

  @override
  void initState() {
    super.initState();
    
    _headerAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _contentAnimController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _loadData();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _contentAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookService.getAllBooks(widget.token);
      
      setState(() {
        _allBooks = books;
        _filteredBooks = books;
        _isLoading = false;
      });
      
      _headerAnimController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _contentAnimController.forward();
        }
      });
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

  Future<void> _searchBooks(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredBooks = _allBooks;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _bookService.searchBooks(widget.token, query);
      setState(() {
        _filteredBooks = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _filteredBooks = _allBooks.where((book) {
          final title = (book['title'] ?? '').toLowerCase();
          final author = (book['author'] ?? '').toLowerCase();
          final q = query.toLowerCase();
          return title.contains(q) || author.contains(q);
        }).toList();
        _isSearching = false;
      });
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
    );
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
            child: _isLoading
                ? _buildLoadingState(theme)
                : CustomScrollView(
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: AnimatedBuilder(
                          animation: _headerAnimController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _headerAnimController.value,
                              child: Transform.translate(
                                offset: Offset(0, -20 * (1 - _headerAnimController.value)),
                                child: child,
                              ),
                            );
                          },
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: theme.primaryGradient,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.shadowColor,
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.menu_book,
                                          size: 28,
                                          color: theme.textPrimaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Библиотека',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: theme.textPrimaryColor,
                                                height: 1.1,
                                              ),
                                            ),
                                            Text(
                                              '${_allBooks.length} новелл',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: theme.textSecondaryColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 18),
                                  // Search bar
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
                                        hintText: 'Найти новеллу...',
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
                      ),

                      // All Books Header
                      SliverToBoxAdapter(
                        child: AnimatedBuilder(
                          animation: _contentAnimController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: _contentAnimController.value,
                              child: child,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
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
                                  _searchController.text.isEmpty 
                                      ? 'Все новеллы'
                                      : 'Результаты поиска',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: theme.textPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Books Grid
                      if (_isSearching)
                        SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(color: theme.primaryColor),
                          ),
                        )
                      else if (_filteredBooks.isEmpty)
                        SliverFillRemaining(
                          child: _buildEmptyState(theme),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.52,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return TweenAnimationBuilder(
                                  duration: Duration(milliseconds: 300 + (index * 50)),
                                  tween: Tween<double>(begin: 0, end: 1),
                                  builder: (context, double value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Opacity(
                                        opacity: value,
                                        child: _buildBookCard(_filteredBooks[index], theme),
                                      ),
                                    );
                                  },
                                );
                              },
                              childCount: _filteredBooks.length,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder(
            duration: const Duration(milliseconds: 1500),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, double value, child) {
              return Transform.rotate(
                angle: value * 6.28,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.primaryColor,
                      width: 3,
                    ),
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Загрузка...',
            style: TextStyle(
              color: theme.textSecondaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 80,
              color: theme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Новеллы не найдены',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: theme.textPrimaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Попробуйте изменить запрос',
            style: TextStyle(
              fontSize: 14,
              color: theme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, ThemeProvider theme) {
    final bookId = book['id'] as int;
    
    return GestureDetector(
      onTap: () => _openBookDetail(bookId),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: theme.isDarkMode 
              ? Border.all(color: theme.borderColor, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: book['coverUrl'] != null && book['coverUrl'].toString().isNotEmpty
                    ? Image.network(
                        ApiConstants.getCoverUrl(book['coverUrl']),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: theme.primaryColor.withValues(alpha: 0.05),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / 
                                      loadingProgress.expectedTotalBytes!
                                    : null,
                                color: theme.primaryColor,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => _buildPlaceholder(theme),
                      )
                    : _buildPlaceholder(theme),
              ),
            ),

            // Book info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        book['title'] ?? 'Без названия',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimaryColor,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 11,
                            color: theme.isDarkMode 
                                ? theme.backgroundColor 
                                : Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Читать',
                            style: TextStyle(
                              fontSize: 9,
                              color: theme.isDarkMode 
                                  ? theme.backgroundColor 
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Container(
      color: theme.primaryColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(
          Icons.book_rounded,
          size: 60,
          color: theme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}