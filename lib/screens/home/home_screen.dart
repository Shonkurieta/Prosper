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
  
  List<dynamic> _books = [];
  List<dynamic> _filteredBooks = [];
  bool _isLoading = true;
  bool _isSearching = false;
  late AnimationController _headerAnimController;
  late AnimationController _searchAnimController;
  late Animation<double> _headerFadeAnimation;
  late Animation<double> _headerScaleAnimation;
  late Animation<double> _searchSlideAnimation;

  @override
  void initState() {
    super.initState();
    
    _headerAnimController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _headerFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _headerAnimController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _headerScaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _headerAnimController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );
    
    _searchAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _searchSlideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _searchAnimController,
        curve: Curves.easeOutCubic,
      ),
    );
    
    _loadBooks();
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _searchAnimController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookService.getAllBooks(widget.token);
      setState(() {
        _books = books;
        _filteredBooks = books;
        _isLoading = false;
      });
      _headerAnimController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _searchAnimController.forward();
      });
    } catch (e) {
      setState(() {
        _books = [];
        _filteredBooks = [];
        _isLoading = false;
      });
      if (mounted) {
        final theme = context.read<ThemeProvider>();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Ошибка загрузки книг: $e')),
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
        _filteredBooks = _books;
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
        _filteredBooks = _books.where((book) {
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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => BookDetailScreen(
          token: widget.token,
          bookId: bookId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  String _getBookWord(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'Новелла';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'новеллы';
    }
    return 'книг';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Scaffold(
          backgroundColor: theme.backgroundColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Animated Header
                AnimatedBuilder(
                  animation: _headerAnimController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _headerFadeAnimation.value,
                      child: Transform.scale(
                        scale: _headerScaleAnimation.value,
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
                                      color: theme.primaryColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: theme.primaryColor.withValues(alpha: 0.3),
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.auto_stories_rounded,
                                      size: 28,
                                      color: theme.primaryColor,
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
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_books.length} ${_getBookWord(_books.length)}',
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
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Animated Search bar
                AnimatedBuilder(
                  animation: _searchAnimController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _searchSlideAnimation.value),
                      child: Opacity(
                        opacity: _searchAnimController.value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: theme.isDarkMode 
                                  ? Border.all(color: theme.borderColor, width: 1.5)
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: theme.primaryColor.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                                theme.cardShadow,
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: _searchBooks,
                              style: TextStyle(
                                color: theme.textPrimaryColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: theme.getInputDecoration(
                                hintText: 'Найти книгу...',
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
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Books Grid
                Expanded(
                  child: _isLoading || _isSearching
                      ? Center(
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
                        )
                      : _filteredBooks.isEmpty
                          ? _buildEmptyState(theme)
                          : _buildBooksGrid(theme),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 800),
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, double value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: 0.8 + (value * 0.2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.search_off_rounded,
                      size: 60,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Ничего не найдено',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Попробуйте другой запрос',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBooksGrid(ThemeProvider theme) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
      ),
      itemCount: _filteredBooks.length,
      itemBuilder: (context, index) {
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 400 + (index * 80)),
          tween: Tween<double>(begin: 0, end: 1),
          curve: Curves.easeOutBack,
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildBookCard(_filteredBooks[index], index, theme),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookCard(Map<String, dynamic> book, int index, ThemeProvider theme) {
    final bookId = book['id'] as int;
    
    return GestureDetector(
      onTap: () => _openBookDetail(bookId),
      child: Hero(
        tag: 'book-$bookId',
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: theme.isDarkMode 
                ? Border.all(color: theme.borderColor, width: 1.5)
                : null,
            boxShadow: [theme.cardShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image with overlay gradient
              Expanded(
                flex: 6,
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(18),
                        ),
                        child: book['coverUrl'] != null && book['coverUrl'].toString().isNotEmpty
                            ? Image.network(
                                ApiConstants.getCoverUrl(book['coverUrl']),
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: theme.inputBackgroundColor,
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
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildPlaceholder(theme);
                                },
                              )
                            : _buildPlaceholder(theme),
                      ),
                    ),
                    // Bottom gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Book info
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 4),
                      Text(
                        book['author'] ?? 'Неизвестный автор',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 14,
                                  color: theme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Читать',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  Widget _buildPlaceholder(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.isDarkMode
              ? [
                  theme.cardColor,
                  theme.inputBackgroundColor,
                ]
              : [
                  const Color(0xFFF5F7FA),
                  const Color(0xFFE8ECEF),
                ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.book_outlined,
          size: 60,
          color: theme.textSecondaryColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}