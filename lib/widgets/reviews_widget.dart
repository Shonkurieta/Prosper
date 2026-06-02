import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import '../services/review_service.dart';
import '../constants/api_constants.dart';
import '../screens/review_detail_screen.dart';
import '../screens/auth/login_screen.dart';

class ReviewsWidget extends StatefulWidget {
  final String token;
  final int bookId;
  final String currentUsername;

  const ReviewsWidget({
    super.key,
    required this.token,
    required this.bookId,
    required this.currentUsername,
  });

  @override
  State<ReviewsWidget> createState() => _ReviewsWidgetState();
}

class _ReviewsWidgetState extends State<ReviewsWidget> {
  final ReviewService _reviewService = ReviewService();
  List<dynamic> _reviews = [];
  bool _isLoading = true;
  String _selectedSentiment = 'ALL';

  static const Color accentColor = Color(0xFFD46A4F);

  bool get _isGuest => widget.token.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewService.getReviewsByBook(widget.token, widget.bookId);
      setState(() { _reviews = reviews; _isLoading = false; });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredReviews {
    if (_selectedSentiment == 'ALL') return _reviews;
    return _reviews.where((r) => r['sentiment'] == _selectedSentiment).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    if (_isLoading) return const Center(child: CircularProgressIndicator(color: accentColor));

    return Column(
      children: [
        _buildFilters(theme),
        Expanded(
          child: _filteredReviews.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredReviews.length,
                  itemBuilder: (context, index) =>
                      _buildReviewCard(_filteredReviews[index], theme),
                ),
        ),
        _buildAddButton(theme),
      ],
    );
  }

  Widget _buildFilters(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFilterIcon('ALL', Icons.all_inclusive, Colors.grey, theme),
          const SizedBox(width: 20),
          _buildFilterIcon('POSITIVE', Icons.sentiment_satisfied_alt_outlined, Colors.green, theme),
          const SizedBox(width: 20),
          _buildFilterIcon('NEUTRAL', Icons.sentiment_neutral_outlined, Colors.grey, theme),
          const SizedBox(width: 20),
          _buildFilterIcon('NEGATIVE', Icons.sentiment_very_dissatisfied_outlined, Colors.red, theme),
        ],
      ),
    );
  }

  Widget _buildFilterIcon(String sentiment, IconData icon, Color color, ThemeProvider theme) {
    final isSelected = _selectedSentiment == sentiment;
    return GestureDetector(
      onTap: () => setState(() => _selectedSentiment = sentiment),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review_outlined, size: 48, color: theme.textSecondaryColor.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Здесь пока нету отзывов, будь первым',
              style: TextStyle(color: theme.textSecondaryColor, fontWeight: FontWeight.w300)),
        ],
      ),
    );
  }

  Widget _buildReviewCard(dynamic review, ThemeProvider theme) {
    final date = DateTime.tryParse(review['createdAt'] ?? '');
    final formattedDate = date != null ? DateFormat('dd.MM.yyyy').format(date) : '';
    final isOwner = review['user']['nickname'] == widget.currentUsername;
    final title = review['title'] as String?;
    final content = review['content'] as String? ?? '';
    final likeCount = review['likeCount'] as int? ?? 0;
    final dislikeCount = review['dislikeCount'] as int? ?? 0;
    final viewCount = review['viewCount'] as int? ?? 0;
    final userLike = review['userLikeStatus'];
    final userLikeBool = userLike == true ? true : userLike == false ? false : null;

    return Container(
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
          // Header: avatar + nickname + type + date + sentiment + rating + delete
          Row(
            children: [
              _buildAvatar(review['user'], theme),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review['user']['nickname'],
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
                        Text(formattedDate,
                            style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
                      ],
                    ),
                  ],
                ),
              ),
              _buildSentimentIcon(review['sentiment']),
              const SizedBox(width: 6),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 2),
                  Text('${review['rating']}/10',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
                ],
              ),
              if (isOwner) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showDeleteConfirmation(review['id'] as int, theme),
                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                ),
              ],
            ],
          ),

          // Title
          if (title?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(title!,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimaryColor)),
          ],

          // Preview (4 lines)
          const SizedBox(height: 6),
          Text(
            content,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: theme.textSecondaryColor, height: 1.4),
          ),

          // Footer: Read button + views + likes
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ReviewDetailScreen(review: review, token: widget.token),
                  ));
                },
                child: const Text('Читать →',
                    style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              Icon(Icons.visibility_outlined, size: 14, color: theme.textSecondaryColor),
              const SizedBox(width: 3),
              Text('$viewCount', style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
              const SizedBox(width: 12),
              _buildLikeButton(review: review, isLike: true, active: userLikeBool == true,
                  count: likeCount, theme: theme),
              const SizedBox(width: 8),
              _buildLikeButton(review: review, isLike: false, active: userLikeBool == false,
                  count: dislikeCount, theme: theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLikeButton({
    required dynamic review,
    required bool isLike,
    required bool active,
    required int count,
    required ThemeProvider theme,
  }) {
    final color = active ? accentColor : theme.textSecondaryColor;
    return GestureDetector(
      onTap: () => _toggleLike(review, isLike),
      child: Row(
        children: [
          Icon(
            isLike
                ? (active ? Icons.thumb_up_rounded : Icons.thumb_up_outlined)
                : (active ? Icons.thumb_down_rounded : Icons.thumb_down_outlined),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 3),
          Text('$count', style: TextStyle(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Future<void> _toggleLike(dynamic review, bool isLike) async {
    if (_isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Войдите в аккаунт, чтобы оценивать')),
      );
      return;
    }
    final current = review['userLikeStatus'];
    final bool? currentBool = current == true ? true : current == false ? false : null;

    setState(() {
      if (currentBool == isLike) {
        review['userLikeStatus'] = null;
        if (isLike) {
          review['likeCount'] = (review['likeCount'] as int? ?? 1) - 1;
        } else {
          review['dislikeCount'] = (review['dislikeCount'] as int? ?? 1) - 1;
        }
      } else {
        if (currentBool != null) {
          if (currentBool) review['likeCount'] = (review['likeCount'] as int? ?? 1) - 1;
          else review['dislikeCount'] = (review['dislikeCount'] as int? ?? 1) - 1;
        }
        review['userLikeStatus'] = isLike;
        if (isLike) review['likeCount'] = (review['likeCount'] as int? ?? 0) + 1;
        else review['dislikeCount'] = (review['dislikeCount'] as int? ?? 0) + 1;
      }
    });
    await _reviewService.toggleLike(widget.token, review['id'] as int, isLike);
  }

  Widget _buildAvatar(dynamic user, ThemeProvider theme) {
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
                    style: const TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)))
            : Text(nickname[0].toUpperCase(),
                style: const TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSentimentIcon(String sentiment) {
    switch (sentiment) {
      case 'POSITIVE': return const Icon(Icons.sentiment_satisfied_alt_outlined, color: Colors.green, size: 18);
      case 'NEGATIVE': return const Icon(Icons.sentiment_very_dissatisfied_outlined, color: Colors.red, size: 18);
      default: return const Icon(Icons.sentiment_neutral_outlined, color: Colors.grey, size: 18);
    }
  }

  Widget _buildAddButton(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (_isGuest) {
              _showGuestDialog(context, theme);
              return;
            }
            _showAddReviewModal();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showGuestDialog(BuildContext context, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Нужна авторизация', style: TextStyle(color: theme.textPrimaryColor)),
        content: Text('Войдите в аккаунт, чтобы оставлять отзывы и рецензии',
            style: TextStyle(color: theme.textSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondaryColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('Войти', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
    );
  }

  void _showAddReviewModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddReviewModal(
        token: widget.token,
        bookId: widget.bookId,
        onSuccess: () {
          _loadReviews();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDeleteConfirmation(int reviewId, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Удалить отзыв?', style: TextStyle(color: theme.textPrimaryColor)),
        content: Text('Вы уверены? Это действие нельзя отменить.',
            style: TextStyle(color: theme.textSecondaryColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Отмена', style: TextStyle(color: theme.textSecondaryColor))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReview(reviewId);
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReview(int reviewId) async {
    try {
      await _reviewService.deleteReview(widget.token, reviewId);
      _loadReviews();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отзыв удален'), backgroundColor: Colors.green),
      );
    } catch (e) {
      String msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $msg'), backgroundColor: Colors.redAccent),
      );
    }
  }
}

// ─── AddReviewModal ────────────────────────────────────────────────────────
class AddReviewModal extends StatefulWidget {
  final String token;
  final int bookId;
  final VoidCallback onSuccess;

  const AddReviewModal({super.key, required this.token, required this.bookId, required this.onSuccess});

  @override
  State<AddReviewModal> createState() => _AddReviewModalState();
}

class _AddReviewModalState extends State<AddReviewModal> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _type = 'REVIEW';
  int _rating = 10;
  String _sentiment = 'POSITIVE';
  bool _agreed = false;
  bool _isSubmitting = false;

  static const Color accentColor = Color(0xFFD46A4F);

  int get _minLength => _type == 'REVIEW' ? 500 : 3000;
  bool get _isContentValid => _contentController.text.length >= _minLength;
  bool get _isTitleValid => _titleController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final currentLength = _contentController.text.length;
    final remaining = _minLength - currentLength;

    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Написать отзыв',
                style: TextStyle(color: theme.textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(children: [
              _buildTypeOption('REVIEW', 'Отзыв', theme),
              const SizedBox(width: 12),
              _buildTypeOption('CRITIQUE', 'Рецензия', theme),
            ]),
            const SizedBox(height: 16),
            Text('Оценка: $_rating/10', style: TextStyle(color: theme.textPrimaryColor)),
            Slider(
              value: _rating.toDouble(),
              min: 1, max: 10, divisions: 9,
              activeColor: accentColor,
              onChanged: (v) => setState(() => _rating = v.toInt()),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSentimentOption('POSITIVE', Icons.sentiment_satisfied_alt_outlined, Colors.green),
                _buildSentimentOption('NEUTRAL', Icons.sentiment_neutral_outlined, Colors.grey),
                _buildSentimentOption('NEGATIVE', Icons.sentiment_very_dissatisfied_outlined, Colors.red),
              ],
            ),
            const SizedBox(height: 16),
            // Title field
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: theme.textPrimaryColor),
              decoration: theme.getInputDecoration(hintText: 'Название (обязательно)'),
            ),
            const SizedBox(height: 12),
            // Content field
            TextField(
              controller: _contentController,
              maxLines: 5,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: theme.textPrimaryColor),
              decoration: theme.getInputDecoration(
                hintText: _type == 'REVIEW' ? 'Минимум 500 символов' : 'Минимум 3000 символов',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!_isContentValid && currentLength > 0)
                  Expanded(child: Text('Ещё $remaining симв.',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12)))
                else const Spacer(),
                Text('$currentLength / $_minLength',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: _isContentValid ? Colors.green : currentLength > 0 ? Colors.redAccent : theme.textSecondaryColor.withOpacity(0.5))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(value: _agreed, activeColor: accentColor, onChanged: (v) => setState(() => _agreed = v ?? false)),
                Expanded(child: Text('Я согласен с правилами публикации',
                    style: TextStyle(color: theme.textSecondaryColor, fontSize: 12))),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_agreed && !_isSubmitting && _isContentValid && _isTitleValid) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Опубликовать', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption(String type, String label, ThemeProvider theme) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentColor : theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? accentColor : theme.borderColor),
          ),
          child: Center(child: Text(label,
              style: TextStyle(color: isSelected ? Colors.white : theme.textPrimaryColor, fontWeight: FontWeight.bold))),
        ),
      ),
    );
  }

  Widget _buildSentimentOption(String sentiment, IconData icon, Color color) {
    final isSelected = _sentiment == sentiment;
    return GestureDetector(
      onTap: () => setState(() => _sentiment = sentiment),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ReviewService().createReview(
        token: widget.token,
        bookId: widget.bookId,
        title: _titleController.text.trim(),
        content: _contentController.text,
        type: _type,
        rating: _rating,
        sentiment: _sentiment,
      );
      widget.onSuccess();
    } catch (e) {
      setState(() => _isSubmitting = false);
      String msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }
}
