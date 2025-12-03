import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../Service/encryption.dart';
import 'chatutils.dart';

class ChatFeatures {
  // Cloudinary configuration
  static const String cloudName = 'dt3h287ce';
  static const String apiKey = '625236421988957';
  static const String apiSecret = 'idvCawRC_FF4O9di2i9VSkTCYKI';

  /// Get username from UID
  static Future<String> getUsername(String uid, {String fallback = 'Unknown'}) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return userDoc.exists && userDoc.data()!.containsKey('username')
          ? userDoc['username']
          : fallback;
    } catch (e) {
      print('❌ Error fetching username: $e');
      return fallback;
    }
  }

  /// Send text message
  static Future<void> sendMessage({
    required String text,
    required String peerUid,
    String? peerUsername,
    String? groupId,
    bool isGroup = false,
    Map<String, dynamic>? customFields,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("User not logged in");

    final validationError = ChatUtils.validateMessage(text);
    if (validationError != null) throw Exception(validationError);

    try {
      final senderUsername = await getUsername(currentUser.uid, fallback: 'Unknown');

      String chatId;
      encrypt.Key key;
      String collectionPath;

      if (isGroup) {
        // FIXED: Use groupId directly, no prefix
        print('🟢 SENDING GROUP MESSAGE to groupId: $groupId');
        print('🟢 Sender: $senderUsername');
        print('🟢 Message: $text');

        chatId = groupId!; // Use groupId directly
        key = EncryptionService.getGroupKey(groupId);
        collectionPath = 'groups';

        print('🟢 Collection Path: $collectionPath/$chatId/messages');
      } else {
        chatId = ChatUtils.getChatId(currentUser.uid, peerUid);
        key = EncryptionService.getSharedKey(currentUser.uid, peerUid);
        collectionPath = 'chats';
      }

      final encryptedMessage = EncryptionService.encryptText(text, key);

      final chatRef = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(chatId)
          .collection('messages');

      Map<String, dynamic> messageData = {
        'fromUid': currentUser.uid,
        'fromUsername': senderUsername,
        'message': encryptedMessage,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (!isGroup) {
        messageData.addAll({
          'toUid': peerUid,
          'toUsername': peerUsername ?? await getUsername(peerUid),
        });
      }

      if (customFields != null) {
        messageData.addAll(customFields);
      }

      print('🟢 Adding message to collection: ${chatRef.path}');
      await chatRef.add(messageData);
      print('🟢 Message added successfully!');

      // Send notification for individual chats only
      if (!isGroup) {
        try {
          await http.post(
            Uri.parse('http://192.168.100.5:3000/send-chat-notification'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'toUid': peerUid,
              'title': senderUsername,
              'body': text,
            }),
          ).timeout(Duration(seconds: 5));
        } catch (e) {
          print("⚠️ Failed to send notification: $e");
        }
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      throw Exception("Failed to send message. Please try again.");
    }
  }

  /// Upload file to Cloudinary
  static Future<String?> uploadToCloudinary(File file, String fileType) async {
    try {
      String resourceType = 'auto';
      if (fileType == 'pdf' || fileType == 'document') {
        resourceType = 'raw';
      }
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'ml_default'
        ..fields['folder'] = 'chat_upload';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final response = await request.send().timeout(Duration(seconds: 120));
      final resStr = await response.stream.bytesToString();
      print('🌟 Upload response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final resJson = json.decode(resStr);
        final secureUrl = resJson['secure_url'];
        print('✅ Upload successful: $secureUrl');
        return secureUrl;
      } else {
        print('❌ Upload error: ${response.statusCode} - $resStr');
        return null;
      }
    } catch (e) {
      print('❌ Upload exception: $e');
      return null;
    }
  }

  /// Send media message
  static Future<void> sendMediaMessage({
    required File file,
    required String fileName,
    required String peerUid,
    String? peerUsername,
    String? groupId,
    bool isGroup = false,
    required Function(bool) setUploadingState,
    required Function(String) showSnackBar,
    Map<String, dynamic>? customFields,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Validate file size
    if (!await ChatUtils.validateFileSize(file)) {
      showSnackBar('File too large. Maximum size is 50MB.');
      return;
    }

    try {
      setUploadingState(true);

      final extension = fileName.split('.').last;
      final fileType = ChatUtils.getFileType(extension);

      print('📤 Uploading file: $fileName (Type: $fileType)');

      final downloadUrl = await uploadToCloudinary(file, fileType);

      if (downloadUrl == null) {
        showSnackBar('Failed to upload file. Please try again.');
        return;
      }

      print('🔗 File uploaded to: $downloadUrl');

      String chatId;
      encrypt.Key key;
      String collectionPath;

      if (isGroup) {
        // FIXED: Use groupId directly, no prefix
        print('🟢 SENDING GROUP MEDIA to groupId: $groupId');
        print('🟢 File: $fileName');

        chatId = groupId!; // Use groupId directly
        key = EncryptionService.getGroupKey(groupId);
        collectionPath = 'groups';

        print('🟢 Collection Path: $collectionPath/$chatId/messages');
      } else {
        chatId = ChatUtils.getChatId(currentUser.uid, peerUid);
        key = EncryptionService.getSharedKey(currentUser.uid, peerUid);
        collectionPath = 'chats';
      }

      final encryptedUrl = EncryptionService.encryptText(downloadUrl, key);

      final chatRef = FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(chatId)
          .collection('messages');

      Map<String, dynamic> messageData = {
        'fromUid': currentUser.uid,
        'fromUsername': await getUsername(currentUser.uid),
        'message': encryptedUrl,
        'mediaType': fileType,
        'fileName': fileName,
        'fileExtension': extension,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // In sendMediaMessage, ensure PDF metadata is correct
      if (fileType == 'pdf') {
        messageData['mediaType'] = 'pdf';
        messageData['fileExtension'] = 'pdf';
        if (!fileName.toLowerCase().endsWith('.pdf')) {
          messageData['fileName'] = fileName + '.pdf';
        }
      }

      if (!isGroup) {
        messageData.addAll({
          'toUid': peerUid,
          'toUsername': peerUsername ?? await getUsername(peerUid),
        });
      }

      if (customFields != null) {
        messageData.addAll(customFields);
      }

      print('🟢 Adding media message to collection: ${chatRef.path}');
      await chatRef.add(messageData);
      print('🟢 Media message added successfully!');

      showSnackBar('File uploaded successfully!');
    } catch (e) {
      print('❌ Error sending media: $e');
      showSnackBar('Failed to send file. Please try again.');
    } finally {
      setUploadingState(false);
    }
  }

  /// Download file with multiple strategies
  static Future<void> downloadFile({
    required String url,
    required String fileName,
    required String fileType,
    required BuildContext context,
    required Map<String, String> downloadedFiles,
    required Function(String, String) updateDownloadedFiles,
  }) async {
    bool downloadStarted = false;

    try {
      // Check if already downloaded
      if (downloadedFiles.containsKey(url)) {
        final localPath = downloadedFiles[url]!;
        final file = File(localPath);
        if (await file.exists()) {
          await _openLocalFile(localPath, fileName, context);
          return;
        } else {
          downloadedFiles.remove(url);
        }
      }

      downloadStarted = true;
      _showDownloadProgress(context, fileName);

      // Get downloads directory
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!(await directory.exists())) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getExternalStorageDirectory();
      }

      if (directory == null) {
        throw Exception('Cannot access storage directory');
      }

      // In downloadFile, force .pdf extension for PDFs
      final uniqueFileName = fileType == 'pdf' ? ChatUtils.getUniqueFileName(fileName).replaceAll(RegExp(r'\.[^.]*$'), '.pdf') : ChatUtils.getUniqueFileName(fileName);
      final filePath = '${directory.path}/$uniqueFileName';

      // Try multiple download strategies
      http.Response? response = await _tryMultipleDownloadStrategies(url, fileType);

      if (response == null) {
        throw Exception('All download strategies failed. File may have access restrictions or may have been deleted.');
      }

      print('📡 Final response status: ${response.statusCode}');
      print('📏 Final response length: ${response.bodyBytes.length} bytes');

      // Save file
      if (response.statusCode == 200 || response.statusCode == 206) {
        if (response.bodyBytes.isEmpty) {
          throw Exception('Downloaded file is empty');
        }

        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (!(await file.exists()) || (await file.length()) == 0) {
          throw Exception('Failed to save file to storage');
        }

        // Force media scan so file appears in Recents
        if (Platform.isAndroid) {
          try {
            const channel = MethodChannel('com.whisp.app/media_scan');
            await channel.invokeMethod('scanFile', {'path': filePath});
          } catch (e) {
            print('Media scan failed: $e');
          }
        }

        final fileSizeKB = (await file.length() / 1024).round();
        print('✅ File saved successfully: ${await file.length()} bytes (${fileSizeKB}KB)');

        // Cache the file path
        updateDownloadedFiles(url, filePath);

        // Save to gallery for images and videos
        await _saveToGallery(response.bodyBytes, filePath, fileType, uniqueFileName);

        // Hide downloading SnackBar and show success
        if (downloadStarted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }

        _showDownloadSuccess(context, fileName, filePath, fileType, fileSizeKB);
      } else {
        _handleDownloadError(response.statusCode);
      }
    } catch (e) {
      print('❌ Download error: $e');
      if (downloadStarted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      _showDownloadError(context, e.toString(), url, fileName, fileType);
    }
  }

  static void _showDownloadProgress(BuildContext context, String fileName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Downloading $fileName...',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        duration: Duration(minutes: 3),
      ),
    );
  }

  static Future<http.Response?> _tryMultipleDownloadStrategies(String url, String fileType) async {
    List<String> urlsToTry = [url];

    // Add URL variants for documents
    if (fileType == 'pdf' || fileType == 'document') {
      // Always try /raw/upload/ first if not present
      if (!url.contains('/raw/upload/')) {
        if (url.contains('/image/upload/')) {
          urlsToTry.insert(0, url.replaceFirst('/image/upload/', '/raw/upload/'));
        } else if (url.contains('/auto/upload/')) {
          urlsToTry.insert(0, url.replaceFirst('/auto/upload/', '/raw/upload/'));
        }
      }
      // Add other variants as fallback
      if (url.contains('/image/upload/')) {
        urlsToTry.add(url.replaceAll('/image/upload/', '/image/upload/fl_attachment/'));
        urlsToTry.add(url.replaceAll('/image/upload/', '/raw/upload/fl_attachment/'));
        urlsToTry.add(url.replaceAll('/image/upload/', '/auto/upload/'));
      }
      urlsToTry = urlsToTry.toSet().toList();
    }

    // Strategy 1: Standard download
    for (String downloadUrl in urlsToTry) {
      try {
        final response = await http.get(
          Uri.parse(downloadUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Android 13; Mobile; rv:109.0) Gecko/117.0 Firefox/117.0',
            'Accept': fileType == 'pdf' ? 'application/pdf' : '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
          },
        ).timeout(Duration(seconds: 120));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response;
        }
      } catch (e) {
        print('❌ Standard download failed for $downloadUrl: $e');
      }
    }

    // Strategy 2: Range request
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Android Download Manager/1.0',
          'Accept': 'application/octet-stream, */*',
          'Accept-Encoding': 'identity',
          'Range': 'bytes=0-',
          'Connection': 'keep-alive',
        },
      ).timeout(Duration(seconds: 120));

      if ((response.statusCode == 200 || response.statusCode == 206) &&
          response.bodyBytes.isNotEmpty) {
        return response;
      }
    } catch (e) {
      print('❌ Range request failed: $e');
    }

    return null;
  }

  static Future<void> _saveToGallery(Uint8List bytes, String filePath, String fileType, String fileName) async {
    try {
      if (fileType == 'image') {
        await SaverGallery.saveImage(bytes, fileName: fileName, skipIfExists: false);
        print('📸 Image saved to gallery');
      } else if (fileType == 'video') {
        await SaverGallery.saveFile(filePath: filePath, fileName: fileName, skipIfExists: false);
        print('🎥 Video saved to gallery');
      }
    } catch (e) {
      print('⚠️ Gallery save failed: $e');
    }
  }

  static void _showDownloadSuccess(BuildContext context, String fileName, String filePath, String fileType, int fileSizeKB) {
    String successMessage;
    if (fileType == 'image' || fileType == 'video') {
      successMessage = '${fileType == 'image' ? 'Image' : 'Video'} saved to gallery and downloads';
    } else {
      successMessage = '$fileName downloaded (${fileSizeKB}KB)';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Open',
          textColor: Colors.white,
          onPressed: () => _openLocalFile(filePath, fileName, context),
        ),
      ),
    );
  }

  static void _handleDownloadError(int statusCode) {
    switch (statusCode) {
      case 401:
        throw Exception('File access denied (401). Please ask sender to resend the file.');
      case 403:
        throw Exception('Access forbidden (403). File may have access restrictions.');
      case 404:
        throw Exception('File not found (404). It may have been deleted.');
      case 429:
        throw Exception('Too many requests (429). Please try again in a few minutes.');
      default:
        throw Exception('Server error ($statusCode). Please try again.');
    }
  }

  static void _showDownloadError(BuildContext context, String errorMessage, String url, String fileName, String fileType) {
    String displayMessage;
    String retryLabel = 'Retry';

    if (errorMessage.contains('401') || errorMessage.contains('403') ||
        errorMessage.contains('404') || errorMessage.contains('429') ||
        errorMessage.contains('All download strategies failed')) {
      retryLabel = 'OK';
    }

    if (errorMessage.contains('401')) {
      displayMessage = 'File access expired or unauthorized. Ask sender to resend the file.';
    } else if (errorMessage.contains('403')) {
      displayMessage = 'File access restricted. Contact sender.';
    } else if (errorMessage.contains('404')) {
      displayMessage = 'File not found. It may have been deleted.';
    } else if (errorMessage.contains('timeout')) {
      displayMessage = 'Download timed out. Check your internet connection.';
    } else {
      displayMessage = 'Download failed. Please try again.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayMessage),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 8),
        action: SnackBarAction(
          label: retryLabel,
          textColor: Colors.white,
          onPressed: () {
            if (retryLabel == 'Retry') {
              // Retry download
              downloadFile(
                url: url,
                fileName: fileName,
                fileType: fileType,
                context: context,
                downloadedFiles: {},
                updateDownloadedFiles: (_, __) {},
              );
            }
          },
        ),
      ),
    );

    // Show additional dialog with more options
    Future.delayed(Duration(milliseconds: 300), () {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Download failed'),
            content: Text('$displayMessage\n\nWould you like to open the file in a browser or copy the link?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Open in browser
                  try {
                    launchUrl(Uri.parse(url));
                  } catch (e) {
                    print('⚠️ Could not launch URL: $e');
                  }
                },
                child: Text('Open in browser'),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Link copied to clipboard')),
                  );
                },
                child: Text('Copy link'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close'),
              ),
            ],
          ),
        );
      }
    });
  }

  static Future<void> _openLocalFile(String filePath, String fileName, BuildContext context) async {
    try {
      final file = File(filePath);
      if (!(await file.exists()) || (await file.length()) == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded file is empty or corrupted.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      final result = await OpenFile.open(filePath);
      if (result.type == ResultType.done) {
        print('✅ File opened successfully');
        return;
      } else if (result.type == ResultType.noAppToOpen) {
        if (fileName.toLowerCase().endsWith('.pdf')) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('No PDF app found'),
              content: Text('No app found to open this PDF file. Please install a PDF viewer from the app store, or open in browser.'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    try {
                      launchUrl(Uri.file(filePath));
                    } catch (e) {
                      print('⚠️ Could not launch file: $e');
                    }
                  },
                  child: Text('Open in browser'),
                ),
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: filePath));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('File path copied to clipboard')),
                    );
                  },
                  child: Text('Copy path'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                )
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No app found to open this file type'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (result.type == ResultType.fileNotFound) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File not found. Please download again.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Open file error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Audio recording methods
  static Future<void> initAudioRecorder(FlutterSoundRecorder recorder) async {
    try {
      await Permission.microphone.request();
      await recorder.openRecorder();
    } catch (e) {
      print('❌ Error initializing recorder: $e');
      throw e;
    }
  }

  static Future<String?> startRecording(FlutterSoundRecorder recorder) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.aac';
      await recorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);
      return filePath;
    } catch (e) {
      print('❌ Error starting recording: $e');
      throw e;
    }
  }

  static Future<String?> stopRecording(FlutterSoundRecorder recorder) async {
    try {
      final path = await recorder.stopRecorder();
      return path;
    } catch (e) {
      print('❌ Error stopping recording: $e');
      throw e;
    }
  }

  static Future<void> playAudio(FlutterSoundPlayer player, String url, Function onFinished) async {
    try {
      await player.startPlayer(
        fromURI: url,
        whenFinished: () => onFinished(),
      );
    } catch (e) {
      print('❌ Error playing audio: $e');
      throw e;
    }
  }

  static Future<void> stopAudio(FlutterSoundPlayer player) async {
    try {
      await player.stopPlayer();
    } catch (e) {
      print('❌ Error stopping audio: $e');
      throw e;
    }
  }

  /// File picker methods
  static Future<File?> pickMediaFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          return File(file.path!);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error picking media: $e');
      throw e;
    }
  }

  static Future<File?> pickDocumentFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['doc', 'docx'], // Only Word documents
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          return File(file.path!);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error picking document: $e');
      throw e;
    }
  }

  /// Request storage permission
  static Future<void> requestStoragePermission() async {
    if (Platform.isAndroid) {
      await [
        Permission.storage,
        Permission.manageExternalStorage,
      ].request();
    }
  }

  /// Delete file from Cloudinary (supports all media types)
  static Future<void> deleteFromCloudinary(String fileUrl, String mediaType) async {
    try {
      // Extract public_id from the Cloudinary URL (handle folders and ignore version)
      // Example: https://res.cloudinary.com/<cloudName>/image/upload/v1234567890/chat_upload/abc123.jpg
      // public_id should be: chat_upload/abc123
      final uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;
      // Find the index of 'upload' and get everything after it except the extension
      final uploadIdx = segments.indexOf('upload');
      if (uploadIdx == -1 || segments.length <= uploadIdx + 1) throw Exception('Invalid Cloudinary URL');
      final publicIdSegments = segments.sublist(uploadIdx + 1);
      // Remove version if present (starts with 'v' and is all digits)
      if (publicIdSegments.isNotEmpty && publicIdSegments[0].startsWith('v') && int.tryParse(publicIdSegments[0].substring(1)) != null) {
        publicIdSegments.removeAt(0);
      }
      // Remove extension from last segment
      if (publicIdSegments.isNotEmpty) {
        publicIdSegments[publicIdSegments.length - 1] = publicIdSegments.last.split('.').first;
      }
      final publicId = publicIdSegments.join('/');
      if (publicId.isEmpty) throw Exception('Invalid Cloudinary public_id');

      // Detect resourceType from fileUrl
      String resourceType;
      if (fileUrl.contains('/video/upload/')) {
        resourceType = 'video';
      } else if (fileUrl.contains('/image/upload/')) {
        resourceType = 'image';
      } else if (fileUrl.contains('/raw/upload/')) {
        resourceType = 'raw';
      } else if (fileUrl.contains('/auto/upload/')) {
        // Fallback: use mediaType or default to raw
        switch (mediaType) {
          case 'image':
            resourceType = 'image';
            break;
          case 'video':
            resourceType = 'video';
            break;
          case 'pdf':
          case 'document':
            resourceType = 'raw';
            break;
          default:
            resourceType = 'raw';
        }
      } else {
        // Fallback: use mediaType or default to raw
        switch (mediaType) {
          case 'image':
            resourceType = 'image';
            break;
          case 'video':
            resourceType = 'video';
            break;
          case 'pdf':
          case 'document':
            resourceType = 'raw';
            break;
          default:
            resourceType = 'raw';
        }
      }
      // After resourceType is set, define apiUrl
      final apiUrl = 'https://api.cloudinary.com/v1_1/$cloudName/resources/$resourceType/upload';
      print('Cloudinary delete debug:');
      print('  fileUrl: $fileUrl');
      print('  mediaType: $mediaType');
      print('  resourceType: $resourceType');
      print('  publicId: $publicId');
      print('  apiUrl: $apiUrl');
      final response = await http.delete(
        Uri.parse('$apiUrl?public_ids[]=$publicId&invalidate=true'),
        headers: {
          'Authorization': 'Basic ' + base64Encode(utf8.encode('$apiKey:$apiSecret')),
        },
      );
      if (response.statusCode == 200) {
        print('✅ Cloudinary file deleted: $publicId');
      } else {
        print('❌ Failed to delete Cloudinary file: ${response.body}');
      }
    } catch (e) {
      print('❌ Error deleting from Cloudinary: $e');
    }
  }
}
