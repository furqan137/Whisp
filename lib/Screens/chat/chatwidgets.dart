import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../theme/theme_provider.dart';
import '../../Service/chatfeature.dart';
import '../../Service/chatutils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMine;
  final String currentUserId;

  final Map<String, String> downloadedFiles;
  final void Function(String, String) updateDownloadedFiles;

  final void Function(String) showImageDialog;
  final void Function(String) showVideoDialog;

  final void Function(String) playAudio;
  final bool isPlaying;
  final String? currentAudioUrl;

  final VoidCallback? onLongPress;
  final void Function(String url, String fileName, String type) downloadFile;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUserId,
    required this.downloadedFiles,
    required this.updateDownloadedFiles,
    required this.showImageDialog,
    required this.showVideoDialog,
    required this.playAudio,
    required this.isPlaying,
    required this.currentAudioUrl,
    required this.downloadFile,
    this.onLongPress,
  });

  // -------------------------------------------------------------
  // SELF-DESTRUCT TIMER CALCULATOR
  // -------------------------------------------------------------
  String _remainingTimeText(Map<String, dynamic> msg) {
    if (msg['selfDestruct'] != true ||
        msg['createdAt'] == null ||
        msg['destroyAfter'] == null) {
      return "";
    }

    final createdAt = (msg['createdAt'] as Timestamp).toDate();
    final destroyAfter = msg['destroyAfter'] as int;
    final expiry = createdAt.add(Duration(seconds: destroyAfter));
    final now = DateTime.now();

    final remaining = expiry.difference(now).inSeconds;

    if (remaining <= 0) return "🔥 Expired";

    if (remaining < 60) return "⏳ ${remaining}s remaining";
    return "⏳ ${(remaining / 60).ceil()} min";
  }

  // -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;

    final mediaType = message['mediaType'];
    final fileName = message['fileName'];
    final decryptedContent =
    mediaType == null ? message['message'] : message['decryptedUrl'];

    final bubbleBg = isMine ? null : themeProv.othersBubbleBackground(isDark);

    final myGradient = themeProv.chatGradient;
    final myTextColor = themeProv.myBubbleTextColor;
    final accent = themeProv.accentColor;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Row(
        mainAxisAlignment:
        isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Container(
              margin: EdgeInsets.only(
                bottom: 8,
                left: isMine ? 50 : 8,
                right: isMine ? 8 : 50,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isMine ? myGradient : null,
                color: bubbleBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                  isMine ? const Radius.circular(18) : Radius.zero,
                  bottomRight:
                  isMine ? Radius.zero : const Radius.circular(18),
                ),
                boxShadow: [
                  if (isMine)
                    BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContent(
                    context,
                    mediaType,
                    decryptedContent,
                    fileName,
                    isMine,
                    myTextColor,
                    accent,
                    themeProv,
                  ),

                  const SizedBox(height: 6),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        ChatUtils.formatTime(message['timestamp'] as Timestamp?),
                        style: TextStyle(
                          color: isMine ? Colors.white70 : Colors.grey.shade700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),


                  if (message['selfDestruct'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _remainingTimeText(message),
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

  }

  // -------------------------------------------------------------
  // MESSAGE BUILDER
  // -------------------------------------------------------------
  Widget _buildContent(
      BuildContext context,
      String? type,
      String? content,
      String? fileName,
      bool isMine,
      Color myTextColor,
      Color accent,
      ThemeProvider themeProv,
      ) {
    if (content == null) {
      return const Text(
        "[Unable to decrypt]",
        style: TextStyle(color: Colors.redAccent),
      );
    }

    switch (type) {
      case "image":
        return _image(content, fileName, themeProv.accentColor);

      case "video":
        return _video(content, fileName, themeProv.accentColor);

      case "audio":
        return _audio(content, isMine, myTextColor);

      case "document":
      case "pdf":
        return _document(context, content, fileName, isMine, themeProv);

      default:
        return _text(content, isMine, myTextColor, themeProv.isDarkMode);
    }
  }

  // -------------------------------------------------------------
  // TEXT MESSAGE
  // -------------------------------------------------------------
  Widget _text(String text, bool isMine, Color myTextColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            color: isMine
                ? myTextColor
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // IMAGE MESSAGE
  // -------------------------------------------------------------
  Widget _image(String url, String? file, Color accent) {
    return GestureDetector(
      onTap: () => showImageDialog(url),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(url, height: 220, fit: BoxFit.cover),
          ),

          // DOWNLOAD BUTTON
          Positioned(
            bottom: 8,
            right: 8,
            child: _downloadButton(
                  () => downloadFile(
                url,
                file ?? "image_${DateTime.now().millisecondsSinceEpoch}.jpg",
                "image",
              ),
              accent,
            ),
          ),

          // SELF-DESTRUCT TIMER BADGE ON IMAGE
          if (message['selfDestruct'] == true)
            Positioned(
              top: 8,
              left: 8,
              child: _timerBadge(),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // VIDEO MESSAGE
  // -------------------------------------------------------------
  Widget _video(String url, String? file, Color accent) {
    return GestureDetector(
      onTap: () => showVideoDialog(url),
      child: Stack(
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.black26,
            ),
            child: const Center(
              child: Icon(Icons.play_circle_fill,
                  size: 60, color: Colors.white),
            ),
          ),

          Positioned(
            bottom: 8,
            right: 8,
            child: _downloadButton(
                  () => downloadFile(
                url,
                file ?? "video_${DateTime.now().millisecondsSinceEpoch}.mp4",
                "video",
              ),
              accent,
            ),
          ),

          if (message['selfDestruct'] == true)
            Positioned(
              top: 8,
              left: 8,
              child: _timerBadge(),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // AUDIO MESSAGE
  // -------------------------------------------------------------
  Widget _audio(String url, bool isMine, Color myTextColor) {
    final isCurrent = isPlaying && currentAudioUrl == url;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            isCurrent ? Icons.pause : Icons.play_arrow,
            color: isMine ? myTextColor : Colors.black87,
            size: 28,
          ),
          onPressed: () => playAudio(url),
        ),
        Text(
          "Voice message",
          style: TextStyle(
            color: isMine ? myTextColor : Colors.black87,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // DOCUMENT MESSAGE
  // -------------------------------------------------------------
  Widget _document(BuildContext context, String url, String? file,
      bool isMine, ThemeProvider themeProv) {
    final fName = file ?? "Document";

    return GestureDetector(
      onTap: () => downloadFile(url, fName, "document"),
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isMine ? Colors.white12 : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file,
              color: isMine ? Colors.white : themeProv.accentColor,
              size: 32,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                fName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMine ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TIMER BADGE FOR MEDIA
  // -------------------------------------------------------------
  Widget _timerBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _remainingTimeText(message),
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }

  // -------------------------------------------------------------
  // DOWNLOAD BUTTON
  // -------------------------------------------------------------
  Widget _downloadButton(VoidCallback action, Color accent) {
    return GestureDetector(
      onTap: action,
      child: Container(
        padding: EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.download, color: accent, size: 22),
      ),
    );
  }
}

// ###########################################################
// #                    CHAT INPUT FIELD (UPDATED)
// ###########################################################

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

  // NEW
  final bool iBlockedHim;
  final bool heBlockedMe;

  const ChatInputField({
    super.key,
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

    this.iBlockedHim = false,
    this.heBlockedMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;

    // You blocked them
    if (iBlockedHim) {
      return _blockedBar("You blocked this user.", isDark);
    }

    // They blocked you
    if (heBlockedMe) {
      return _blockedBar("This user has blocked you.", isDark);
    }

    // Normal input bar
    return _inputBar(context, themeProv, isDark);
  }

  // -------------------------------
  // BLOCKED MESSAGE UI
  // -------------------------------
  Widget _blockedBar(String text, bool isDark) {
    return Container(
      padding: EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        border: Border(top: BorderSide(color: Colors.grey.shade400)),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // -------------------------------
  // MAIN INPUT BAR
  // -------------------------------
  Widget _inputBar(
      BuildContext context, ThemeProvider themeProv, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF0C1220) : Colors.white,
        border: Border(
            top: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (errorMessage != null)
              Text(errorMessage!,
                  style: TextStyle(color: Colors.redAccent)),

            if (isUploading)
              Row(
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 8),
                  Text("Uploading...",
                      style: TextStyle(color: Colors.grey)),
                ],
              ),

            if (isRecording) _recordingBar(themeProv),

            Row(
              children: [
                // MEDIA PICKER
                IconButton(
                  onPressed: onPickMedia,
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),

                // MIC BUTTON
                IconButton(
                  onPressed: isRecorderReady
                      ? (isRecording ? null : onStartRecording)
                      : null,
                  icon: Icon(
                    Icons.mic,
                    color: isRecording
                        ? Colors.redAccent
                        : isRecorderReady
                        ? (isDark ? Colors.white : Colors.black87)
                        : Colors.grey,
                  ),
                ),

                // SELF-DESTRUCT TIMER BUTTON
                IconButton(
                  onPressed: isSelfDestructEnabled
                      ? onOpenSelfDestructDialog
                      : null,
                  icon: Icon(
                    Icons.timer,
                    color: isSelfDestructEnabled
                        ? Colors.redAccent
                        : Colors.grey,
                  ),
                ),

                // TEXT FIELD
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Message...",
                        hintStyle: TextStyle(
                          color:
                          isDark ? Colors.white54 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 8),

                // SEND BUTTON
                GestureDetector(
                  onTap: onSendMessage,
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: themeProv.chatGradient,
                      boxShadow: [
                        BoxShadow(
                          color:
                          themeProv.accentColor.withOpacity(0.5),
                          blurRadius: 12,
                        )
                      ],
                    ),
                    child: Icon(Icons.send,
                        size: 22, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------
  // RECORDING UI, RED BAR
  // -------------------------------
  Widget _recordingBar(ThemeProvider themeProv) {
    return Container(
      padding: EdgeInsets.all(10),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.mic, color: Colors.redAccent),
          SizedBox(width: 8),
          Text(
            "Recording... $recordDuration s",
            style:
            TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          Spacer(),
          GestureDetector(
            onTap: onStopRecording,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: themeProv.accentColor,
              child: Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}


// ###########################################################
//                    IMAGE VIEWER
// ###########################################################

class ImageDialog extends StatelessWidget {
  final String imageUrl;
  final String? fileName;
  final BuildContext parentContext;

  const ImageDialog({
    super.key,
    required this.imageUrl,
    this.fileName,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          InteractiveViewer(
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),

          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: Icon(Icons.download, color: Colors.white),
              onPressed: () async {
                Navigator.pop(context);
                await ChatFeatures.downloadFile(
                  url: imageUrl,
                  fileName: fileName ??
                      "image_${DateTime.now().millisecondsSinceEpoch}.jpg",
                  fileType: "image",
                  context: parentContext,
                  downloadedFiles: {},
                  updateDownloadedFiles: (_, __) {},
                );
              },
            ),
          ),

          Positioned(
            top: 16,
            left: 16,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ###########################################################
//                    VIDEO VIEWER
// ###########################################################

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerDialog({super.key, required this.videoUrl});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool initialized = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();

    _controller =
    VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => initialized = true);
          _controller.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => failed = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);

    return Dialog(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: failed
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 40),
                SizedBox(height: 8),
                Text("Failed to load video",
                    style: TextStyle(color: Colors.red)),
              ],
            )
                : initialized
                ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller))
                : CircularProgressIndicator(color: themeProv.accentColor),
          ),

          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ###########################################################
//                    BOTTOM SHEET PICKER
// ###########################################################

class MediaPickerBottomSheet extends StatelessWidget {
  final VoidCallback onPickPhoto;
  final VoidCallback onPickDocument;

  const MediaPickerBottomSheet({
    super.key,
    required this.onPickPhoto,
    required this.onPickDocument,
  });

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;

    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 26, horizontal: 18),
        decoration: BoxDecoration(
          color: isDark ? Color(0xFF0C1220) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Select file type",
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),

            SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _pickerBox(
                  icon: Icons.photo,
                  title: "Picture/Video",
                  subtitle: "Gallery, Camera",
                  color: themeProv.accentColor,
                  onTap: onPickPhoto,
                ),
                _pickerBox(
                  icon: Icons.description,
                  title: "Document",
                  subtitle: "PDF, Word, etc.",
                  color: themeProv.accentColor,
                  onTap: onPickDocument,
                ),
              ],
            ),

            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _pickerBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 42, color: color),
            SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12, color: color.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
