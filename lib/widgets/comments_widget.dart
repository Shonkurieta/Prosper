import 'package:flutter/material.dart';
import 'package:prosper/services/comment_service.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/constants/api_constants.dart';
import 'package:prosper/screens/auth/login_screen.dart';

class CommentsWidget extends StatefulWidget {
  final String token;
  final int bookId;
  final int? chapterId;
  final String currentUsername;
  final int? scrollToCommentId;

  const CommentsWidget({
    super.key,
    required this.token,
    required this.bookId,
    this.chapterId,
    required this.currentUsername,
    this.scrollToCommentId,
  });

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  final CommentService _commentService = CommentService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String _sortMode = 'new';

  // Tracks like state per comment (key = comment id as string)
  final Map<String, bool?> _likeStatus = {}; // null = no reaction, true = like, false = dislike
  final Map<String, int> _likeCounts = {};
  final Map<String, int> _dislikeCounts = {};

  final Map<int, bool> _expandedReplies = {};

  int? _replyingToId;
  String? _replyingToAuthor;
  String? _replyToNickname;

  static const Color accentColor = Color(0xFFD46A4F);

  bool get _isGuest => widget.token.isEmpty;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void deactivate() {
    FocusManager.instance.primaryFocus?.unfocus();
    super.deactivate();
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> allComments;
      if (widget.chapterId != null) {
        allComments = await _commentService.getCommentsForChapter(widget.token, widget.chapterId!);
      } else {
        allComments = await _commentService.getCommentsForBook(widget.token, widget.bookId);
      }

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
        for (final c in _comments) {
          final id = c['id'] as int;
          _initCommentState(id, c);
          c['replies'] = replies[id] ?? [];
          for (final r in (c['replies'] as List<dynamic>)) {
            _initCommentState(r['id'] as int, r as Map<String, dynamic>);
          }
        }
      });

      if (widget.scrollToCommentId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToComment(widget.scrollToCommentId!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _initCommentState(int id, Map<String, dynamic> data) {
    final key = id.toString();
    _likeCounts[key] = data['likeCount'] as int? ?? 0;
    _dislikeCounts[key] = data['dislikeCount'] as int? ?? 0;
    final userLike = data['userLikeStatus'];
    _likeStatus[key] = userLike == true ? true : userLike == false ? false : null;
  }

  void _scrollToComment(int commentId) {
    final sorted = _sortedComments;
    int? rootId;
    int rootIndex = -1;

    for (int i = 0; i < sorted.length; i++) {
      final c = sorted[i];
      if (c['id'] == commentId) { rootId = commentId; rootIndex = i; break; }
      final replyList = c['replies'] as List? ?? [];
      for (final reply in replyList) {
        if (reply['id'] == commentId) { rootId = c['id'] as int; rootIndex = i; break; }
      }
      if (rootId != null) break;
    }

    if (rootId == null || rootIndex < 0) return;
    setState(() => _expandedReplies[rootId!] = true);

    if (!_scrollController.hasClients) return;
    const headerHeight = 130.0;
    const avgCommentHeight = 90.0;
    final offset = (headerHeight + rootIndex * avgCommentHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(offset,
        duration: const Duration(milliseconds: 600), curve: Curves.easeOut);
  }

  Future<void> _submitComment() async {
    if (_isGuest) {
      _showGuestSnackBar('Войдите в аккаунт, чтобы оставлять комментарии');
      return;
    }
    if (_inputController.text.trim().isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _commentService.addComment(
        widget.token, widget.bookId, widget.chapterId, _inputController.text.trim(),
        parentCommentId: _replyingToId, replyToNickname: _replyToNickname,
      );
      _inputController.clear();
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() { _replyingToId = null; _replyingToAuthor = null; _replyToNickname = null; });
      await _loadComments();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await _commentService.deleteComment(widget.token, commentId);
      await _loadComments();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _toggleLike(int commentId, bool isLike) async {
    if (_isGuest) {
      _showGuestSnackBar('Войдите в аккаунт, чтобы оценивать');
      return;
    }

    final key = commentId.toString();
    final current = _likeStatus[key];

    setState(() {
      if (current == isLike) {
        // remove reaction
        _likeStatus[key] = null;
        if (isLike) _likeCounts[key] = (_likeCounts[key] ?? 1) - 1;
        else _dislikeCounts[key] = (_dislikeCounts[key] ?? 1) - 1;
      } else {
        if (current != null) {
          if (current) _likeCounts[key] = (_likeCounts[key] ?? 1) - 1;
          else _dislikeCounts[key] = (_dislikeCounts[key] ?? 1) - 1;
        }
        _likeStatus[key] = isLike;
        if (isLike) _likeCounts[key] = (_likeCounts[key] ?? 0) + 1;
        else _dislikeCounts[key] = (_dislikeCounts[key] ?? 0) + 1;
      }
    });

    await _commentService.toggleLike(widget.token, commentId, isLike);
  }

  void _showGuestSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showDeleteConfirmationDialog(int commentId, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.borderColor)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(width: 4, height: 20,
                    decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 12),
                Text('Удалить комментарий?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textPrimaryColor)),
              ]),
              const SizedBox(height: 12),
              Text('Вы уверены, что хотите удалить свой комментарий?',
                  style: TextStyle(fontSize: 13, color: theme.textSecondaryColor, height: 1.5)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx),
                      child: Text('Нет', style: TextStyle(color: theme.textPrimaryColor))),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () { Navigator.pop(ctx); _deleteComment(commentId); },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor.withOpacity(0.1), foregroundColor: accentColor, elevation: 0),
                    child: const Text('Да, удалить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _sortedComments {
    final list = List<Map<String, dynamic>>.from(_comments);
    if (_sortMode == 'top') {
      list.sort((a, b) {
        final aLikes = _likeCounts[a['id'].toString()] ?? 0;
        final bLikes = _likeCounts[b['id'].toString()] ?? 0;
        return bLikes.compareTo(aLikes);
      });
    } else {
      list.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
    }
    return list;
  }

  Widget _buildAvatar(String name, String? avatarUrl, ThemeProvider theme, {bool isReply = false}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final bgColor = theme.isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);

    return Container(
      width: isReply ? 24 : 32,
      height: isReply ? 24 : 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
        border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(ApiConstants.getCoverUrl(avatarUrl), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: Text(initial,
                    style: TextStyle(fontSize: isReply ? 10 : 12, fontWeight: FontWeight.w600, color: accentColor))))
            : Center(child: Text(initial,
                style: TextStyle(fontSize: isReply ? 10 : 12, fontWeight: FontWeight.w600, color: accentColor))),
      ),
    );
  }

  Widget _buildLikeDislikeRow(int commentId, ThemeProvider theme) {
    final key = commentId.toString();
    final status = _likeStatus[key];
    final likeCount = _likeCounts[key] ?? 0;
    final dislikeCount = _dislikeCounts[key] ?? 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _toggleLike(commentId, true),
          child: Row(children: [
            Icon(
              status == true ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              size: 14,
              color: status == true ? accentColor : theme.textSecondaryColor,
            ),
            const SizedBox(width: 3),
            Text('$likeCount',
                style: TextStyle(fontSize: 11, color: status == true ? accentColor : theme.textSecondaryColor)),
          ]),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _toggleLike(commentId, false),
          child: Row(children: [
            Icon(
              status == false ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
              size: 14,
              color: status == false ? Colors.red : theme.textSecondaryColor,
            ),
            const SizedBox(width: 3),
            Text('$dislikeCount',
                style: TextStyle(fontSize: 11, color: status == false ? Colors.red : theme.textSecondaryColor)),
          ]),
        ),
      ],
    );
  }

  Widget _buildReplyItem(Map<String, dynamic> reply, int rootCommentId, ThemeProvider theme) {
    final replyId = reply['id'] as int;
    final replyAuthor = reply['user']['nickname'] ?? 'Аноним';
    final replyToNickname = reply['replyToNickname'] as String?;
    final replyContent = reply['content'] ?? '';
    final isOwnReply = replyAuthor == widget.currentUsername;

    return Padding(
      padding: const EdgeInsets.only(left: 44, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(replyAuthor, reply['user']['avatarUrl'], theme, isReply: true),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(replyAuthor,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimaryColor)),
                    if (isOwnReply)
                      GestureDetector(
                        onTap: () => _showDeleteConfirmationDialog(replyId, theme),
                        child: Icon(Icons.close, size: 12, color: theme.textSecondaryColor.withOpacity(0.4)),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(children: [
                    if (replyToNickname != null)
                      TextSpan(text: '@$replyToNickname ',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor)),
                    TextSpan(text: replyContent,
                        style: TextStyle(fontSize: 12, color: theme.textSecondaryColor, height: 1.4)),
                  ]),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildLikeDislikeRow(replyId, theme),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        if (_isGuest) {
                          _showGuestSnackBar('Войдите в аккаунт, чтобы оставлять комментарии');
                          return;
                        }
                        setState(() {
                          _replyingToId = rootCommentId;
                          _replyingToAuthor = replyAuthor;
                          _replyToNickname = replyAuthor;
                          _expandedReplies[rootCommentId] = true;
                          _focusNode.requestFocus();
                        });
                      },
                      child: Text('Ответить',
                          style: TextStyle(fontSize: 11, color: theme.textSecondaryColor, fontWeight: FontWeight.w500)),
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

  Widget _buildComment(Map<String, dynamic> comment, ThemeProvider theme) {
    final id = comment['id'] as int;
    final author = comment['user']['nickname'] ?? 'Аноним';
    final content = comment['content'] ?? '';
    final createdAt = comment['createdAt'] ?? '';
    final isOwn = author == widget.currentUsername;
    final replies = (comment['replies'] as List<dynamic>?) ?? [];
    final isExpanded = _expandedReplies[id] ?? false;
    final extraCount = replies.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(author, comment['user']['avatarUrl'], theme),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(children: [
                            Text(author,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.textPrimaryColor)),
                            const SizedBox(width: 8),
                            Text(_formatDate(createdAt),
                                style: TextStyle(fontSize: 11, color: theme.textSecondaryColor)),
                          ]),
                        ),
                        if (isOwn)
                          GestureDetector(
                            onTap: () => _showDeleteConfirmationDialog(id, theme),
                            child: Icon(Icons.close, size: 14, color: theme.textSecondaryColor.withOpacity(0.5)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(content,
                        style: TextStyle(fontSize: 14, color: theme.textPrimaryColor, height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildLikeDislikeRow(id, theme),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            if (_isGuest) {
                              _showGuestSnackBar('Войдите в аккаунт, чтобы оставлять комментарии');
                              return;
                            }
                            setState(() {
                              _replyingToId = id;
                              _replyingToAuthor = author;
                              _replyToNickname = null;
                              _focusNode.requestFocus();
                            });
                          },
                          child: Text('Ответить',
                              style: TextStyle(fontSize: 11, color: theme.textSecondaryColor, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (replies.isNotEmpty)
          _buildReplyItem(replies[0] as Map<String, dynamic>, id, theme),

        if (replies.length > 1 && !isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 44, bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _expandedReplies[id] = true),
              child: Text('Показать ещё $extraCount ${_replyWord(extraCount)}',
                  style: const TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w500)),
            ),
          ),

        if (isExpanded && replies.length > 1)
          ...replies.asMap().entries.skip(1).map((entry) =>
              _buildReplyItem(entry.value as Map<String, dynamic>, id, theme)),

        if (isExpanded && replies.length > 1)
          Padding(
            padding: const EdgeInsets.only(left: 44, bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _expandedReplies[id] = false),
              child: const Text('Скрыть',
                  style: TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.w500)),
            ),
          ),

        Divider(color: theme.borderColor, height: 1, thickness: 0.5),
      ],
    );
  }

  String _replyWord(int count) {
    if (count % 100 >= 11 && count % 100 <= 14) return 'ответов';
    switch (count % 10) {
      case 1: return 'ответ';
      case 2: case 3: case 4: return 'ответа';
      default: return 'ответов';
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse('${dateString}Z').toLocal();
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 1) return 'Только что';
      if (diff.inHours < 1) return '${diff.inMinutes}м';
      if (diff.inDays < 1) return '${diff.inHours}ч';
      return '${date.day}.${date.month}';
    } catch (_) {
      return dateString;
    }
  }

  Widget _buildSortButton(String title, String mode, ThemeProvider theme) {
    final isSelected = _sortMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _sortMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.cardColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.borderColor : theme.borderColor.withOpacity(0.3),
          ),
        ),
        child: Text(title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? theme.textPrimaryColor : theme.textSecondaryColor,
            )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final sortedComments = _sortedComments;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: theme.backgroundColor,
        resizeToAvoidBottomInset: true,
        body: ListView.builder(
          controller: _scrollController,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 2 + sortedComments.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Row(children: [
                  _buildSortButton('Новые', 'new', theme),
                  const SizedBox(width: 12),
                  _buildSortButton('Популярные', 'top', theme),
                ]),
              );
            }

            if (index == 1) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_replyingToAuthor != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Row(
                          children: [
                            Text('Ответ для $_replyingToAuthor',
                                style: const TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() {
                                _replyingToId = null; _replyingToAuthor = null; _replyToNickname = null;
                              }),
                              child: Icon(Icons.cancel, size: 14, color: theme.textSecondaryColor),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: _inputController,
                      focusNode: _focusNode,
                      style: TextStyle(color: theme.textPrimaryColor, fontSize: 14),
                      maxLines: 5, minLines: 1,
                      onTap: () {
                        if (_isGuest) {
                          _focusNode.unfocus();
                          _showGuestSnackBar('Войдите в аккаунт, чтобы оставлять комментарии');
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Написать комментарий...',
                        hintStyle: TextStyle(color: theme.textSecondaryColor.withOpacity(0.6), fontSize: 14),
                        filled: true,
                        fillColor: theme.cardColor.withOpacity(0.5),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: theme.borderColor)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: theme.borderColor)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: accentColor)),
                        suffixIcon: IconButton(
                          icon: Icon(_isSubmitting ? Icons.hourglass_empty : Icons.send, color: accentColor, size: 20),
                          onPressed: _isSubmitting ? null : _submitComment,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            if (_isLoading && index == 2) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: accentColor, strokeWidth: 2)),
              );
            }

            if (sortedComments.isEmpty && index == 2) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Нет комментариев',
                    style: TextStyle(color: theme.textSecondaryColor))),
              );
            }

            final commentIndex = index - 2;
            if (commentIndex < sortedComments.length) {
              return _buildComment(sortedComments[commentIndex], theme);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
