import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../Service/chatfeature.dart';
import '../../Service/chatutils.dart';


class ChatBubble extends StatelessWidget {
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
  final void Function(String url, String fileName, String fileType) downloadFile;

  const ChatBubble({
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
    required this.downloadFile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mediaType = message['mediaType'];
    final fileName = message['fileName'];
    final displayContent = mediaType == null ? message['message'] : message['decryptedUrl'];

    if (displayContent == null && mediaType != null) {
      return Container(
        margin: EdgeInsets.only(
          bottom: 8,
          left: isMine ? 40 : 0,
          right: isMine ? 0 : 40,
        ),
        child: Text(
          '[Media decryption failed]',
          style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
        ),
      );
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: IntrinsicWidth(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            margin: EdgeInsets.only(
              bottom: 8,
              left: isMine ? 40 : 0,
              right: isMine ? 0 : 40,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 13),
            decoration: BoxDecoration(
              color: isMine ? Colors.teal : Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(isMine ? 15 : 5),
                bottomRight: Radius.circular(isMine ? 5 : 15),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 1.5,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMessageContent(context, mediaType, displayContent, fileName),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    ChatUtils.formatTime(message['timestamp'] as Timestamp?),
                    style: TextStyle(
                      color: isMine ? Colors.white70 : Colors.grey[700],
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, String? mediaType, String displayContent, String? fileName) {
    switch (mediaType) {
      case 'image':
        return _buildImageContent(displayContent, fileName);
      case 'video':
        return _buildVideoContent(displayContent, fileName);
      case 'audio':
        return _buildAudioContent(displayContent);
      case 'pdf':
      case 'document':
        return _buildDocumentContent(context, displayContent, fileName, mediaType);
      default:
        return _buildTextContent(displayContent);
    }
  }

  Widget _buildImageContent(String imageUrl, String? fileName) {
    return GestureDetector(
      onTap: () => showImageDialog(imageUrl),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              imageUrl,
              height: 180,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 180,
                  child: Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 180,
                child: Center(
                  child: Icon(Icons.broken_image, size: 60, color: Colors.red),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.download, color: Colors.white, size: 28),
              onPressed: () => downloadFile(
                imageUrl,
                fileName ?? 'whisp_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
                'image',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent(String videoUrl, String? fileName) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => showVideoDialog(videoUrl),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.videocam, size: 60, color: Colors.teal),
                  SizedBox(height: 8),
                  Text('Tap to play', style: TextStyle(color: Colors.teal)),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.download, color: Colors.white, size: 28),
            onPressed: () => downloadFile(
              videoUrl,
              fileName ?? 'whisp_video_${DateTime.now().millisecondsSinceEpoch}.mp4',
              'video',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioContent(String audioUrl) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isPlaying && currentAudioUrl == audioUrl ? Icons.pause : Icons.play_arrow,
            color: isMine ? Colors.white : Colors.teal,
            size: 28,
          ),
          onPressed: () => playAudio(audioUrl),
        ),
        Text(
          'Voice message',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: isMine ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentContent(BuildContext context, String documentUrl, String? fileName, String? mediaType) {
    return GestureDetector(
      onTap: () => _handleDocumentTap(context, documentUrl, fileName ?? 'Document'),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMine ? Colors.teal.withAlpha(51) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMine ? Colors.white : Colors.teal.withAlpha(77),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ChatUtils.getFileIcon(mediaType ?? 'document', fileName),
              color: isMine ? Colors.white : Colors.teal,
              size: 30,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName ?? 'Document',
                    style: TextStyle(
                      color: isMine ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    downloadedFiles.containsKey(documentUrl) ? 'Tap to open' : 'Tap to download',
                    style: TextStyle(
                      color: isMine ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(String text) {
    return Text(
      text,
      style: TextStyle(
        color: isMine ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
    );
  }

  void _handleDocumentTap(BuildContext context, String url, String fileName) {
    ChatFeatures.downloadFile(
      url: url,
      fileName: fileName,
      fileType: 'document',
      context: context,
      downloadedFiles: downloadedFiles,
      updateDownloadedFiles: updateDownloadedFiles,
    );
  }
}

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorMessage;
  final bool isUploading;
  final bool isRecording;
  final bool isRecorderReady;
  final int recordDuration;
  final VoidCallback onSendMessage;
  final VoidCallback onPickMedia;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onSendSelfDestructMessage;
  final bool isSelfDestructEnabled;
  final VoidCallback onOpenSelfDestructDialog;

  const ChatInputField({
    Key? key,
    required this.controller,
    this.errorMessage,
    required this.isUploading,
    required this.isRecording,
    required this.isRecorderReady,
    required this.recordDuration,
    required this.onSendMessage,
    required this.onPickMedia,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onSendSelfDestructMessage,
    required this.isSelfDestructEnabled,
    required this.onOpenSelfDestructDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isUploading)
              Container(
                padding: EdgeInsets.all(8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('Uploading...', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
            if (isRecording)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mic, color: Colors.teal, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recording... ${recordDuration}s',
                        style: const TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: onStopRecording,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.attach_file,
                    color: isUploading ? Colors.grey : Colors.teal,
                    size: 28,
                  ),
                  onPressed: isUploading ? null : onPickMedia,
                ),
                IconButton(
                  icon: Icon(
                    Icons.mic,
                    color: isRecording ? Colors.teal : (isRecorderReady ? Colors.teal : Colors.grey),
                    size: 28,
                  ),
                  onPressed: isRecorderReady ? (isRecording ? null : onStartRecording) : null,
                ),
                IconButton(
                  icon: Icon(Icons.timer, color: isSelfDestructEnabled ? Colors.redAccent : Colors.grey, size: 24),
                  onPressed: isSelfDestructEnabled ? onOpenSelfDestructDialog : null,
                  tooltip: 'Send Self-Destruct Message',
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.teal.withAlpha(77)),
                    ),
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(100),
                  onTap: onSendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withAlpha(41),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ImageDialog extends StatelessWidget {
  final String imageUrl;
  final String? fileName;
  final BuildContext parentContext;

  const ImageDialog({
    Key? key,
    required this.imageUrl,
    this.fileName,
    required this.parentContext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          InteractiveViewer(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.broken_image, size: 80, color: Colors.red),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: Icon(Icons.download, color: Colors.white, size: 30),
              onPressed: () async {
                Navigator.of(context).pop();
                await ChatFeatures.downloadFile(
                  url: imageUrl,
                  fileName: fileName ?? 'whisp_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
                  fileType: 'image',
                  context: parentContext,
                  downloadedFiles: {},
                  updateDownloadedFiles: (_, __) {},
                );
              },
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerDialog({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play();
      }
    }).catchError((error) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: _hasError
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 40),
                SizedBox(height: 10),
                Text('Failed to load video', style: TextStyle(color: Colors.red)),
              ],
            )
                : _isInitialized
                ? AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
                : CircularProgressIndicator(color: Colors.teal),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class MediaPickerBottomSheet extends StatelessWidget {
  final VoidCallback onPickPhoto;
  final VoidCallback onPickDocument;

  const MediaPickerBottomSheet({
    Key? key,
    required this.onPickPhoto,
    required this.onPickDocument,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
        ),
        padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select file type', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PickerOption(
                  icon: Icons.photo,
                  label: 'Picture/Video',
                  subtitle: 'Gallery, Camera',
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    onPickPhoto();
                  },
                ),
                _PickerOption(
                  icon: Icons.description,
                  label: 'Document',
                  subtitle: 'PDF, Word, etc.',
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.pop(context);
                    onPickDocument();
                  },
                ),
              ],
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _PickerOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 120,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12, color: color.withAlpha(179))),
          ],
        ),
      ),
    );
  }
}

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onMorePressed;
  final List<Widget>? additionalActions;

  const ChatAppBar({
    Key? key,
    required this.title,
    this.subtitle,
    this.onMorePressed,
    this.additionalActions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 19,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(color: Colors.green, fontSize: 13),
            ),
          ],
        ],
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      actions: [
        if (additionalActions != null) ...additionalActions!,
        // Only show the 3 dots if onMorePressed is provided (for screens that want it)
        if (onMorePressed != null)
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onPressed: onMorePressed,
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
