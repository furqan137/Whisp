import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatUtils {
  /// Format timestamp to HH:MM format
  static String formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Generate chat ID from two user IDs
  static String getChatId(String uid1, String uid2) {
    final uids = [uid1, uid2]..sort();
    return '${uids[0]}_${uids[1]}';
  }

  /// Generate group chat ID
  static String getGroupChatId(String groupId) {
    return 'group_$groupId';
  }

  /// Get file type from extension
  static String getFileType(String? extension) {
    if (extension == null) return 'file';

    final ext = extension.toLowerCase();
    if (["jpg", "jpeg", "png", "gif", "bmp", "webp"].contains(ext)) {
      return 'image';
    } else if (["mp4", "mov", "avi", "wmv", "flv", "mkv", "webm"].contains(ext)) {
      return 'video';
    } else if (["pdf"].contains(ext)) {
      return 'pdf';
    } else if (["doc", "docx"].contains(ext)) {
      return 'document';
    } else if (["mp3", "wav", "aac", "m4a"].contains(ext)) {
      return 'audio';
    }
    return 'file';
  }

  /// Get file icon based on file type - using const IconData to prevent tree-shaking issues
  static IconData getFileIcon(String fileType, String? fileName) {
    switch (fileType) {
      case 'pdf':
        return const IconData(0xe415, fontFamily: 'MaterialIcons'); // Icons.picture_as_pdf
      case 'document':
        return const IconData(0xe873, fontFamily: 'MaterialIcons'); // Icons.description
      case 'image':
        return const IconData(0xe3f4, fontFamily: 'MaterialIcons'); // Icons.image
      case 'video':
        return const IconData(0xe04b, fontFamily: 'MaterialIcons'); // Icons.videocam
      case 'audio':
        return const IconData(0xe3b8, fontFamily: 'MaterialIcons'); // Icons.audiotrack
      default:
        return const IconData(0xe24d, fontFamily: 'MaterialIcons'); // Icons.insert_drive_file
    }
  }

  /// Check if file size is within limits (50MB)
  static Future<bool> validateFileSize(File file, {int maxSizeMB = 50}) async {
    final fileSize = await file.length();
    return fileSize <= maxSizeMB * 1024 * 1024;
  }

  /// Get unique filename with timestamp
  static String getUniqueFileName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = originalName.split('.').last.toLowerCase();
    final baseName = originalName.replaceAll('.${extension}', '');
    return '${baseName}_${timestamp}.${extension}';
  }

  /// Validate message content
  static String? validateMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return "Message cannot be empty";
    }
    return null;
  }
}