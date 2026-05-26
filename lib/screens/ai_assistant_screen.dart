import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class AiAssistantScreen extends StatefulWidget {
  final String token;
  const AiAssistantScreen({super.key, required this.token});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final response = await AiService.sendMessage(
        token: widget.token,
        question: text,
      );

      setState(() {
        _messages.add({
          "role": "assistant",
          "text": response["answer"],
          "sources": response["sources"]
        });
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add({
          "role": "assistant",
          "text": "Произошла ошибка при получении ответа. Попробуйте позже."
        });
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFD46A4F);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Ассистент Prosper',
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18),
        ),
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildInitialState(isDark)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg["role"] == "user";
                      return _buildMessage(msg, isUser, isDark, primaryColor);
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text("• • •", style: TextStyle(fontSize: 20, color: Colors.grey)),
            ),
          _buildInputArea(isDark, primaryColor),
        ],
      ),
    );
  }

  Widget _buildInitialState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Привет! Спроси меня о любой новелле.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Text(
            'Например:',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _exampleItem("Что случилось с Артуром в Тени меча?", isDark),
          _exampleItem("Что было в 7 главе Преподобного Гу?", isDark),
          _exampleItem("Кто такой Фан Юань из Преподобный Гу", isDark),
        ],
      ),
    );
  }

  Widget _exampleItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '- "$text"',
        textAlign: TextAlign.center,
        style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 14),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg, bool isUser, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: isUser ? Border.all(color: primaryColor) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              msg["text"],
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ),
          if (!isUser && msg["sources"] != null && (msg["sources"] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                _formatSources(msg["sources"]),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  String _formatSources(List sources) {
    final first = sources.first;
    return 'Источник: "${first["bookTitle"]}" — ${first["chapterTitle"]}';
  }

  Widget _buildInputArea(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: 'Задай вопрос...',
                hintStyle: const TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward, color: primaryColor),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}