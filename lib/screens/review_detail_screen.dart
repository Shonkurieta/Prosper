import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../constants/api_constants.dart';
import '../providers/theme_provider.dart';
import '../services/review_service.dart';

class ReviewDetailScreen extends StatefulWidget {
  final Map<String, dynamic> review;
  final String token;

  const ReviewDetailScreen({super.key, required this.review, required this.token});

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen> {
  static const Color accentColor = Color(0xFFD46A4F);
  final ReviewService _reviewService = ReviewService();

  late Map<String, dynamic> _review;
  bool _viewRecorded = false;

  @override
  void initState() {
    super.initState();
    _review = Map.from(widget.review);
    _recordView();
  }

  Future<void> _recordView() async {
    if (_viewRecorded || widget.token.isEmpty) return;
    _viewRecorded = true;
    final isNew = await _reviewService.recordView(widget.token, _review['id'] as int);
    if (isNew && mounted) {
      setState(() {
        _review['viewCount'] = (_review['viewCount'] as int? ?? 0) + 1;
      });
    }
  }

  Future<void> _toggleLike(bool isLike) async {
    if (widget.token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в аккаунт, чтобы оценивать')),
      );
      return;
    }
    final current = _review['userLikeStatus'];
    final bool? currentBool = current == true ? true : current == false ? false : null;

    setState(() {
      if (currentBool == isLike) {
        _review['userLikeStatus'] = null;
        if (isLike) {
          _review['likeCount'] = (_review['likeCount'] as int? ?? 1) - 1;
        } else {
          _review['dislikeCount'] = (_review['dislikeCount'] as int? ?? 1) - 1;
        }
      } else {
        if (currentBool != null) {
          if (currentBool) {
            _review['likeCount'] = (_review['likeCount'] as int? ?? 1) - 1;
          } else {
            _review['dislikeCount'] = (_review['dislikeCount'] as int? ?? 1) - 1;
          }
        }
        _review['userLikeStatus'] = isLike;
        if (isLike) {
          _review['likeCount'] = (_review['likeCount'] as int? ?? 0) + 1;
        } else {
          _review['dislikeCount'] = (_review['dislikeCount'] as int? ?? 0) + 1;
        }
      }
    });
    await _reviewService.toggleLike(widget.token, _review['id'] as int, isLike);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final user = _review['user'] as Map<String, dynamic>? ?? {};
    final book = _review['book'] as Map<String, dynamic>?;
    final date = DateTime.tryParse(_review['createdAt'] ?? '');
    final formattedDate = date != null ? DateFormat('dd.MM.yyyy').format(date) : '';
    final userLike = _review['userLikeStatus'];
    final userLikeBool = userLike == true ? true : userLike == false ? false : null;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: theme.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _review['type'] == 'REVIEW' ? 'Отзыв' : 'Рецензия',
          style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book info
            if (book != null) ...[
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 48,
                      height: 72,
                      child: Image.network(
                        ApiConstants.getCoverUrl(book['coverUrl'] ?? ''),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: accentColor.withOpacity(0.1),
                          child: const Icon(Icons.book_rounded, color: accentColor, size: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book['title'] ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.textPrimaryColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          book['author'] ?? '',
                          style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: theme.borderColor),
            ],

            // Author + date + type
            Row(
              children: [
                _buildAvatar(user, theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['nickname'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimaryColor,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: accentColor.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _review['type'] == 'REVIEW' ? 'ОТЗЫВ' : 'РЕЦЕНЗИЯ',
                              style: const TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(formattedDate, style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildSentimentIcon(_review['sentiment'] as String? ?? 'NEUTRAL'),
              ],
            ),
            const SizedBox(height: 16),

            // Rating
            Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${_review['rating']}/10',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            if ((_review['title'] as String?)?.isNotEmpty == true) ...[
              Text(
                _review['title'] as String,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimaryColor,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Content
            Text(
              _review['content'] ?? '',
              style: TextStyle(fontSize: 15, color: theme.textPrimaryColor, height: 1.6),
            ),
            const SizedBox(height: 24),

            // Stats + likes
            Row(
              children: [
                Icon(Icons.visibility_outlined, size: 16, color: theme.textSecondaryColor),
                const SizedBox(width: 4),
                Text(
                  '${_review['viewCount'] ?? 0}',
                  style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                ),
                const SizedBox(width: 20),
                _buildLikeButton(isLike: true, active: userLikeBool == true,
                    count: _review['likeCount'] as int? ?? 0, theme: theme),
                const SizedBox(width: 16),
                _buildLikeButton(isLike: false, active: userLikeBool == false,
                    count: _review['dislikeCount'] as int? ?? 0, theme: theme),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLikeButton({
    required bool isLike,
    required bool active,
    required int count,
    required ThemeProvider theme,
  }) {
    final color = active ? accentColor : theme.textSecondaryColor;
    return GestureDetector(
      onTap: () => _toggleLike(isLike),
      child: Row(
        children: [
          Icon(
            isLike
                ? (active ? Icons.thumb_up_rounded : Icons.thumb_up_outlined)
                : (active ? Icons.thumb_down_rounded : Icons.thumb_down_outlined),
            size: 18,
            color: color,
          ),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> user, ThemeProvider theme) {
    final nickname = user['nickname'] as String? ?? '?';
    final avatarUrl = user['avatarUrl'] as String?;
    return CircleAvatar(
      radius: 18,
      backgroundColor: accentColor.withOpacity(0.1),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(ApiConstants.getCoverUrl(avatarUrl),
                fit: BoxFit.cover, width: 36, height: 36,
                errorBuilder: (_, __, ___) => Text(
                  nickname[0].toUpperCase(),
                  style: const TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold),
                ))
            : Text(nickname[0].toUpperCase(),
                style: const TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSentimentIcon(String sentiment) {
    switch (sentiment) {
      case 'POSITIVE':
        return const Icon(Icons.sentiment_satisfied_alt_outlined, color: Colors.green, size: 22);
      case 'NEGATIVE':
        return const Icon(Icons.sentiment_very_dissatisfied_outlined, color: Colors.red, size: 22);
      default:
        return const Icon(Icons.sentiment_neutral_outlined, color: Colors.grey, size: 22);
    }
  }
}
