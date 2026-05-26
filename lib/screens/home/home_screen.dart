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
  bool _isSearching = false;
  
  late AnimationController _headerAnimController;
  late AnimationController _contentAnimController;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _contentAnimController = AnimationController(duration: const Duration(milliseconds: 1000), vsync: this);
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
      
      final genresSet = <dynamic>{};
      for (var book in books) {
        final genres = book['genres'] as List<dynamic>? ?? [];
        genresSet.addAll(genres);
      }
      final genres = genresSet.toList();
      
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
        final matchesSearch = query.isEmpty || title.contains(q) || author.contains(q);
        
        bool matchesGenres = true;
        if (_selectedGenreIds.isNotEmpty) {
          final bookGenres = (book['genres'] as List<dynamic>? ?? [])
              .map((g) => g is Map ? g['id'] : g)
              .toSet();
          matchesGenres = _selectedGenreIds.every((genreId) => bookGenres.contains(genreId));
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
                ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: accentColor)))
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
              style: TextStyle(fontSize: 14, color: theme.textSecondaryColor, fontWeight: FontWeight.w500),
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
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _searchBooks,
            style: TextStyle(color: theme.textPrimaryColor),
            decoration: InputDecoration(
              hintText: 'Поиск новелл...',
              hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.5), fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: accentColor, size: 22),
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _allGenres.map((genre) {
              final genreId = genre is Map ? genre['id'] : genre;
              final genreName = genre is Map ? genre['name'] : genre.toString();
              final isSelected = _selectedGenreIds.contains(genreId);
              
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(genreName),
                  selected: isSelected,
                  onSelected: (_) => _toggleGenreFilter(genreId),
                  backgroundColor: theme.cardColor,
                  selectedColor: accentColor.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? accentColor : theme.textPrimaryColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? accentColor : theme.textSecondaryColor.withOpacity(0.2),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBookGrid(ThemeProvider theme) {
    if (_filteredBooks.isEmpty) {
      return const SliverFillRemaining(child: Center(child: Text('Ничего не найдено')));
    }
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.55,
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NovellDetailScreen(token: widget.token, bookId: book['id']))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: coverUrl.isNotEmpty
                    ? Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                    : _buildPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            book['title'] ?? 'Без названия',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
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

  Widget _buildPlaceholder() {
    return Container(
      color: accentColor.withOpacity(0.1),
      child: const Center(child: Icon(Icons.book_rounded, color: accentColor, size: 40)),
    );
  }
}