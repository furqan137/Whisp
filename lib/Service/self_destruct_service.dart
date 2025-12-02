import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// import your Cloudinary delete helper here

class SelfDestructService {
  static final _firestore = FirebaseFirestore.instance;

  /// Call this to start listening for self-destruct messages in a chat or group
  static void listenForSelfDestructMessages(String chatCollectionPath) {
    _firestore.collection(chatCollectionPath)
      .where('selfDestruct', isEqualTo: true)
      .snapshots()
      .listen((snapshot) {
        final now = DateTime.now();
        for (var doc in snapshot.docs) {
          final createdAt = (doc['createdAt'] as Timestamp).toDate();
          final destroyAfter = doc['destroyAfter'] as int;
          final expiresAt = createdAt.add(Duration(seconds: destroyAfter));
          if (now.isAfter(expiresAt)) {
            _deleteMessage(doc.reference, doc.data());
          } else {
            // Schedule deletion
            Future.delayed(expiresAt.difference(now), () {
              _deleteMessage(doc.reference, doc.data());
            });
          }
        }
      });
  }

  static Future<void> _deleteMessage(DocumentReference ref, Map<String, dynamic> data) async {
    try {
      await ref.delete();
      if (data['mediaType'] != null && data['decryptedUrl'] != null) {
        await _deleteCloudinaryFile(data['decryptedUrl']);
      }
    } catch (e) {
      debugPrint('Failed to delete self-destruct message: $e');
    }
  }

  static Future<void> _deleteCloudinaryFile(String url) async {
    // Implement Cloudinary deletion logic here
    // Example: await CloudinaryService.deleteFile(url);
  }
}
