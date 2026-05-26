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
      final books = await _bookService.getAllBooks(widget.token);
      final bookmarks = await _bookmarkService.getBookmarks(widget.token);

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
        _filteredBooks = books;
        _bookmarksByBookId = bookmarksMap;
        _isLoading = false;
      });

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
              if (_allGenres.isNotEmpty) _buildGenreFilter(theme),
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

  Widget _buildGenreFilter(ThemeProvider theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GestureDetector(
          onTap: () => _showGenreFilterModal(theme),
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
            child: Row(
              children: [
                const SizedBox(width: 16),
                const Icon(Icons.tune_rounded, color: accentColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedGenreIds.isEmpty
                        ? 'Выбрать жанры'
                        : '${_selectedGenreIds.length} жанр${_selectedGenreIds.length == 1 ? '' : 'ов'} выбрано',
                    style: TextStyle(
                      color: _selectedGenreIds.isEmpty
                          ? theme.textSecondaryColor.withOpacity(0.5)
                          : accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: theme.textSecondaryColor, size: 16),
                const SizedBox(width: 16),
              ],
            ),
          ),
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
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => NovellDetailScreen(
                  token: widget.token, bookId: book['id']))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
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
                        errorBuilder: (_, __, ___) => _buildPlaceholder())
                    : _buildPlaceholder(),
              ),
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
            style:
                TextStyle(fontSize: 10, color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: accentColor.withOpacity(0.1),
      child:
          const Center(child: Icon(Icons.book_rounded, color: accentColor, size: 40)),
    );
  }
}