import 'package:flutter/material.dart';
import 'package:prosper/services/book_service.dart';
import 'package:prosper/services/bookmark_service.dart';
import 'package:prosper/screens/novell/novell_detail_screen.dart';
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
  final BookmarkService _bookmarkService = BookmarkService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allBooks = [];
  List<dynamic> _filteredBooks = [];
  Map<int, Map<String, dynamic>> _bookmarksByBookId = {};
  List<dynamic> _allGenres = [];
  Set<int> _selectedGenreIds = {};
  bool _isLoading = true;
  String _currentSort = 'rating';

  late AnimationController _headerAnimController;
  late AnimationController _contentAnimController;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _contentAnimController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
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
      final books = await _bookService.getAllBooks(widget.token, sort: _currentSort);
      final bookmarks = widget.token.isNotEmpty
          ? await _bookmarkService.getBookmarks(widget.token)
          : <dynamic>[];

      // FIX 1: Deduplicate genres by ID to prevent duplicates
      final genresMap = <dynamic, dynamic>{};
      for (var book in books) {
        final genres = book['genres'] as List<dynamic>? ?? [];
        for (var genre in genres) {
          final id = genre is Map ? genre['id'] : genre;
          genresMap[id] = genre;
        }
      }
      final genres = genresMap.values.toList();

      final bookmarksMap = <int, Map<String, dynamic>>{};
      for (var bookmark in bookmarks) {
        final bookId = bookmark['book']?['id'] as int?;
        if (bookId != null) bookmarksMap[bookId] = bookmark;
      }

      setState(() {
        _allBooks = books;
        _allGenres = genres;
        _bookmarksByBookId = bookmarksMap;
        _isLoading = false;
      });
      _applyFilters(_searchController.text);

      _headerAnimController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _contentAnimController.forward();
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _searchBooks(String query) {
    _applyFilters(query);
  }

  void _toggleGenreFilter(int genreId) {
    setState(() {
      if (_selectedGenreIds.contains(genreId)) {
        _selectedGenreIds.remove(genreId);
      } else {
        _selectedGenreIds.add(genreId);
      }
    });
    _applyFilters(_searchController.text);
  }

  void _applyFilters(String query) {
    setState(() {
      _filteredBooks = _allBooks.where((book) {
        final title = (book['title'] ?? '').toLowerCase();
        final author = (book['author'] ?? '').toLowerCase();
        final q = query.toLowerCase();
        final matchesSearch =
            query.isEmpty || title.contains(q) || author.contains(q);

        bool matchesGenres = true;
        if (_selectedGenreIds.isNotEmpty) {
          final bookGenres = (book['genres'] as List<dynamic>? ?? [])
              .map((g) => g is Map ? g['id'] : g)
              .toSet();
          matchesGenres =
              _selectedGenreIds.every((genreId) => bookGenres.contains(genreId));
        }

        return matchesSearch && matchesGenres;
      }).toList();
    });
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
          child: CustomScrollView(
            slivers: [
              _buildHeader(theme),
              _buildSearchBar(theme),
              _buildFilterSortRow(theme),
              _isLoading
                  ? const SliverFillRemaining(
                      child: Center(
                          child: CircularProgressIndicator(color: accentColor)))
                  : _buildBookGrid(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Библиотека',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: theme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_allBooks.length} новелл доступно',
              style: TextStyle(
                  fontSize: 14,
                  color: theme.textSecondaryColor,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeProvider theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _searchBooks,
            style: TextStyle(color: theme.textPrimaryColor),
            decoration: InputDecoration(
              hintText: 'Поиск новелл...',
              hintStyle: TextStyle(
                  color: theme.textSecondaryColor.withOpacity(0.5),
                  fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: accentColor, size: 22),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'chapters':   return 'По главам';
      case 'title_asc':  return 'А → Я';
      case 'title_desc': return 'Я → А';
      default:           return 'По рейтингу';
    }
  }

  Widget _buildFilterSortRow(ThemeProvider theme) {
    final bool hasFilter = _selectedGenreIds.isNotEmpty;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Кнопка Фильтр
            Expanded(
              child: GestureDetector(
                onTap: () => _showGenreFilterModal(theme),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasFilter
                        ? accentColor.withOpacity(0.08)
                        : theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasFilter
                          ? accentColor
                          : theme.textSecondaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tune_rounded,
                          color: hasFilter
                              ? accentColor
                              : theme.textSecondaryColor,
                          size: 18),
                      const SizedBox(width: 6),
                      Text(
                        hasFilter
                            ? '${_selectedGenreIds.length} жанр${_selectedGenreIds.length == 1 ? '' : 'ов'}'
                            : 'Фильтр',
                        style: TextStyle(
                          color: hasFilter
                              ? accentColor
                              : theme.textSecondaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Кнопка Сортировка (всегда акцентная)
            Expanded(
              child: GestureDetector(
                onTap: () => _showSortModal(theme),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accentColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sort_rounded,
                          color: accentColor, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _sortLabel(_currentSort),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: accentColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGenreFilterModal(ThemeProvider theme) {
    // FIX 3 & 4: Use isScrollControlled + StatefulBuilder for smooth animation
    // and immediate color update inside the sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      // smooth slide-up animation
      isScrollControlled: true,
      useRootNavigator: false,
      builder: (context) {
        // FIX 4: StatefulBuilder gives the sheet its own setState so chips
        // repaint instantly without waiting for the parent to rebuild
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // drag handle
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.textSecondaryColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Выбрать жанры',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textPrimaryColor,
                                ),
                              ),
                              if (_selectedGenreIds.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    // update both parent and sheet state
                                    setState(() => _selectedGenreIds.clear());
                                    setSheetState(() {});
                                    _applyFilters(_searchController.text);
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'Очистить',
                                    style: TextStyle(
                                      color: accentColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // FIX 2: Wrap inside a scrollable to prevent overflow
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.45,
                            ),
                            child: SingleChildScrollView(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _allGenres.map((genre) {
                                  final genreId =
                                      genre is Map ? genre['id'] : genre;
                                  final genreName = genre is Map
                                      ? genre['name']
                                      : genre.toString();
                                  final isSelected =
                                      _selectedGenreIds.contains(genreId);

                                  return GestureDetector(
                                    onTap: () {
                                      // update parent state AND sheet state together
                                      setState(() {
                                        if (_selectedGenreIds
                                            .contains(genreId)) {
                                          _selectedGenreIds.remove(genreId);
                                        } else {
                                          _selectedGenreIds.add(genreId);
                                        }
                                      });
                                      setSheetState(() {}); // repaint chips immediately
                                      _applyFilters(_searchController.text);
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      curve: Curves.easeInOut,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? accentColor
                                            : theme.cardColor,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? accentColor
                                              : theme.textSecondaryColor
                                                  .withOpacity(0.2),
                                        ),
                                      ),
                                      child: Text(
                                        genreName,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : theme.textPrimaryColor,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            _applyFilters(_searchController.text);
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'Применить',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSortModal(ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.textSecondaryColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Сортировка',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimaryColor,
                        ),
                      ),
                    ),
                  ),
                  _sortOption(theme, context, 'rating',      'По популярности',       Icons.star_rounded),
                  _sortOption(theme, context, 'chapters',    'По количеству глав',    Icons.format_list_numbered_rounded),
                  _sortOption(theme, context, 'title_asc',   'По названию А → Я',     Icons.sort_by_alpha_rounded),
                  _sortOption(theme, context, 'title_desc',  'По названию Я → А',     Icons.sort_by_alpha_rounded),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sortOption(ThemeProvider theme, BuildContext sheetContext,
      String key, String label, IconData icon) {
    final bool selected = _currentSort == key;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon,
          color: selected ? accentColor : theme.textSecondaryColor, size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? accentColor : theme.textPrimaryColor,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: accentColor)
          : null,
      onTap: () {
        Navigator.pop(sheetContext);
        if (_currentSort != key) {
          setState(() => _currentSort = key);
          _loadData();
        }
      },
    );
  }

  Widget _buildBookGrid(ThemeProvider theme) {
    if (_filteredBooks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            'Ничего не найдено',
            style: TextStyle(color: theme.textSecondaryColor),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          // FIX 2: increased ratio to give text lines room and prevent overflow
          childAspectRatio: 0.50,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildBookCard(theme, _filteredBooks[index]),
          childCount: _filteredBooks.length,
        ),
      ),
    );
  }

  Widget _buildBookCard(ThemeProvider theme, dynamic book) {
    final coverUrl = ApiConstants.getCoverUrl(book['coverUrl'] ?? '');
    final int bookId = book['id'] as int;

    // Рейтинг
    final double rating = ((book['averageRating'] ?? 0) as num).toDouble();
    final bool showRating = rating > 0;
    final Color ratingColor = rating >= 8
        ? const Color(0xFF4CAF50)   // зелёный
        : rating >= 6
            ? const Color(0xFFFFB300) // жёлтый
            : const Color(0xFFE53935); // красный

    // Закладка
    final bookmark = _bookmarksByBookId[bookId];
    final String? bookmarkStatus = bookmark?['status'] as String?;
    final bool showBookmark = bookmarkStatus != null;
    final String bookmarkLabel = showBookmark
        ? _bookmarkShortLabel(bookmarkStatus!)
        : '';

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NovellDetailScreen(
                  token: widget.token, bookId: bookId))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── обложка (не-Positioned — задаёт размер Stack) ──────
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: coverUrl.isNotEmpty
                        ? Image.network(coverUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (_, __, ___) => _buildPlaceholder())
                        : _buildPlaceholder(),
                  ),
                ),

                // ── бейдж рейтинга (выходит за левый край) ────────────
                if (showRating)
                  Positioned(
                    top: 8,
                    left: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: ratingColor,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 4,
                              offset: const Offset(1, 1))
                        ],
                      ),
                      child: Text(
                        rating % 1 == 0
                            ? rating.toInt().toString()
                            : rating.toStringAsFixed(1),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                // ── бейдж закладки (правый верхний угол) ──────────────
                if (showBookmark)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bookmarkLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book['title'] ?? 'Без названия',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.textPrimaryColor),
          ),
          Text(
            book['author'] ?? 'Автор неизвестен',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  /// Короткий русский лейбл для бейджа закладки
  String _bookmarkShortLabel(String status) {
    switch (status) {
      case 'READING':    return 'Читаю';
      case 'COMPLETED':  return 'Прочитано';
      case 'FAVORITE':   return 'Любимое';
      case 'DROPPED':    return 'Брошено';
      case 'PLANNED':    return 'В планах';
      default:           return 'Читаю';
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: accentColor.withOpacity(0.1),
      child: const Center(
          child: Icon(Icons.book_rounded, color: accentColor, size: 40)),
    );
  }
}