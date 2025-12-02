import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

import '../../Service/chatfeature.dart';
import '../../Service/chatutils.dart';
import '../../Service/encryption.dart';
import '../../Service/groupfeatures.dart'; // Import ChatScreen for navigation
import '../chat/Chatscreen.dart'; // Use the correct file for ChatScreen
import '../chat/chatwidgets.dart';
import '../profile_screen.dart';
import 'create_group_screen.dart'; // Import AddGroupMembersScreen
// Import CreateGroupScreen


class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
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

  // Group specific
  Map<String, dynamic>? _groupInfo;
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isAdmin = false;
  bool _isMuted = false;
  String _currentGroupName = '';

  // Self-destruct feature
  bool _isSelfDestructEnabled = false;
  String? _pendingMediaPath;

  // Pagination
  static const int _messagesPageSize = 30;
  DocumentSnapshot? _lastMessageSnapshot;
  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _currentGroupName = widget.groupName;
    _initializeApp();
    _messageController.addListener(_updateSelfDestructEnabled);
    // Start self-destruct listener for group chat
    SelfDestructService.startListener(widget.groupId, isGroup: true);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <= 100 && !_loading && !_isLoadingMore && _hasMoreMessages) {
        _loadMoreMessages();
      }
    });
  }

  void _updateSelfDestructEnabled() {
    setState(() {
      _isSelfDestructEnabled = _messageController.text.trim().isNotEmpty || _pendingMediaPath != null;
    });
  }

  Future<void> _initializeApp() async {
    _audioRecorder = FlutterSoundRecorder();
    _audioPlayer = FlutterSoundPlayer();

    await _initRecorder();
    await _audioPlayer?.openPlayer();
    await _loadGroupInfo();
    await _loadInitialMessages();
    await _checkAdminStatus();
    await _loadMuteStatus();
    await ChatFeatures.requestStoragePermission();
  }

  Future<void> _loadGroupInfo() async {
    try {
      final groupInfo = await GroupFeatures.getGroupInfo(widget.groupId);
      final members = await GroupFeatures.getGroupMembers(widget.groupId);

      if (mounted) {
        setState(() {
          _groupInfo = groupInfo;
          _groupMembers = members;
          if (groupInfo != null) {
            _currentGroupName = groupInfo['groupName'] ?? widget.groupName;
          }
        });
      }
    } catch (e) {
      print('❌ Error loading group info: $e');
    }
  }

  Future<void> _checkAdminStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final isAdmin = await GroupFeatures.isAdmin(
        groupId: widget.groupId,
        userId: currentUser.uid,
      );

      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    } catch (e) {
      print('❌ Error checking admin status: $e');
    }
  }

  Future<void> _loadMuteStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final isMuted = await GroupFeatures.getMuteStatus(
        groupId: widget.groupId,
        userId: currentUser.uid,
      );

      if (mounted) {
        setState(() {
          _isMuted = isMuted;
        });
      }
    } catch (e) {
      print('❌ Error loading mute status: $e');
    }
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

  // Real-time stream for latest messages
  Stream<List<Map<String, dynamic>>> _latestMessagesStream() {
    return FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_messagesPageSize)
        .snapshots()
        .map((snapshot) {
      final key = EncryptionService.getGroupKey(widget.groupId);
      List<Map<String, dynamic>> loadedMessages = [];
      for (var doc in snapshot.docs) {
        final msg = doc.data();
        msg['id'] = doc.id;
        final messageType = msg['type'];
        final mediaType = msg['mediaType'];
        if (messageType == 'system') {
          loadedMessages.add(msg);
          continue;
        }
        if (mediaType == null) {
          try {
            msg['message'] = EncryptionService.decryptText(msg['message'], key);
          } catch (e) {
            msg['message'] = '[Encrypted message]';
          }
        } else {
          try {
            msg['decryptedUrl'] = EncryptionService.decryptText(msg['message'], key);
          } catch (e) {
            msg['decryptedUrl'] = null;
          }
        }
        loadedMessages.add(msg);
      }
      return loadedMessages.reversed.toList(); // oldest at top
    });
  }

  Future<void> _loadInitialMessages() async {
    setState(() { _loading = true; });
    final query = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(_messagesPageSize);
    final snapshot = await query.get();
    final key = EncryptionService.getGroupKey(widget.groupId);
    List<Map<String, dynamic>> loadedMessages = [];
    for (var doc in snapshot.docs) {
      final msg = doc.data();
      msg['id'] = doc.id;
      final messageType = msg['type'];
      final mediaType = msg['mediaType'];
      if (messageType == 'system') {
        loadedMessages.add(msg);
        continue;
      }
      if (mediaType == null) {
        try {
          msg['message'] = EncryptionService.decryptText(msg['message'], key);
        } catch (e) {
          msg['message'] = '[Encrypted message]';
        }
      } else {
        try {
          msg['decryptedUrl'] = EncryptionService.decryptText(msg['message'], key);
        } catch (e) {
          msg['decryptedUrl'] = null;
        }
      }
      loadedMessages.add(msg);
    }
    setState(() {
      messages = loadedMessages.reversed.toList(); // oldest at top
      _loading = false;
      _lastMessageSnapshot = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      _hasMoreMessages = snapshot.docs.length == _messagesPageSize;
    });
  }

  Future<void> _loadMoreMessages() async {
    if (!_hasMoreMessages || _isLoadingMore || _lastMessageSnapshot == null) return;
    setState(() { _isLoadingMore = true; });
    final query = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(_lastMessageSnapshot!)
        .limit(_messagesPageSize);
    final snapshot = await query.get();
    final key = EncryptionService.getGroupKey(widget.groupId);
    List<Map<String, dynamic>> loadedMessages = [];
    for (var doc in snapshot.docs) {
      final msg = doc.data();
      msg['id'] = doc.id;
      final messageType = msg['type'];
      final mediaType = msg['mediaType'];
      if (messageType == 'system') {
        loadedMessages.add(msg);
        continue;
      }
      if (mediaType == null) {
        try {
          msg['message'] = EncryptionService.decryptText(msg['message'], key);
        } catch (e) {
          msg['message'] = '[Encrypted message]';
        }
      } else {
        try {
          msg['decryptedUrl'] = EncryptionService.decryptText(msg['message'], key);
        } catch (e) {
          msg['decryptedUrl'] = null;
        }
      }
      loadedMessages.add(msg);
    }
    setState(() {
      messages = [...loadedMessages.reversed, ...messages];
      _lastMessageSnapshot = snapshot.docs.isNotEmpty ? snapshot.docs.last : _lastMessageSnapshot;
      _hasMoreMessages = snapshot.docs.length == _messagesPageSize;
      _isLoadingMore = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    _messageController.clear();

    try {
      setState(() => _messageError = null);

      await ChatFeatures.sendMessage(
        text: text,
        peerUid: '', // Not used for groups
        groupId: widget.groupId,
        isGroup: true,
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

        setState(() { _pendingMediaPath = file.path; });
        _updateSelfDestructEnabled();
      }
    } catch (e) {
      _showSnackBar('Failed to select file. Please try again.');
    }
  }

  Future<void> _pickDocumentFiles() async {
    try {
      final file = await ChatFeatures.pickDocumentFile();
      if (file != null) {
        if (!await ChatUtils.validateFileSize(file)) {
          _showSnackBar('File too large. Maximum size is 50MB.');
          return;
        }

        await ChatFeatures.sendMediaMessage(
          file: file,
          fileName: file.path.split('/').last,
          peerUid: '', // Not used for groups
          groupId: widget.groupId,
          isGroup: true,
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
      await ChatFeatures.sendMediaMessage(
        file: audioFile,
        fileName: audioFile.path.split('/').last,
        peerUid: '', // Not used for groups
        groupId: widget.groupId,
        isGroup: true,
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
      builder: (context) => ImageDialog(imageUrl: imageUrl, parentContext: this.context,),
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

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GroupInfoBottomSheet(
        groupInfo: _groupInfo,
        groupMembers: _groupMembers,
        isAdmin: _isAdmin,
        isMuted: _isMuted,
        onGroupNameChanged: _updateGroupName,
        onMemberAdded: _addMember,
        onMemberRemoved: _removeMember,
        onMemberMadeAdmin: _makeMemberAdmin,
        onToggleMute: _toggleMute,
        onLeaveGroup: _leaveGroup,
        onDeleteGroup: _deleteGroup,
        groupName: _currentGroupName, // <-- Pass the group name here
      ),
    );
  }

  Future<void> _updateGroupName(String newName) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await GroupFeatures.updateGroupName(
        groupId: widget.groupId,
        newName: newName,
        currentUserUid: currentUser.uid,
      );

      setState(() {
        _currentGroupName = newName;
      });

      _showSnackBar('Group name updated successfully', color: Colors.green);
      await _loadGroupInfo(); // Refresh group info
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _addMember(String memberUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await GroupFeatures.addMember(
        groupId: widget.groupId,
        newMemberUid: memberUid,
        currentUserUid: currentUser.uid,
      );

      _showSnackBar('Member added successfully', color: Colors.green);
      await _loadGroupInfo(); // Refresh member list
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _removeMember(String memberUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await GroupFeatures.removeMember(
        groupId: widget.groupId,
        memberUid: memberUid,
        currentUserUid: currentUser.uid,
      );

      _showSnackBar('Member removed successfully', color: Colors.green);
      await _loadGroupInfo(); // Refresh member list
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _makeMemberAdmin(String memberUid) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await GroupFeatures.makeAdmin(
        groupId: widget.groupId,
        memberUid: memberUid,
        currentUserUid: currentUser.uid,
      );

      _showSnackBar('Member made admin successfully', color: Colors.green);
      await _loadGroupInfo(); // Refresh member list
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _toggleMute() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await GroupFeatures.toggleMuteNotifications(
        groupId: widget.groupId,
        userId: currentUser.uid,
        mute: !_isMuted,
      );

      setState(() {
        _isMuted = !_isMuted;
      });

      _showSnackBar(
        _isMuted ? 'Notifications muted' : 'Notifications enabled',
        color: Colors.green,
      );
    } catch (e) {
      _showSnackBar('Failed to update notification settings');
    }
  }

  Future<void> _leaveGroup() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Group'),
        content: Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await GroupFeatures.leaveGroup(
          groupId: widget.groupId,
          userId: currentUser.uid,
        );

        _showSnackBar('Left group successfully', color: Colors.green);
        Navigator.of(context).pop(); // Go back to previous screen
      } catch (e) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _deleteGroup() async {
    await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).delete();
    Navigator.of(context).pop(); // Close info sheet
    Navigator.of(context).pop(); // Go back to previous screen
  }

  Future<void> _deleteGroupMessage(Map<String, dynamic> message) async {
    try {
      // Delete media from Cloudinary if applicable
      if (message['mediaType'] != null && message['decryptedUrl'] != null) {
        await ChatFeatures.deleteFromCloudinary(message['decryptedUrl'], message['mediaType']);
      }
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .doc(message['id']) // Assuming message document has an 'id' field
          .delete();

      _showSnackBar('Message deleted successfully', color: Colors.green);
    } catch (e) {
      _showSnackBar('Failed to delete message');
    }
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
      final data = {
        'selfDestruct': true,
        'destroyAfter': duration,
        'createdAt': Timestamp.now(),
      };
      if (mediaPath != null) {
        await ChatFeatures.sendMediaMessage(
          file: File(mediaPath),
          fileName: mediaPath.split('/').last,
          peerUid: '',
          groupId: widget.groupId,
          isGroup: true,
          customFields: data,
          setUploadingState: (uploading) => setState(() => _isUploading = uploading),
          showSnackBar: _showSnackBar,
        );
      } else {
        await ChatFeatures.sendMessage(
          text: text,
          peerUid: '',
          groupId: widget.groupId,
          isGroup: true,
          customFields: data,
        );
      }
    } catch (e) {
      setState(() {
        _messageError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder?.closeRecorder();
    _audioPlayer?.closePlayer();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _messageController.removeListener(_updateSelfDestructEnabled);
    // Stop self-destruct listener for group chat
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
      appBar: ChatAppBar(
        title: _currentGroupName,
        subtitle: '${_groupMembers.length} members',
        additionalActions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.black),
            onPressed: _showGroupInfo,
          ),
        ],
        // Do not pass onMorePressed, so 3 dots are not shown
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _latestMessagesStream(),
              builder: (context, snapshot) {
                if (_loading || !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.teal));
                }
                final latestMessages = snapshot.data!;
                final allMessages = [...messages, ...latestMessages.where((m) => !messages.any((old) => old['id'] == m['id']))];
                if (allMessages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  itemCount: allMessages.length,
                  itemBuilder: (context, index) {
                    final msg = allMessages[index];
                    final messageType = msg['type'];
                    if (messageType == 'system') {
                      return SystemMessageBubble(
                        message: msg['message'],
                        timestamp: msg['timestamp'],
                        systemType: msg['systemType'],
                      );
                    }
                    final isMine = msg['fromUid'] == currentUser.uid;
                    return GroupChatBubble(
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
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => Dialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
                                  SizedBox(height: 16),
                                  Text('Delete Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.teal)),
                                  SizedBox(height: 12),
                                  Text('Are you sure you want to delete this message for everyone? This action cannot be undone.',
                                    style: TextStyle(fontSize: 15, color: Colors.black87), textAlign: TextAlign.center),
                                  SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                                        child: Text('Cancel'),
                                      ),
                                      SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 18),
                                            SizedBox(width: 4),
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                        if (confirm == true) {
                          await _deleteGroupMessage(msg);
                        }
                      },
                    );
                  },
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

class SystemMessageBubble extends StatelessWidget {
  final String message;
  final Timestamp? timestamp;
  final String? systemType;

  const SystemMessageBubble({
    Key? key,
    required this.message,
    this.timestamp,
    this.systemType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 20),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class GroupChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final String currentUserId;
  final Map<String, String> downloadedFiles;
  final Function(String, String) updateDownloadedFiles;
  final Function(String) showImageDialog;
  final Function(String) showVideoDialog;
  final Function(String) playAudio;
  final bool isPlaying;
  final String? currentAudioUrl;
  final VoidCallback? onLongPress;

  const GroupChatBubble({
    Key? key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    required this.downloadedFiles,
    required this.updateDownloadedFiles,
    required this.showImageDialog,
    required this.showVideoDialog,
    required this.playAudio,
    required this.isPlaying,
    this.currentAudioUrl,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Show sender name for group messages (except own messages)
          if (!isMine)
            Padding(
              padding: EdgeInsets.only(left: 12, bottom: 2, right: 40),
              child: Text(
                message['fromUsername'] ?? 'Unknown',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ChatBubble(
            message: message,
            isMine: isMine,
            currentUserId: currentUserId,
            downloadedFiles: downloadedFiles,
            updateDownloadedFiles: updateDownloadedFiles,
            showImageDialog: showImageDialog,
            showVideoDialog: showVideoDialog,
            playAudio: playAudio,
            isPlaying: isPlaying,
            currentAudioUrl: currentAudioUrl,
            onLongPress: onLongPress,
            downloadFile: (String url, String fileName, String fileType) {  },
          ),
        ],
      ),
    );
  }
}

class GroupInfoBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? groupInfo;
  final List<Map<String, dynamic>> groupMembers;
  final bool isAdmin;
  final bool isMuted;
  final Function(String) onGroupNameChanged;
  final Function(String) onMemberAdded;
  final Function(String) onMemberRemoved;
  final Function(String) onMemberMadeAdmin;
  final VoidCallback onToggleMute;
  final VoidCallback onLeaveGroup;
  final VoidCallback onDeleteGroup;
  final String groupName; // <-- Add this line

  const GroupInfoBottomSheet({
    Key? key,
    required this.groupInfo,
    required this.groupMembers,
    required this.isAdmin,
    required this.isMuted,
    required this.onGroupNameChanged,
    required this.onMemberAdded,
    required this.onMemberRemoved,
    required this.onMemberMadeAdmin,
    required this.onToggleMute,
    required this.onLeaveGroup,
    required this.onDeleteGroup,
    required this.groupName, // <-- Add this line
  }) : super(key: key);

  @override
  State<GroupInfoBottomSheet> createState() => _GroupInfoBottomSheetState();
}

class _GroupInfoBottomSheetState extends State<GroupInfoBottomSheet> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _addMemberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _groupNameController.text = widget.groupInfo?['groupName'] ?? '';
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _addMemberController.dispose();
    super.dispose();
  }

  void _showEditGroupNameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Group Name'),
        content: TextField(
          controller: _groupNameController,
          decoration: InputDecoration(
            hintText: 'Enter group name',
            border: OutlineInputBorder(),
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = _groupNameController.text.trim();
              if (newName.isNotEmpty && newName != widget.groupInfo?['groupName']) {
                widget.onGroupNameChanged(newName);
                Navigator.of(context).pop();
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() async {
    final memberUids = widget.groupMembers.map((m) => m['uid'] as String).toSet();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateGroupScreen(
          isAddMembersMode: true,
          initialSelectedUserIds: memberUids,
          onMembersAdded: (List<String> newUids) {
            for (final uid in newUids) {
              if (!memberUids.contains(uid)) {
                widget.onMemberAdded(uid);
              }
            }
          },
        ),
      ),
    );
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (member['uid'] == currentUser?.uid) {
      return; // Don't show options for current user
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userUid: member['uid'],
                    ),
                  ));
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Text(
                        (member['username'] ?? 'U')[0].toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member['username'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (member['isAdmin'])
                            Text(
                              'Admin',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1),
            if (widget.isAdmin && !member['isAdmin'])
              ListTile(
                leading: Icon(Icons.admin_panel_settings, color: Colors.orange),
                title: Text('Make Admin'),
                onTap: () {
                  Navigator.pop(context);
                  _showMakeAdminDialog(member);
                },
              ),
            if (widget.isAdmin && member['isAdmin'] && member['uid'] != currentUser?.uid)
              ListTile(
                leading: Icon(Icons.admin_panel_settings_outlined, color: Colors.grey),
                title: Text('Remove Admin'),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveAdminDialog(member);
                },
              ),
            ListTile(
              leading: Icon(Icons.message, color: Colors.blue),
              title: Text('Send Message'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    peerUid: member['uid'],
                    peerUsername: member['username'],
                    peerName: member['name'] ?? '', // Pass full name or empty string
                  ),
                ));
              },
            ),
            // Only show Delete Member for the group creator and not for themselves
            if (widget.groupInfo != null && widget.groupInfo!['createdBy'] == currentUser?.uid && member['uid'] != currentUser?.uid)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Member'),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMemberRemoved(member['uid']);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showMakeAdminDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Make Admin'),
        content: Text('Are you sure you want to make ${member['username']} an admin of this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onMemberMadeAdmin(member['uid']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text('Make Admin'),
          ),
        ],
      ),
    );
  }

  void _showRemoveAdminDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Admin'),
        content: Text('Are you sure you want to remove ${member['username']} as an admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement remove admin functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Remove admin feature coming soon!')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
            child: Text('Remove Admin'),
          ),
        ],
      ),
    );
  }

  void _showRemoveMemberDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Member'),
        content: Text('Are you sure you want to remove ${member['username']} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onMemberRemoved(member['uid']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCreator = widget.groupInfo != null && widget.groupInfo!['createdBy'] == currentUser?.uid;
    final canAddMembers = widget.isAdmin || isCreator;
    // Always show the group name: prefer groupInfo['groupName'], fallback to widget.groupName
    final groupName = (widget.groupInfo != null && widget.groupInfo!['groupName'] != null && widget.groupInfo!['groupName'].toString().trim().isNotEmpty)
        ? widget.groupInfo!['groupName']
        : widget.groupName;
    final createdBy = widget.groupInfo?['createdBy'];
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Group header
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.teal,
                  backgroundImage: widget.groupInfo?['groupIcon'] != null
                      ? NetworkImage(widget.groupInfo!['groupIcon'])
                      : null,
                  child: widget.groupInfo?['groupIcon'] == null
                      ? Text(
                    (groupName.isNotEmpty ? groupName[0] : 'G').toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                      : null,
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        groupName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (widget.isAdmin)
                      IconButton(
                        icon: Icon(Icons.edit, size: 20, color: Colors.grey),
                        onPressed: _showEditGroupNameDialog,
                      ),
                  ],
                ),
                Text(
                  '${widget.groupMembers.length} members',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                if (widget.groupInfo?['description']?.isNotEmpty == true)
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.groupInfo!['description'],
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          // Group options
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                if (canAddMembers)
                  ListTile(
                    leading: Icon(Icons.person_add, color: Colors.blue),
                    title: Text('Add Members'),
                    onTap: _showAddMemberDialog,
                  ),
                if (isCreator)
                  ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Delete Group'),
                    onTap: widget.onDeleteGroup,
                  ),
                // Only show Leave Group for non-admins
                if (!widget.isAdmin && !isCreator)
                  ListTile(
                    leading: Icon(Icons.exit_to_app, color: Colors.red),
                    title: Text('Leave Group'),
                    onTap: widget.onLeaveGroup,
                  ),
              ],
            ),
          ),

          Divider(),

          // Members section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Members',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${widget.groupMembers.length}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.groupMembers.length,
                    itemBuilder: (context, index) {
                      final member = widget.groupMembers[index];
                      final isCurrentUser = member['uid'] == FirebaseAuth.instance.currentUser?.uid;
                      final isAdminOrCreator = member['isAdmin'] == true || member['uid'] == createdBy;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Text(
                            (member['username'] ?? 'U')[0].toUpperCase(),
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                member['username'] ?? 'Unknown',
                                style: TextStyle(
                                  fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (isAdminOrCreator)
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(255, 165, 0, 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange, width: 1),
                                ),
                                child: Text(
                                  'Admin',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: isCurrentUser
                            ? Text(
                          'You',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                            : null,
                        onTap: () => _showMemberOptions(member),
                        trailing: isCurrentUser
                            ? null
                            : Icon(Icons.more_vert, color: Colors.grey),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
  int _selectedDuration = 10;
  final List<int> _durations = [10, 30, 60, 120];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Send Self-Destructing Message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This message will self-destruct after a set duration.',
            style: TextStyle(color: Colors.black87),
          ),
          SizedBox(height: 16),
          Text(
            'Message Preview: ${widget.messagePreview.isEmpty ? "No text entered" : widget.messagePreview}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          if (widget.hasMedia) ...[
            SizedBox(height: 8),
            Text(
              'Media attached',
              style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
            ),
          ],
          SizedBox(height: 16),
          Text('Select duration (in seconds):'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _durations.map((duration) {
              return ChoiceChip(
                label: Text('$duration'),
                selected: _selectedDuration == duration,
                onSelected: (_) {
                  setState(() => _selectedDuration = duration);
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSend(_selectedDuration);
            Navigator.of(context).pop();
          },
          child: Text('Send'),
        ),
      ],
    );
  }
}
