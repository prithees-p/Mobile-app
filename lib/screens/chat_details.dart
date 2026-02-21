import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:gal/gal.dart';
import '../api_service.dart';

// --- SUPPORTING WIDGET: FULL SCREEN IMAGE ---
class FullScreenImage extends StatefulWidget {
  final String imageUrl;
  const FullScreenImage({super.key, required this.imageUrl});

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  bool isDownloading = false;

  Future<void> _downloadImage() async {
    if (!await Gal.hasAccess()) await Gal.requestAccess();
    setState(() => isDownloading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final String savePath = '${tempDir.path}/${widget.imageUrl.split('/').last}';
      await Dio().download(widget.imageUrl, savePath);
      await Gal.putImage(savePath);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Image saved to gallery!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Failed: $e")));
    } finally {
      setState(() => isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: isDownloading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
            onPressed: isDownloading ? null : _downloadImage,
          )
        ],
      ),
      body: Center(child: InteractiveViewer(child: Image.network(widget.imageUrl))),
    );
  }
}

// --- SUPPORTING WIDGET: VIDEO PLAYER ---
class ChatVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const ChatVideoPlayer({super.key, required this.videoUrl});

  @override
  State<ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<ChatVideoPlayer> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool isDownloading = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    await _videoPlayerController.initialize();
    setState(() {
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: true,
      );
    });
  }

  Future<void> _downloadVideo() async {
    if (!await Gal.hasAccess()) await Gal.requestAccess();
    setState(() => isDownloading = true);
    try {
      final tempDir = await getTemporaryDirectory();
      final String savePath = '${tempDir.path}/${widget.videoUrl.split('/').last}';
      await Dio().download(widget.videoUrl, savePath);
      await Gal.putVideo(savePath);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Video saved to gallery!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Failed: $e")));
    } finally {
      setState(() => isDownloading = false);
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: isDownloading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
            onPressed: isDownloading ? null : _downloadVideo,
          )
        ],
      ),
      body: _chewieController != null ? Chewie(controller: _chewieController!) : const Center(child: CircularProgressIndicator()),
    );
  }
}

// --- MAIN CHAT SCREEN ---
class ChatDetailScreen extends StatefulWidget {
  final String toUserEmail;
  final String toUserName;

  const ChatDetailScreen({super.key, required this.toUserEmail, required this.toUserName});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List messages = [];
  String? currentUserEmail;
  String? playingUrl;
  bool isSending = false;
  bool isLoading = true;
  bool isRecording = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initChat();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) => _loadChatHistory(isPolling: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => currentUserEmail = prefs.getString('userEmail'));
    await _loadChatHistory();
  }

  Future<String?> _uploadToERPNext(File file) async {
    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: p.basename(file.path)),
        "is_private": 0,
        "folder": "Home/Attachments"
      });
      var response = await ApiService().dio.post("/api/method/upload_file", data: formData);
      return response.statusCode == 200 ? response.data["message"]["file_url"] : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadChatHistory({bool isPolling = false}) async {
    if (currentUserEmail == null) return;
    try {
      final response = await ApiService().dio.get("/api/resource/In-app Chat", queryParameters: {
        "fields": '["name", "message", "time", "from_user", "to_user", "seen", "document_type", "document"]',
        "filters": jsonEncode([["from_user", "in", [currentUserEmail, widget.toUserEmail]], ["to_user", "in", [currentUserEmail, widget.toUserEmail]]]),
        "order_by": "time asc"
      });
      final newMessages = response.data["data"] ?? [];
      _markMessagesAsRead(newMessages);

      if (newMessages.length != messages.length || _hasStatusChanged(newMessages)) {
        setState(() { messages = newMessages; isLoading = false; });
        if (!isPolling) _scrollToBottom();
      } else if (!isPolling) setState(() => isLoading = false);
    } catch (e) {
      if (!isPolling) setState(() => isLoading = false);
    }
  }

  Future<void> _sendMessage({String? customText, String docType = "Text", String? docUrl}) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty && docUrl == null) return;
    if (customText == null && docUrl == null) _messageController.clear();
    
    setState(() => isSending = true);
    try {
      await ApiService().dio.post("/api/resource/In-app Chat", data: {
        "message": text, "from_user": currentUserEmail, "to_user": widget.toUserEmail,
        "time": DateTime.now().toIso8601String(), "seen": 0, "document_type": docType, "document": docUrl,
      });
      _loadChatHistory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send")));
    } finally {
      setState(() => isSending = false);
    }
  }

  Future<void> _handleImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      String? url = await _uploadToERPNext(File(image.path));
      if (url != null) _sendMessage(docType: "Image", docUrl: url, customText: "📷 Image");
    }
  }

  Future<void> _handleVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      String? url = await _uploadToERPNext(File(video.path));
      if (url != null) _sendMessage(docType: "Video", docUrl: url, customText: "🎥 Video");
    }
  }

  Future<void> _handleVoice() async {
    if (await _audioRecorder.hasPermission()) {
      if (isRecording) {
        final path = await _audioRecorder.stop();
        setState(() => isRecording = false);
        if (path != null) {
          String? url = await _uploadToERPNext(File(path));
          if (url != null) _sendMessage(docType: "Audio", docUrl: url, customText: "🎤 Voice Message");
        }
      } else {
        final dir = await getTemporaryDirectory();
        final path = p.join(dir.path, 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => isRecording = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(backgroundColor: Colors.indigo, title: Text(widget.toUserName), foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(child: isLoading ? const Center(child: CircularProgressIndicator()) : _buildMessageList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) => _buildMessageBubble(messages[index], messages[index]['from_user'] == currentUserEmail),
    );
  }

  Widget _buildMessageBubble(Map msg, bool isMe) {
    String type = msg['document_type'] ?? "Text";
    String fullUrl = (msg['document'] != null) ? "${dotenv.env['url']}${msg['document']}" : "";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          if (type == "Image") Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: fullUrl)));
          if (type == "Video") Navigator.push(context, MaterialPageRoute(builder: (_) => ChatVideoPlayer(videoUrl: fullUrl)));
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(color: isMe ? Colors.indigo : Colors.white, borderRadius: BorderRadius.circular(15)),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (type == "Image") ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(fullUrl))
              else if (type == "Video") Stack(alignment: Alignment.center, children: [
                Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8))),
                const Icon(Icons.play_circle_fill, size: 50, color: Colors.white70),
              ])
              else if (type == "Audio") _buildAudioPlayerUI(fullUrl, isMe)
              else Text(msg['message'] ?? "", style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text(DateFormat('hh:mm a').format(DateTime.parse(msg['time']).toLocal()), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black45)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioPlayerUI(String url, bool isMe) {
    bool isPlaying = playingUrl == url;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isPlaying ? Icons.stop_circle : Icons.play_circle, 
            color: isMe ? Colors.white : Colors.indigo
          ),
          onPressed: () async {
            if (isPlaying) {
              await _audioPlayer.stop();
              setState(() => playingUrl = null);
            } else {
              await _audioPlayer.play(UrlSource(url));
              setState(() => playingUrl = url);
              _audioPlayer.onPlayerComplete.listen((_) => setState(() => playingUrl = null));
            }
          },
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Voice Message", 
              style: TextStyle(
                fontSize: 12, 
                color: isMe ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold
              )
            ),

            FutureBuilder<Duration?>(
              future: AudioPlayer().getDuration(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Text(
                    _formatDuration(snapshot.data!),
                    style: TextStyle(
                      fontSize: 10, 
                      color: isMe ? Colors.white70 : Colors.grey
                    ),
                  );
                }
                return const SizedBox(
                  width: 10, 
                  height: 10, 
                  // child: CircularProgressIndicator(strokeWidth: 1, color: Colors.grey)
                );
              },
            ),
          ],
        ),
      ],
    );
  }
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.image, color: Colors.indigo), onPressed: _handleImage),
          IconButton(icon: const Icon(Icons.videocam, color: Colors.indigo), onPressed: _handleVideo),
          Expanded(
            child: TextField(
              controller: _messageController, 
              decoration: InputDecoration(
                hintText: isRecording ? "Recording Voice..." : "Message", 
                hintStyle: TextStyle(color: isRecording ? Colors.red : Colors.grey),
                border: InputBorder.none
              )
            )
          ),
          GestureDetector(
            onLongPress: _handleVoice,
            onLongPressUp: _handleVoice,
            child: CircleAvatar(
              backgroundColor: isRecording ? Colors.red : Colors.indigo, 
              child: Icon(isRecording ? Icons.mic : (_messageController.text.isEmpty ? Icons.mic : Icons.send), color: Colors.white)
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  bool _hasStatusChanged(List newMsgs) {
    if (newMsgs.length != messages.length) return true;
    for (int i = 0; i < messages.length; i++) if (messages[i]['seen'] != newMsgs[i]['seen']) return true;
    return false;
  }

  Future<void> _markMessagesAsRead(List messageData) async {
    for (var msg in messageData) {
      if (msg['to_user'] == currentUserEmail && msg['seen'] != 1) {
        try { await ApiService().dio.put("/api/resource/In-app Chat/${msg['name']}", data: {"seen": 1}); } catch (e) {}
      }
    }
  }
}