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
      
      final bookmarksMap = <int, Map<String, dynamic>>{};
      for (var bookmark in bookmarks) {
        final bookId = bookmark['book']?['id'] as int?;
        if (bookId != null) bookmarksMap[bookId] = bookmark;
      }
      
      setState(() {
        _allBooks = books;
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
    setState(() {
      if (query.isEmpty) {
        _filteredBooks = _allBooks;
      } else {
        _filteredBooks = _allBooks.where((book) {
          final title = (book['title'] ?? '').toLowerCase();
          final author = (book['author'] ?? '').toLowerCase();
          final q = query.toLowerCase();
          return title.contains(q) || author.contains(q);
        }).toList();
      }
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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

  Widget _buildBookGrid(ThemeProvider theme) {
    if (_filteredBooks.isEmpty) {
      return const SliverFillRemaining(child: Center(child: Text('Ничего не найдено')));
    }
    return SliverPadding(
      padding: const EdgeInsets.all(24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
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
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookDetailScreen(token: widget.token, bookId: book['id']))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: coverUrl.isNotEmpty
                    ? Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                    : _buildPlaceholder(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            book['title'] ?? 'Без названия',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimaryColor),
          ),
          Text(
            book['author'] ?? 'Автор неизвестен',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
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
