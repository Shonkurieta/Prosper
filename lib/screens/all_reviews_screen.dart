import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/api_constants.dart';
import '../providers/theme_provider.dart';
import '../screens/review_detail_screen.dart';
import '../services/review_service.dart';

class AllReviewsScreen extends StatefulWidget {
  final String token;
  const AllReviewsScreen({super.key, required this.token});

  @override
  State<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends State<AllReviewsScreen> {
  static const Color accentColor = Color(0xFFD46A4F);
  static const int _pageSize = 20;

  final ReviewService _reviewService = ReviewService();
  List<dynamic> _all = [];
  int _page = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final reviews = await _reviewService.getRecentReviews(widget.token, limit: 200);
      setState(() {
        _all = reviews;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _paged => _all.skip(_page * _pageSize).take(_pageSize).toList();
  int get _totalPages => (_all.length / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: theme.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Отзывы и рецензии',
            style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentColor))
          : _all.isEmpty
              ? Center(child: Text('Нет отзывов', style: TextStyle(color: theme.textSecondaryColor)))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _paged.length,
                        itemBuilder: (context, index) =>
                            _buildCard(_paged[index], theme),
                      ),
                    ),
                    if (_totalPages > 1) _buildPagination(theme),
                  ],
                ),
    );
  }

  Widget _buildPagination(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: accentColor),
            onPressed: _page > 0 ? () => setState(() => _page--) : null,
          ),
          Text('${_page + 1} / $_totalPages',
              style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: accentColor),
            onPressed: _page < _totalPages - 1 ? () => setState(() => _page++) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic review, ThemeProvider theme) {
    final user = review['user'] as Map<String, dynamic>? ?? {};
    final date = DateTime.tryParse(review['createdAt'] ?? '');
    final timeAgo = _formatTime(date);
    final title = review['title'] as String?;
    final content = review['content'] as String? ?? '';
    final likeCount = review['likeCount'] as int? ?? 0;
    final viewCount = review['viewCount'] as int? ?? 0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewDetailScreen(review: review, token: widget.token),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAvatar(user, theme),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['nickname'] ?? '',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: accentColor.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              review['type'] == 'REVIEW' ? 'Отзыв' : 'Рецензия',
                              style: const TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(timeAgo, style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (title?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(title!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
            ],
            const SizedBox(height: 6),
            Text(
              content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: theme.textSecondaryColor, height: 1.4),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text('${review['rating']}/10',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
                  ],
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReviewDetailScreen(review: review, token: widget.token),
                    ),
                  ),
                  child: const Text('Читать →',
                      style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Icon(Icons.visibility_outlined, size: 14, color: theme.textSecondaryColor),
                const SizedBox(width: 3),
                Text('$viewCount', style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
                const SizedBox(width: 10),
                Icon(Icons.thumb_up_outlined, size: 14, color: theme.textSecondaryColor),
                const SizedBox(width: 3),
                Text('$likeCount', style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> user, ThemeProvider theme) {
    final nickname = user['nickname'] as String? ?? '?';
    final avatarUrl = user['avatarUrl'] as String?;
    return CircleAvatar(
      radius: 16,
      backgroundColor: accentColor.withOpacity(0.1),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(ApiConstants.getCoverUrl(avatarUrl),
                fit: BoxFit.cover, width: 32, height: 32,
                errorBuilder: (_, __, ___) => Text(nickname[0].toUpperCase(),
                    style: const TextStyle(color: accentColor, fontSize: 12)))
            : Text(nickname[0].toUpperCase(),
                style: const TextStyle(color: accentColor, fontSize: 12)),
      ),
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes}м назад';
    if (diff.inDays < 1) return '${diff.inHours}ч назад';
    if (diff.inDays < 7) return '${diff.inDays}д назад';
    return DateFormat('dd.MM.yyyy').format(date);
  }
}
