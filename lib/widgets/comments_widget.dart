import 'package:flutter/material.dart';
import 'package:prosper/services/comment_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';

class CommentsWidget extends StatefulWidget {
  final String token;
  final int bookId;
  final int? chapterId;
  final String currentUsername;

  const CommentsWidget({
    super.key,
    required this.token,
    required this.bookId,
    this.chapterId,
    required this.currentUsername,
  });

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  // ============ СЕРВИС И КОНТРОЛЛЕР ============
  final CommentService _commentService = CommentService();
  final TextEditingController _inputController = TextEditingController();

  // ============ СОСТОЯНИЕ ============
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Сортировка: 'new' или 'top'
  String _sortMode = 'new';

  // Локальное хранилище лайков (ключ: 'c_{commentId}' или 'r_{commentId}_{replyIndex}')
  final Map<String, bool> _liked = {};
  final Map<String, int> _likeCounts = {};

  // Какие ответы раскрыты
  final Map<int, bool> _expandedReplies = {};

  // Ответ на комментарий
  int? _replyingToId;
  String? _replyingToAuthor;

  static const Color accentColor = Color(0xFFD46A4F);

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // ============ ЗАГРУЗКА КОММЕНТАРИЕВ ============
  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> allComments;
      if (widget.chapterId != null) {
        allComments = await _commentService.getCommentsForChapter(
          widget.token,
          widget.chapterId!,
        );
      } else {
        allComments = await _commentService.getCommentsForBook(
          widget.token,
          widget.bookId,
        );
      }

      // Разделяем на корневые и ответы
      final roots = <Map<String, dynamic>>[];
      final replies = <int, List<Map<String, dynamic>>>{};

      for (final comment in allComments) {
        final parent = comment['parentComment'];
        if (parent == null) {
          roots.add(comment);
        } else {
          final parentId = parent['id'] as int;
          replies.putIfAbsent(parentId, () => []);
          replies[parentId]!.add(comment);
        }
      }

      setState(() {
        _comments = roots;
        // Инициализируем счётчики лайков и ответы
        for (final c in _comments) {
          final id = c['id'] as int;
          final cKey = 'c_$id';
          _likeCounts[cKey] = c['likes'] ?? 0;
          _liked[cKey] = false;

          // Добавляем ответы в комментарий
          c['replies'] = replies[id] ?? [];

          // Инициализируем лайки для ответов
          final replyList = c['replies'] as List<dynamic>;
          for (int i = 0; i < replyList.length; i++) {
            final rKey = 'r_${id}_$i';
            _likeCounts[rKey] = replyList[i]['likes'] ?? 0;
            _liked[rKey] = false;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки комментариев: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============ ОТПРАВКА КОММЕНТАРИЯ ============
  Future<void> _submitComment() async {
    if (_inputController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _commentService.addComment(
        widget.token,
        widget.bookId,
        widget.chapterId,
        _inputController.text.trim(),
        parentCommentId: _replyingToId,
      );
      _inputController.clear();
      setState(() {
        _replyingToId = null;
        _replyingToAuthor = null;
      });
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при добавлении комментария: $e')),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ============ УДАЛЕНИЕ КОММЕНТАРИЯ ============
  Future<void> _deleteComment(int commentId) async {
    try {
      await _commentService.deleteComment(widget.token, commentId);
      await _loadComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при удалении комментария: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmationDialog(int commentId, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.borderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Удалить комментарий?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Вы уверены, что хотите удалить свой комментарий? Это действие невозможно отменить.',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textSecondaryColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.borderColor, width: 1),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Нет',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: theme.textPrimaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              _deleteComment(commentId);
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'Да, удалить',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============ ЛОКАЛЬНЫЙ ЛАЙ ============
  void _toggleLike(String key) {
    setState(() {
      final isLiked = _liked[key] ?? false;
      _liked[key] = !isLiked;
      _likeCounts[key] = (_likeCounts[key] ?? 0) + (isLiked ? -1 : 1);
    });
  }

  // ============ СОРТИРОВКА ============
  List<Map<String, dynamic>> get _sortedComments {
    final list = List<Map<String, dynamic>>.from(_comments);
    if (_sortMode == 'top') {
      list.sort((a, b) {
        final aLikes = _likeCounts['c_${a['id']}'] ?? 0;
        final bLikes = _likeCounts['c_${b['id']}'] ?? 0;
        return bLikes.compareTo(aLikes);
      });
    } else {
      list.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    }
    return list;
  }

  // ============ АВАТАР ============
  Widget _buildAvatar(String name, ThemeProvider theme, {bool isReply = false}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = accentColor;
    final bgColor = theme.isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Container(
      width: isReply ? 28 : 34,
      height: isReply ? 28 : 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: isReply ? 11 : 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  // ============ КНОПКА ЛАЙКА ============
  Widget _buildLikeButton(String key, ThemeProvider theme) {
    final isLiked = _liked[key] ?? false;
    final count = _likeCounts[key] ?? 0;
    final color = isLiked ? accentColor : theme.textSecondaryColor;

    return GestureDetector(
      onTap: () => _toggleLike(key),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  // ============ КАРТОЧКА КОММЕНТАРИЯ ============
  Widget _buildComment(Map<String, dynamic> comment, ThemeProvider theme) {
    final id = comment['id'] as int;
    final cKey = 'c_$id';
    final author = comment['user']['nickname'] ?? 'Аноним';
    final content = comment['content'] ?? '';
    final createdAt = comment['createdAt'] ?? '';
    final isOwn = author == widget.currentUsername;
    final replies = (comment['replies'] as List<dynamic>?) ?? [];
    final isExpanded = _expandedReplies[id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Основной комментарий
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(author, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                author,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDate(createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwn)
                          GestureDetector(
                            onTap: () => _showDeleteConfirmationDialog(id, theme),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 12,
                                color: accentColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondaryColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildLikeButton(cKey, theme),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => setState(() {
                            _replyingToId = id;
                            _replyingToAuthor = author;
                          }),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 15, color: theme.textSecondaryColor),
                              const SizedBox(width: 4),
                              Text(
                                'Ответить',
                                style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Кнопка раскрытия ответов
        if (replies.isNotEmpty)
          GestureDetector(
            onTap: () => setState(() => _expandedReplies[id] = !isExpanded),
            child: Padding(
              padding: const EdgeInsets.only(left: 46, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right, size: 14, color: accentColor),
                  const SizedBox(width: 4),
                  Text(
                    isExpanded
                        ? 'Скрыть'
                        : '${replies.length} ответ${_getReplyForm(replies.length)}',
                    style: const TextStyle(fontSize: 12, color: accentColor),
                  ),
                ],
              ),
            ),
          ),

        // Ответы
        if (isExpanded)
          ...replies.asMap().entries.map((entry) {
            final i = entry.key;
            final reply = entry.value as Map<String, dynamic>;
            final rKey = 'r_${id}_$i';
            final replyAuthor = reply['user']['nickname'] ?? 'Аноним';
            final replyContent = reply['content'] ?? '';
            final replyCreatedAt = reply['createdAt'] ?? '';
            final isOwnReply = replyAuthor == widget.currentUsername;

            return Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatar(replyAuthor, theme, isReply: true),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          replyAuthor,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.textPrimaryColor,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(replyCreatedAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOwnReply)
                                    GestureDetector(
                                      onTap: () => _showDeleteConfirmationDialog(reply['id'] as int, theme),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: accentColor.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Icon(
                                          Icons.close,
                                          size: 12,
                                          color: accentColor.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                replyContent,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textSecondaryColor,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildLikeButton(rKey, theme),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

        Divider(color: theme.borderColor, height: 1, thickness: 1),
      ],
    );
  }

  String _getReplyForm(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return '';
    } else if (count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)) {
      return 'а';
    } else {
      return 'ов';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse('${dateString}Z').toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Только что';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} мин назад';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} ч назад';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} дн назад';
      } else {
        return '${date.day}.${date.month}.${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Container(
      color: theme.backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ============ ЗАГОЛОВОК ============
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Комментарии',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.textPrimaryColor,
                    letterSpacing: 0.3,
                  ),
                ),
                // ============ ПЕРЕКЛЮЧАТЕЛЬ СОРТИРОВКИ ============
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.borderColor, width: 1),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _sortMode = 'new'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _sortMode == 'new' ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: _sortMode == 'new'
                                ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 1)
                                : null,
                          ),
                          child: Text(
                            'Новые',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _sortMode == 'new' ? accentColor : theme.textSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _sortMode = 'top'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _sortMode == 'top' ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: _sortMode == 'top'
                                ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 1)
                                : null,
                          ),
                          child: Text(
                            'Популярные',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _sortMode == 'top' ? accentColor : theme.textSecondaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ============ СПИСОК КОММЕНТАРИЕВ ============
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(color: accentColor),
            )
          else if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Нет комментариев',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textSecondaryColor.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w300,
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    for (final comment in _sortedComments)
                      _buildComment(comment, theme),
                  ],
                ),
              ),
            ),

          // ============ ПОЛЕ ВВОДА ============
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_replyingToAuthor != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Ответ на: $_replyingToAuthor',
                            style: const TextStyle(
                              fontSize: 12,
                              color: accentColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _replyingToId = null;
                            _replyingToAuthor = null;
                          }),
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    _buildAvatar(widget.currentUsername, theme),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
                        maxLines: null,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Оставить комментарий...',
                          hintStyle: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
                          filled: true,
                          fillColor: theme.cardColor,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: theme.borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: theme.borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide(color: accentColor.withValues(alpha: 0.35), width: 1.5),
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: GestureDetector(
                              onTap: _isSubmitting ? null : _submitComment,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.send,
                                  size: 16,
                                  color: _isSubmitting ? theme.textSecondaryColor : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
