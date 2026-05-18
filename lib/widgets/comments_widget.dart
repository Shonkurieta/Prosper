import 'package:flutter/material.dart';
import 'package:prosper/services/comment_service.dart';

const Color accentColor = Color(0xFFD46A4F);

class CommentsWidget extends StatefulWidget {
  final String token;
  final int bookId;
  final int chapterId;
  final String currentUsername;

  const CommentsWidget({
    super.key,
    required this.token,
    required this.bookId,
    required this.chapterId,
    required this.currentUsername,
  });

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();

  List<Map<String, dynamic>> _rootComments = [];
  Map<int, List<Map<String, dynamic>>> _repliesMap = {};
  bool _isLoading = false;
  bool _isSubmitting = false;
  int? _replyingToId;
  String? _replyingToAuthor;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final allComments = await _commentService.getCommentsForChapter(
        widget.token,
        widget.chapterId,
      );

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
        _rootComments = roots;
        _repliesMap = replies;
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

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _commentService.addComment(
        widget.token,
        widget.bookId,
        widget.chapterId,
        _commentController.text.trim(),
        parentCommentId: _replyingToId,
      );
      _commentController.clear();
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

  void _setReplyingTo(int commentId, String author) {
    setState(() {
      _replyingToId = commentId;
      _replyingToAuthor = author;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToAuthor = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Комментарии',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    color: Colors.black87,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 1,
                  width: 40,
                  color: accentColor,
                ),
              ],
            ),
          ),

          // Comments List
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(color: accentColor),
            )
          else if (_rootComments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Нет комментариев',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
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
                    for (final comment in _rootComments) ...[
                      _buildCommentTile(comment, isReply: false),
                      // Ответы на этот комментарий
                      if (_repliesMap.containsKey(comment['id']))
                        Padding(
                          padding: const EdgeInsets.only(left: 24),
                          child: Column(
                            children: [
                              for (final reply in _repliesMap[comment['id']]!)
                                _buildCommentTile(reply, isReply: true),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

          // Comment Input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_replyingToAuthor != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
                        InkWell(
                          onTap: _cancelReply,
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        maxLines: null,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Ваш комментарий...',
                          hintStyle: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 14,
                            fontWeight: FontWeight.w300,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _isSubmitting ? null : _submitComment,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isSubmitting
                              ? Colors.grey[200]
                              : accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: _isSubmitting ? Colors.grey[400] : accentColor,
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

  Widget _buildCommentTile(Map<String, dynamic> comment, {required bool isReply}) {
    final isOwnComment = comment['user']['nickname'] == widget.currentUsername;
    final commentId = comment['id'] as int;
    final author = comment['user']['nickname'] ?? 'Аноним';
    final content = comment['content'] ?? '';
    final createdAt = comment['createdAt'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isReply)
                Container(
                  width: 2,
                  height: 40,
                  margin: const EdgeInsets.only(right: 10),
                  color: accentColor.withValues(alpha: 0.3),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          author,
                          style: TextStyle(
                            fontSize: isReply ? 12 : 13,
                            fontWeight: FontWeight.w500,
                            color: isReply ? Colors.black54 : Colors.black87,
                          ),
                        ),
                        if (isOwnComment)
                          InkWell(
                            onTap: () => _deleteComment(commentId),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: isReply ? 12 : 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w300,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          _formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        if (!isReply) ...[
                          const SizedBox(width: 16),
                          InkWell(
                            onTap: () => _setReplyingTo(commentId, author),
                            child: const Text(
                              'Ответить',
                              style: TextStyle(
                                fontSize: 11,
                                color: accentColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: Colors.grey[100],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString + 'Z').toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Только что';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes} мин назад';
      } else if (difference.inDays < 1) {
        return '${difference.inHours} ч назад';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} дн назад';
      } else {
        return '${date.day}.${date.month}.${date.year}';
      }
    } catch (e) {
      return 'Недавно';
    }
  }
}