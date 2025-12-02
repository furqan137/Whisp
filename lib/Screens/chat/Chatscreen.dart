import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http/http.dart' as http;
import '../../Service/chatfeature.dart';
import '../../Service/chatutils.dart';
import '../../Service/encryption.dart';
import 'chatwidgets.dart';
import 'share_message_screen.dart';

class ChatScreen extends StatefulWidget {
  final String peerUid;
  final String peerUsername;
  final String peerName; // <-- Add peerName

  const ChatScreen({
    super.key,
    required this.peerUid,
    required this.peerUsername,
    required this.peerName, // <-- Add peerName to constructor
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _messageError;

  // Audio recording
  FlutterSoundRecorder? _audioRecorder;
  FlutterSoundPlayer? _audioPlayer;
  bool _isRecording = false;
  bool _isRecorderReady = false;
  bool _isPlaying = false;
  String? _currentAudioUrl;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Messages and state
  List<Map<String, dynamic>> messages = [];
  bool _loading = true;
  bool _isUploading = false;
  Map<String, String> _downloadedFiles = {};

  // Self-destruct feature
  bool _isSelfDestructEnabled = false;
  String? _pendingMediaPath;

  // Long press actions
  Map<String, dynamic>? _selectedMessage;
  bool _showActionBar = false;

  String get chatId => ChatUtils.getChatId(FirebaseAuth.instance.currentUser?.uid ?? '', widget.peerUid);

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _messageController.addListener(_updateSelfDestructEnabled);
    SelfDestructService.startListener(chatId, isGroup: false);
  }

  Future<void> _initializeApp() async {
    _audioRecorder = FlutterSoundRecorder();
    _audioPlayer = FlutterSoundPlayer();

    await _initRecorder();
    await _audioPlayer?.openPlayer();
    await _loadMessages();
    await ChatFeatures.requestStoragePermission();
  }

  Future<void> _initRecorder() async {
    try {
      await ChatFeatures.initAudioRecorder(_audioRecorder!);
      if (mounted) {
        setState(() {
          _isRecorderReady = true;
        });
      }
    } catch (e) {
      print('❌ Error initializing recorder: $e');
    }
  }

  Future<void> _loadMessages() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatId = ChatUtils.getChatId(currentUser.uid, widget.peerUid);

    FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .listen((snapshot) {
      final key = EncryptionService.getSharedKey(currentUser.uid, widget.peerUid);

      List<Map<String, dynamic>> loadedMessages = [];
      print('Firestore snapshot docs count: ${snapshot.docs.length}');
      for (var doc in snapshot.docs) {
        final msg = doc.data() as Map<String, dynamic>;
        msg['id'] = doc.id; // Attach Firestore doc ID
        print('Firestore raw message: $msg');
        // Robustly handle both text and media messages
        if (msg.containsKey('mediaType') && msg['mediaType'] != null) {
          try {
            msg['decryptedUrl'] = EncryptionService.decryptText(msg['message'], key);
          } catch (e) {
            print('❌ Failed to decrypt media URL: $e');
            msg['decryptedUrl'] = msg['message']; // fallback to raw URL
          }
        } else {
          // Treat as plain text message
          try {
            msg['message'] = EncryptionService.decryptText(msg['message'], key);
          } catch (e) {
            print('❌ Failed to decrypt text message: $e');
            msg['message'] = msg['message']; // fallback to raw text
          }
        }
        loadedMessages.add(msg);
      }
      if (mounted) {
        setState(() {
          messages = loadedMessages;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });
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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    _messageController.clear();

    try {
      setState(() => _messageError = null);

      await ChatFeatures.sendMessage(
        text: text,
        peerUid: widget.peerUid,
        peerUsername: widget.peerUsername,
      );
    } catch (e) {
      setState(() {
        _messageError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _showSnackBar(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? (message.contains('success') ? Colors.green : Colors.red),
      ),
    );
  }

  Future<void> _pickMediaFromGallery() async {
    if (_isUploading) {
      _showSnackBar('Please wait for current upload to finish');
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => MediaPickerBottomSheet(
        onPickPhoto: _pickMediaFiles,
        onPickDocument: _pickDocumentFiles,
      ),
    );
  }

  Future<void> _pickMediaFiles() async {
    try {
      final file = await ChatFeatures.pickMediaFile();
      if (file != null) {
        if (!await ChatUtils.validateFileSize(file)) {
          _showSnackBar('File too large. Maximum size is 50MB.');
          return;
        }
        // Directly send the media message after picking
        await ChatFeatures.sendMediaMessage(
          file: file,
          fileName: file.path.split('/').last,
          peerUid: widget.peerUid,
          peerUsername: widget.peerUsername,
          setUploadingState: (uploading) => setState(() => _isUploading = uploading),
          showSnackBar: _showSnackBar,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to select or send file. Please try again.');
    }
  }

  Future<void> _pickDocumentFiles() async {
    try {
      final file = await ChatFeatures.pickDocumentFile();
      if (file != null) {
        final fileName = file.path.split('/').last;

        if (!await ChatUtils.validateFileSize(file)) {
          _showSnackBar('File too large. Maximum size is 50MB.');
          return;
        }

        await ChatFeatures.sendMediaMessage(
          file: file,
          fileName: fileName,
          peerUid: widget.peerUid,
          peerUsername: widget.peerUsername,
          setUploadingState: (uploading) => setState(() => _isUploading = uploading),
          showSnackBar: _showSnackBar,
        );
      }
    } catch (e) {
      _showSnackBar('Failed to select document. Please try again.');
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || !_isRecorderReady) return;

    try {
      await ChatFeatures.startRecording(_audioRecorder!);

      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordDuration++;
          });
        }
      });
    } catch (e) {
      _showSnackBar('Failed to start recording');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;

    try {
      final path = await ChatFeatures.stopRecording(_audioRecorder!);
      _recordTimer?.cancel();

      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });

      if (path != null) {
        await _sendVoiceMessage(File(path));
      }
    } catch (e) {
      _showSnackBar('Failed to stop recording');
    }
  }

  Future<void> _sendVoiceMessage(File audioFile) async {
    try {
      final fileName = audioFile.path.split('/').last;
      await ChatFeatures.sendMediaMessage(
        file: audioFile,
        fileName: fileName,
        peerUid: widget.peerUid,
        peerUsername: widget.peerUsername,
        setUploadingState: (uploading) => setState(() => _isUploading = uploading),
        showSnackBar: _showSnackBar,
      );
    } catch (e) {
      _showSnackBar('Failed to send voice message');
    }
  }

  Future<void> _playAudio(String url) async {
    try {
      if (_isPlaying) {
        await ChatFeatures.stopAudio(_audioPlayer!);
        setState(() { _isPlaying = false; });
        return;
      }

      await ChatFeatures.playAudio(_audioPlayer!, url, () {
        if (mounted) {
          setState(() { _isPlaying = false; });
        }
      });

      setState(() {
        _isPlaying = true;
        _currentAudioUrl = url;
      });
    } catch (e) {
      _showSnackBar('Failed to play audio');
    }
  }

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => ImageDialog(
        imageUrl: imageUrl,
        parentContext: this.context,
      ),
    );
  }

  void _showVideoDialog(String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  void _updateDownloadedFiles(String url, String path) {
    setState(() {
      _downloadedFiles[url] = path;
    });
  }

  Future<void> _deletePersonalMessage(Map<String, dynamic> msg) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final chatId = ChatUtils.getChatId(currentUser.uid, widget.peerUid);

      // Delete media from Cloudinary if applicable
      if (msg['mediaType'] != null && msg['decryptedUrl'] != null) {
        await ChatFeatures.deleteFromCloudinary(msg['decryptedUrl'], msg['mediaType']);
      }

      // Only delete if the message belongs to the current user
      if (msg['fromUid'] == currentUser.uid) {
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc(msg['id'])
            .delete();

        _showSnackBar('Message deleted successfully', color: Colors.green);
      } else {
        _showSnackBar('You can only delete your own messages');
      }
    } catch (e) {
      _showSnackBar('Failed to delete message');
    }
  }

  void _updateSelfDestructEnabled() {
    setState(() {
      _isSelfDestructEnabled = _messageController.text.trim().isNotEmpty || _pendingMediaPath != null;
    });
  }

  void _openSelfDestructDialog() {
    showDialog(
      context: context,
      builder: (context) => SelfDestructDialog(
        messagePreview: _pendingMediaPath != null ? 'Media selected' : _messageController.text.trim(),
        hasMedia: _pendingMediaPath != null,
        onSend: (duration) => _sendSelfDestructMessage(duration),
      ),
    );
  }

  Future<void> _sendSelfDestructMessage(int duration) async {
    final text = _messageController.text.trim();
    final mediaPath = _pendingMediaPath;
    _messageController.clear();
    setState(() { _pendingMediaPath = null; });
    try {
      setState(() => _messageError = null);
      final now = Timestamp.now();
      final currentUser = FirebaseAuth.instance.currentUser;
      final chatId = ChatUtils.getChatId(currentUser?.uid ?? '', widget.peerUid);
      final key = EncryptionService.getSharedKey(currentUser?.uid ?? '', widget.peerUid);
      final data = {
        'selfDestruct': true,
        'destroyAfter': duration,
        'createdAt': now,
        'timestamp': now, // Ensure all messages have timestamp for query
        'fromUid': currentUser?.uid,
        'fromUsername': currentUser?.displayName ?? '',
        'toUid': widget.peerUid,
        'toUsername': widget.peerUsername,
      };
      print('Sending self-destruct message: $data');
      if (mediaPath != null) {
        // Upload to Cloudinary, get mediaUrl and mediaPublicId
        final uploadResult = await ChatFeatures.uploadToCloudinary(File(mediaPath), 'media');
        data['mediaUrl'] = EncryptionService.encryptText(uploadResult ?? '', key);
        data['mediaPublicId'] = mediaPath.split('/').last.split('.').first;
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .add(data);
      } else {
        data['message'] = EncryptionService.encryptText(text, key);
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .add(data);
      }
    } catch (e) {
      setState(() {
        _messageError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _downloadFile(String url, String fileName, String fileType) {
    ChatFeatures.downloadFile(
      url: url,
      fileName: fileName,
      fileType: fileType,
      context: context,
      downloadedFiles: _downloadedFiles,
      updateDownloadedFiles: _updateDownloadedFiles,
    );
  }

  void _onLongPressMessage(Map<String, dynamic> msg) {
    setState(() {
      _selectedMessage = msg;
      _showActionBar = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMessage = null;
      _showActionBar = false;
    });
  }

  Future<void> _deleteSelectedMessage() async {
    if (_selectedMessage == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(_selectedMessage!['id'])
          .delete();
      _clearSelection();
    } catch (e) {
      _clearSelection();
    }
  }

  void _shareSelectedMessage() async {
    if (_selectedMessage == null) return;
    final msg = _selectedMessage!;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ShareMessageScreen(
          message: msg,
          onSend: (userId, message) async {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) return;
            final chatId = ChatUtils.getChatId(currentUser.uid, userId);
            final key = EncryptionService.getSharedKey(currentUser.uid, userId);
            final Map<String, dynamic> newMsg = {
              'fromUid': currentUser.uid,
              'fromUsername': currentUser.displayName ?? '',
              'toUid': userId,
              'timestamp': FieldValue.serverTimestamp(),
            };
            if (message['mediaType'] != null) {
              newMsg['mediaType'] = message['mediaType'];
              if (message['mediaType'] == 'image' || message['mediaType'] == 'video' || message['mediaType'] == 'audio' || message['mediaType'] == 'pdf' || message['mediaType'] == 'document') {
                newMsg['message'] = EncryptionService.encryptText(message['decryptedUrl'] ?? message['message'], key);
                if (message['fileName'] != null) newMsg['fileName'] = message['fileName'];
                if (message['mediaUrl'] != null) newMsg['mediaUrl'] = message['mediaUrl'];
                if (message['mediaPublicId'] != null) newMsg['mediaPublicId'] = message['mediaPublicId'];
              }
            } else {
              newMsg['message'] = EncryptionService.encryptText(message['message'], key);
            }
            await FirebaseFirestore.instance
                .collection('chats')
                .doc(chatId)
                .collection('messages')
                .add(newMsg);
          },
        ),
      ),
    );
    _clearSelection();
  }

  @override
  void dispose() {
    _audioRecorder?.closeRecorder();
    _audioPlayer?.closePlayer();
    _scrollController.dispose();
    _recordTimer?.cancel();
    SelfDestructService.stopListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "You are not logged in.",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _showActionBar
          ? AppBar(
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text('1 selected'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _deleteSelectedMessage,
          ),
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _shareSelectedMessage,
          ),
        ],
      )
          : ChatAppBar(
        title: widget.peerName.isNotEmpty ? widget.peerName : widget.peerUsername, // Show full name if available

      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                : messages.isEmpty
                ? Center(
              child: Text(
                'No messages yet.',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                ),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                final isMine = msg['fromUid'] == currentUser.uid;
                return ChatBubble(
                  message: msg,
                  isMine: isMine,
                  currentUserId: currentUser.uid,
                  downloadedFiles: _downloadedFiles,
                  updateDownloadedFiles: _updateDownloadedFiles,
                  showImageDialog: _showImageDialog,
                  showVideoDialog: _showVideoDialog,
                  playAudio: _playAudio,
                  isPlaying: _isPlaying,
                  currentAudioUrl: _currentAudioUrl,
                  onLongPress: () => _onLongPressMessage(msg),
                  downloadFile: _downloadFile,
                );
              },
            ),
          ),
          ChatInputField(
            controller: _messageController,
            errorMessage: _messageError,
            isUploading: _isUploading,
            isRecording: _isRecording,
            isRecorderReady: _isRecorderReady,
            recordDuration: _recordDuration,
            onSendMessage: _sendMessage,
            onPickMedia: _pickMediaFromGallery,
            onStartRecording: _startRecording,
            onStopRecording: _stopRecordingAndSend,
            onSendSelfDestructMessage: () => _openSelfDestructDialog(),
            isSelfDestructEnabled: _isSelfDestructEnabled,
            onOpenSelfDestructDialog: _openSelfDestructDialog,
          ),
        ],
      ),
    );
  }
}

// Self-Destruct Dialog Widget
class SelfDestructDialog extends StatefulWidget {
  final String messagePreview;
  final bool hasMedia;
  final Function(int) onSend;

  const SelfDestructDialog({
    Key? key,
    required this.messagePreview,
    required this.hasMedia,
    required this.onSend,
  }) : super(key: key);

  @override
  State<SelfDestructDialog> createState() => _SelfDestructDialogState();
}

class _SelfDestructDialogState extends State<SelfDestructDialog> {
  int _selectedDuration = 5;
  final List<int> _durations = [5, 10, 60];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Color(0xFF5B5FE9),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send Self-Destruct Message',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                )),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.07 * 255).toInt()),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.hasMedia ? Icons.image : Icons.message, color: Color(0xFF5B5FE9)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.messagePreview.isEmpty ? 'No text entered' : widget.messagePreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 22),
            Text('Choose timer:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _durations.map((d) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(d == 60 ? '1m' : '${d}s', style: TextStyle(color: _selectedDuration == d ? Colors.white : Color(0xFF5B5FE9), fontWeight: FontWeight.bold)),
                  selected: _selectedDuration == d,
                  selectedColor: Color(0xFF7F53AC),
                  backgroundColor: Colors.white,
                  onSelected: (_) => setState(() => _selectedDuration = d),
                  elevation: 2,
                ),
              )).toList(),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.local_fire_department, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                label: Text('Send Self-Destruct Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () {
                  widget.onSend(_selectedDuration);
                  Navigator.of(context).pop();
                },
              ),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// Self-Destruct Service Class
class SelfDestructService {
  static StreamSubscription? _listener;

  static void startListener(String chatId, {bool isGroup = false}) {
    final collection = isGroup ? 'groups' : 'chats';
    final messagesRef = FirebaseFirestore.instance
        .collection(collection)
        .doc(chatId)
        .collection('messages');

    _listener?.cancel();
    _listener = messagesRef.snapshots().listen((snapshot) async {
      final now = DateTime.now();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['selfDestruct'] == true && data['createdAt'] != null && data['destroyAfter'] != null) {
          final createdAt = (data['createdAt'] as Timestamp).toDate();
          final destroyAfter = data['destroyAfter'] as int;
          final expireTime = createdAt.add(Duration(seconds: destroyAfter));
          if (now.isAfter(expireTime)) {
            // Delete media from Cloudinary if present
            if (data['mediaUrl'] != null && data['mediaPublicId'] != null) {
              await _deleteFromCloudinary(data['mediaPublicId']);
            }
            // Delete Firestore message
            await doc.reference.delete();
          }
        }
      }
    });
  }

  static Future<void> _deleteFromCloudinary(String publicId) async {
    // Replace with your Cloudinary credentials
    const cloudName = 'YOUR_CLOUD_NAME';
    const apiKey = 'YOUR_API_KEY';
    const apiSecret = 'YOUR_API_SECRET';
    final url =
        'https://api.cloudinary.com/v1_1/$cloudName/resources/image/upload?public_ids[]=$publicId&invalidate=true';
    final auth = 'Basic ' + base64Encode(utf8.encode('$apiKey:$apiSecret'));
    await http.delete(
      Uri.parse(url),
      headers: {'Authorization': auth},
    );
  }

  static void stopListener() {
    _listener?.cancel();
    _listener = null;
  }
}
