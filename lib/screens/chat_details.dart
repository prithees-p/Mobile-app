import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String toUserEmail;
  final String toUserName;

  const ChatDetailScreen({
    super.key,
    required this.toUserEmail,
    required this.toUserName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  List messages = [];
  String? currentUserEmail;
  bool isSending = false;
  bool isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initChat();
    // Poll for new messages every 4 seconds
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _loadChatHistory(isPolling: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserEmail = prefs.getString('userEmail');
    });
    await _loadChatHistory();
  }

  // New logic to update the 'seen' checkbox in ERPNext
  Future<void> _markMessagesAsRead(List messageData) async {
    for (var msg in messageData) {
      // If the message is TO me and is NOT seen yet
      if (msg['to_user'] == currentUserEmail && msg['seen'] != 1) {
        try {
          await ApiService().dio.put(
            "/api/resource/In-app Chat/${msg['name']}",
            data: {"seen": 1},
          );
        } catch (e) {
          debugPrint("Error marking as seen: $e");
        }
      }
    }
  }

  Future<void> _loadChatHistory({bool isPolling = false}) async {
    if (currentUserEmail == null) return;

    try {
      final response = await ApiService().dio.get(
        "/api/resource/In-app Chat",
        queryParameters: {
          // Added 'seen' to the fields list
          "fields": '["name", "message", "time", "from_user", "to_user", "seen"]',
          "filters": jsonEncode([
            ["from_user", "in", [currentUserEmail, widget.toUserEmail]],
            ["to_user", "in", [currentUserEmail, widget.toUserEmail]]
          ]),
          "order_by": "time asc"
        },
      );

      final newMessages = response.data["data"] ?? [];
      
      // Check if we need to update seen status
      _markMessagesAsRead(newMessages);

      if (newMessages.length != messages.length || _hasSeenStatusChanged(newMessages)) {
        setState(() {
          messages = newMessages;
          isLoading = false;
        });
        
        if (_scrollController.hasClients) {
          double offset = _scrollController.offset;
          double maxScroll = _scrollController.position.maxScrollExtent;
          if (maxScroll - offset < 200 || !isPolling) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }
        }
      } else if (!isPolling) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!isPolling) setState(() => isLoading = false);
    }
  }

  // Helper to detect if 'seen' status changed even if message count is same
  bool _hasSeenStatusChanged(List newMsgs) {
    if (newMsgs.length != messages.length) return true;
    for (int i = 0; i < messages.length; i++) {
      if (messages[i]['seen'] != newMsgs[i]['seen']) return true;
    }
    return false;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage({String? customText}) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty || isSending) return;

    if (customText == null) _messageController.clear();
    setState(() => isSending = true);

    try {
      await ApiService().dio.post(
        "/api/resource/In-app Chat",
        data: {
          "message": text,
          "from_user": currentUserEmail,
          "to_user": widget.toUserEmail,
          "time": DateTime.now().toIso8601String(),
          "seen": 0, // Default to unseen
        },
      );
      await _loadChatHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message failed to send")),
      );
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FB),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : messages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessageList(),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 2,
      backgroundColor: Colors.indigo,
      foregroundColor: Colors.white,
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white24,
            child: Text(widget.toUserName[0].toUpperCase()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.toUserName, style: const TextStyle(fontSize: 16)),
                Text(widget.toUserEmail, style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("No messages yet"),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _sendMessage(customText: "Hi! 👋"),
            icon: const Icon(Icons.waving_hand),
            label: const Text("Say Hi!"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        bool isMe = msg['from_user'] == currentUserEmail;
        bool showDateHeader = index == 0 || 
            DateTime.parse(messages[index - 1]['time']).day != DateTime.parse(msg['time']).day;

        return Column(
          children: [
            if (showDateHeader) _buildDateDivider(msg['time']),
            _buildMessageBubble(msg, isMe),
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(String time) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
      child: Text(DateFormat('MMMM dd').format(DateTime.parse(time).toLocal()),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMessageBubble(Map msg, bool isMe) {
    bool isSeen = msg['seen'] == 1;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.indigo : Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(msg['message'] ?? "", 
              style: TextStyle(color: isMe ? Colors.white : Colors.black87)
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(DateFormat('hh:mm a').format(DateTime.parse(msg['time']).toLocal()),
                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black45)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all, 
                    size: 14, 
                    color: isSeen ? Colors.lightBlueAccent : Colors.white70
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                hintText: "Type a message...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.indigo,
            child: IconButton(
              icon: isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}