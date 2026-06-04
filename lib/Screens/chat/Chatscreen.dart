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
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';
import '../profile_screen.dart';

import '../../Service/self_destruct_service.dart';
import 'self_destruct_dialog.dart';

import 'voice_effect_picker.dart';
import '../../Service/voice_effect_api_service.dart';


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

  String? _rawRecordedPath;


  // Audio recording
  FlutterSoundRecorder? _audioRecorder;
  FlutterSoundPlayer? _audioPlayer;
  bool _isRecording = false;
  bool _isRecorderReady = false;
  bool _isPlaying = false;
  String? _currentAudioUrl;
  int _recordDuration = 0;
  Timer? _recordTimer;

  bool _iBlockedHim = false;
  bool _heBlockedMe = false;

  // Messages and state
  List<Map<String, dynamic>> messages = [];
  bool _loading = true;
  bool _isUploading = false;
  Map<String, String> _downloadedFiles = {};

  String get _senderName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ??
        user?.email?.split('@').first ??
        "Someone";
  }

  Future<String> _getSenderNameFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return "Someone";

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    if (!doc.exists) return "Someone";

    return doc.data()?["name"]
        ?? doc.data()?["username"]
        ?? "Someone";
  }


  // Self-destruct feature
  bool _isSelfDestructEnabled = false;
  String? _pendingMediaPath;
  String? _selfDestructPath; // stored path used by SelfDestructService

  // Long press actions
  Map<String, dynamic>? _selectedMessage;
  bool _showActionBar = false;

  String get chatId => ChatUtils.getChatId(FirebaseAuth.instance.currentUser?.uid ?? '', widget.peerUid);

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _checkBlockStatus();
    _messageController.addListener(_updateSelfDestructEnabled);
    _startSelfDestructListener(); // safe start (will verify currentUser)
  }

  Future<void> _startSelfDestructListener() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final id = ChatUtils.getChatId(currentUser.uid, widget.peerUid);
    _selfDestructPath = 'chats/$id/messages';
    SelfDestructService.listenForSelfDestructMessages(_selfDestructPath!);
  }

  // ⚠️ ONLY RELEVANT PARTS SHOWN HERE TO AVOID 1,500+ LINES DUPLICATION
// ⛔ Everything else in your file remains EXACTLY SAME

// -------------------------------
// 🔔 PUSH NOTIFICATION (FIXED)
// -------------------------------
  Future<void> _sendPushNotification({
    required String toUid,
    required String senderName,
    required String text,
    required String messageType,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse("https://whisp-notify.onrender.com/send-chat-notification"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "toUid": toUid,
          "senderName": senderName, // ✅ REQUIRED
          "text": text,             // ✅ REQUIRED
          "messageType": messageType,
        }),
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print("❌ Notification API error: ${response.body}");
      }
    } catch (e) {
      print("❌ Push notification failed: $e");
    }
  }




  Future<bool> _isUserBlocked() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('blocked')
        .doc(widget.peerUid)
        .get();

    return doc.exists;
  }

  Future<void> _checkBlockStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // 1) Did I block him?
    final meBlockedDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('blocked')
        .doc(widget.peerUid)
        .get();

    // 2) Did he block me?
    final heBlockedDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.peerUid)
        .collection('blocked')
        .doc(currentUser.uid)
        .get();

    setState(() {
      _iBlockedHim = meBlockedDoc.exists;
      _heBlockedMe = heBlockedDoc.exists;
    });
  }

  Future<void> _blockUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('blocked')
        .doc(widget.peerUid)
        .set({
      "username": widget.peerUsername,
      "name": widget.peerName,
      "blockedAt": FieldValue.serverTimestamp(),
    });

    setState(() {});
    _showSnackBar("${widget.peerUsername} has been blocked",
        color: Colors.redAccent);
  }

  Future<void> _unblockUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('blocked')
        .doc(widget.peerUid)
        .delete();

    setState(() {});
    _showSnackBar("${widget.peerUsername} unblocked",
        color: Colors.green);
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
      final key = EncryptionService.getSharedKey(
          currentUser.uid, widget.peerUid);

      List<Map<String, dynamic>> loadedMessages = [];
      print('Firestore snapshot docs count: ${snapshot.docs.length}');

      for (var doc in snapshot.docs) {
        final msg = doc.data() as Map<String, dynamic>;
        msg['id'] = doc.id;

        print('Firestore raw message: $msg');

        // -------------------------------
        // SELF-DESTRUCT — Auto Skip Expired
        // -------------------------------
        if (msg["selfDestruct"] == true &&
            msg["createdAt"] != null &&
            msg["destroyAfter"] != null) {
          final createdAt = (msg["createdAt"] as Timestamp).toDate();
          final expireAt = createdAt.add(
            Duration(seconds: msg["destroyAfter"]),
          );

          if (DateTime.now().isAfter(expireAt)) {
            // Already expired → do not show
            continue;
          }
        }

        // -------------------------------
        // DECRYPT TEXT OR MEDIA URL
        // -------------------------------
        if (msg.containsKey('mediaType') && msg['mediaType'] != null) {
          try {
            msg['decryptedUrl'] =
                EncryptionService.decryptText(msg['message'], key);
          } catch (e) {
            print('❌ Failed to decrypt media URL: $e');
            msg['decryptedUrl'] = msg['message']; // fallback
          }
        } else {
          try {
            msg['message'] =
                EncryptionService.decryptText(msg['message'], key);
          } catch (e) {
            print('❌ Failed to decrypt text message: $e');
            msg['message'] = msg['message']; // fallback
          }
        }

        loadedMessages.add(msg);
      }

      if (mounted) {
        setState(() {
          messages = loadedMessages;
          _loading = false;
        });

        // Scroll to bottom after UI update
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
    if (_iBlockedHim) {
      _showSnackBar("You have blocked this user.");
      return;
    }

    if (_heBlockedMe) {
      _showSnackBar("You cannot send message. This user has blocked you.");
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      setState(() => _messageError = null);

      await ChatFeatures.sendMessage(
        text: text,
        peerUid: widget.peerUid,
        peerUsername: widget.peerUsername,
      );

      final senderName = await _getSenderNameFromFirestore();

      await _sendPushNotification(
        toUid: widget.peerUid,
        senderName: senderName,
        text: text,
        messageType: "text",
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
        final senderName = await _getSenderNameFromFirestore();
        // 🔔 ADD THIS
        await _sendPushNotification(
          toUid: widget.peerUid,
          senderName: senderName,
          text: "",
          messageType: "image",
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
        final senderName = await _getSenderNameFromFirestore();
        await _sendPushNotification(
          toUid: widget.peerUid,
          senderName: senderName,
          text: "",
          messageType: "document",
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
        _rawRecordedPath = path;
        _openVoiceEffectPicker();
      }

    } catch (e) {
      _showSnackBar('Failed to stop recording');
    }
  }

  void _openVoiceEffectPicker() {
    if (_rawRecordedPath == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => VoiceEffectPicker(
        rawAudio: File(_rawRecordedPath!),

        // APPLY → send processed voice
        onApply: (processedFile) async {
          Navigator.pop(context);
          await _sendVoiceMessage(processedFile);

          // cleanup raw file
          try {
            File(_rawRecordedPath!).delete();
          } catch (_) {}
          _rawRecordedPath = null;
        },

        // CANCEL → discard recording
        onCancel: () {
          Navigator.pop(context);
          try {
            File(_rawRecordedPath!).delete();
          } catch (_) {}
          _rawRecordedPath = null;
        },
      ),
    );
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
      final senderName = await _getSenderNameFromFirestore();
      // 🔔 ADD THIS
      await _sendPushNotification(
        toUid: widget.peerUid,
        senderName: senderName,
        text: "",
        messageType: "audio",
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
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final chatId = ChatUtils.getChatId(currentUser.uid, widget.peerUid);
      final key = EncryptionService.getSharedKey(currentUser.uid, widget.peerUid);
      final now = Timestamp.now();

      Map<String, dynamic> data = {
        "selfDestruct": true,
        "destroyAfter": duration,
        "createdAt": now,
        "timestamp": now,
        "fromUid": currentUser.uid,
        "toUid": widget.peerUid,
        "mediaType": null,
      };

      if (mediaPath != null) {
        final uploadUrl = await ChatFeatures.uploadToCloudinary(
          File(mediaPath),
          "media",
        );

        data["mediaUrl"] = EncryptionService.encryptText(uploadUrl ?? "", key);
        data["mediaPublicId"] =
            mediaPath.split("/").last.split(".").first;
      } else {
        data["message"] = EncryptionService.encryptText(text, key);
      }

      await FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add(data);

    }

    catch (e) {
      setState(() {
        _messageError = e.toString().replaceAll("Exception: ", "");
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

    // stop self-destruct listener using stored path
    if (_selfDestructPath != null) {
      SelfDestructService.stopListener(_selfDestructPath!);
    }

    _messageController.removeListener(_updateSelfDestructEnabled);
    _messageController.dispose();

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

    // 💛 THEME INTEGRATED HERE
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final chatBgColor = isDark
        ? const Color(0xFF0D0D0D)            // dark mode background
        : themeProvider.chatBackground;      // themed background (yellow/purple/blue/etc.)

    return Scaffold(
      backgroundColor: chatBgColor,
      appBar: _showActionBar
          ? AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: _clearSelection,
        ),
        title: const Text(
          '1 selected',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.black),
            onPressed: _deleteSelectedMessage,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: _shareSelectedMessage,
          ),
        ],
      )

          : AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white, // 🔥 Android 12+
        elevation: 1,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),

        title: Text(
          widget.peerName.isNotEmpty
              ? widget.peerName
              : widget.peerUsername,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          FutureBuilder<bool>(
            future: _isUserBlocked(),
            builder: (context, snapshot) {
              final iBlockedUser = snapshot.data ?? false;

              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black),
                color: Colors.white,
                onSelected: (value) async {
                  if (value == "view") {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(userUid: widget.peerUid),
                      ),
                    );
                  } else if (value == "block") {
                    _blockUser();
                  } else if (value == "unblock") {
                    _unblockUser();
                  } else if (value == "self_destruct") {
                    _openSelfDestructDialog();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: "view",
                    child: Row(
                      children: [
                        Icon(Icons.person, color: Colors.black87),
                        SizedBox(width: 10),
                        Text("View Profile"),
                      ],
                    ),
                  ),
                  if (!iBlockedUser)
                    const PopupMenuItem(
                      value: "block",
                      child: Row(
                        children: [
                          Icon(Icons.block, color: Colors.red),
                          SizedBox(width: 10),
                          Text("Block User",
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  if (iBlockedUser)
                    const PopupMenuItem(
                      value: "unblock",
                      child: Row(
                        children: [
                          Icon(Icons.lock_open, color: Colors.green),
                          SizedBox(width: 10),
                          Text("Unblock User",
                              style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
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

            // NEW FLAGS ⬇⬇⬇
            iBlockedHim: _iBlockedHim,
            heBlockedMe: _heBlockedMe,
          ),
        ],
      ),
    );
  }
}
