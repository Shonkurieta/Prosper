import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/theme_provider.dart';
import '../services/review_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewService.getReviewsByBook(widget.token, widget.bookId);
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    } catch (e) {
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: accentColor));
    }

    return Column(
      children: [
        _buildFilters(theme),
        Expanded(
          child: _filteredReviews.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _filteredReviews.length,
                  itemBuilder: (context, index) => _buildReviewItem(_filteredReviews[index], theme),
                ),
        ),
        _buildAddButton(theme),
      ],
    );
  }

  Widget _buildFilters(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
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
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
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
          Icon(Icons.rate_review_outlined, size: 48, color: theme.textSecondaryColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Здесь пока нету отзывов, будь первым',
            style: TextStyle(color: theme.textSecondaryColor, fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(dynamic review, ThemeProvider theme) {
    final date = DateTime.parse(review['createdAt']);
    final formattedDate = DateFormat('dd.MM.yyyy').format(date);
    final isOwner = review['user']['username'] == widget.currentUsername;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
              CircleAvatar(
                radius: 16,
                backgroundColor: accentColor.withValues(alpha: 0.1),
                child: Text(
                  review['user']['nickname'][0].toUpperCase(),
                  style: const TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['user']['nickname'],
                      style: TextStyle(color: theme.textPrimaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(color: theme.textSecondaryColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              _buildSentimentIcon(review['sentiment']),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${review['rating']}/10',
                  style: const TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _showDeleteConfirmation(review['id'], theme),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: accentColor.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              review['type'] == 'REVIEW' ? 'ОТЗЫВ' : 'РЕЦЕНЗИЯ',
              style: const TextStyle(color: accentColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            review['content'],
            style: TextStyle(color: theme.textPrimaryColor, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSentimentIcon(String sentiment) {
    switch (sentiment) {
      case 'POSITIVE':
        return const Icon(Icons.sentiment_satisfied_alt_outlined, color: Colors.green, size: 20);
      case 'NEGATIVE':
        return const Icon(Icons.sentiment_very_dissatisfied_outlined, color: Colors.red, size: 20);
      default:
        return const Icon(Icons.sentiment_neutral_outlined, color: Colors.grey, size: 20);
    }
  }

  Widget _buildAddButton(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _showAddReviewModal(),
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
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Удалить отзыв?', style: TextStyle(color: theme.textPrimaryColor)),
        content: Text('Вы уверены, что хотите удалить этот отзыв? Это действие нельзя отменить.',
            style: TextStyle(color: theme.textSecondaryColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена', style: TextStyle(color: theme.textSecondaryColor)),
          ),
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
        const SnackBar(
          content: Text('Отзыв удален'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $errorMessage'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class AddReviewModal extends StatefulWidget {
  final String token;
  final int bookId;
  final VoidCallback onSuccess;

  const AddReviewModal({
    super.key,
    required this.token,
    required this.bookId,
    required this.onSuccess,
  });

  @override
  State<AddReviewModal> createState() => _AddReviewModalState();
}

class _AddReviewModalState extends State<AddReviewModal> {
  final TextEditingController _controller = TextEditingController();
  String _type = 'REVIEW';
  int _rating = 10;
  String _sentiment = 'POSITIVE';
  bool _agreed = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

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
            Text(
              'Написать отзыв',
              style: TextStyle(color: theme.textPrimaryColor, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildTypeOption('REVIEW', 'Отзыв', theme),
                const SizedBox(width: 12),
                _buildTypeOption('CRITIQUE', 'Рецензия', theme),
              ],
            ),
            const SizedBox(height: 20),
            Text('Оценка: $_rating/10', style: TextStyle(color: theme.textPrimaryColor)),
            Slider(
              value: _rating.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: const Color(0xFFD46A4F),
              onChanged: (v) => setState(() => _rating = v.toInt()),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSentimentOption('POSITIVE', Icons.sentiment_satisfied_alt_outlined, Colors.green),
                _buildSentimentOption('NEUTRAL', Icons.sentiment_neutral_outlined, Colors.grey),
                _buildSentimentOption('NEGATIVE', Icons.sentiment_very_dissatisfied_outlined, Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 5,
              style: TextStyle(color: theme.textPrimaryColor),
              decoration: theme.getInputDecoration(
                hintText: _type == 'REVIEW' ? 'Минимум 500 символов' : 'Минимум 3000 символов',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  activeColor: const Color(0xFFD46A4F),
                  onChanged: (v) => setState(() => _agreed = v ?? false),
                ),
                Expanded(
                  child: Text(
                    'Я согласен с правилами публикации',
                    style: TextStyle(color: theme.textSecondaryColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_agreed && !_isSubmitting) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD46A4F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
            color: isSelected ? const Color(0xFFD46A4F) : theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFFD46A4F) : theme.borderColor),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: isSelected ? Colors.white : theme.textPrimaryColor, fontWeight: FontWeight.bold),
            ),
          ),
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
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
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
        content: _controller.text,
        type: _type,
        rating: _rating,
        sentiment: _sentiment,
      );
      widget.onSuccess();
    } catch (e) {
      setState(() => _isSubmitting = false);
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring(11);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}
