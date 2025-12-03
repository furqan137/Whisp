import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// import your Cloudinary delete helper here

class SelfDestructService {
  static final _firestore = FirebaseFirestore.instance;

  // Track active subscriptions and timers per chat path / message id
  static final Map<String, StreamSubscription<QuerySnapshot>> _subscriptions = {};
  static final Map<String, Timer> _messageTimers = {};
  static final Map<String, Timer> _safetyTimers = {};

  /// Call this to start listening for self-destruct messages in a chat or group
  /// This will:
  ///  - listen to live updates for messages in [chatCollectionPath]
  ///  - set per-message timers to delete when the message's expiry is reached
  ///  - run a short periodic (1-2s) safety check to catch missed expirations
  /// Returns immediately; call [stopListening] with same path to cancel.
  static void listenForSelfDestructMessages(String chatCollectionPath) {
    if (_subscriptions.containsKey(chatCollectionPath)) return; // already listening

    final subscription = _firestore
        .collection(chatCollectionPath)
        // listen to all changes; we'll filter messages that have selfDestruct enabled
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();

      // Cancel timers for removed docs
      for (final change in snapshot.docChanges) {
        final doc = change.doc;
        final key = _messageKey(chatCollectionPath, doc.id);

        if (change.type == DocumentChangeType.removed) {
          // message was deleted (maybe by self-destruct); cancel any timer
          _cancelMessageTimer(key);
          continue;
        }

        final data = doc.data();
        if (data == null) {
          _cancelMessageTimer(key);
          continue;
        }

        final selfDestructEnabled = data['selfDestruct'] == true;
        if (!selfDestructEnabled) {
          // If previously had a timer, cancel it
          _cancelMessageTimer(key);
          continue;
        }

        // Compute expiresAt: prefer explicit 'selfDestructAt' timestamp if available,
        // otherwise compute from createdAt + destroyAfter (seconds).
        DateTime? expiresAt;
        try {
          if (data.containsKey('selfDestructAt') && data['selfDestructAt'] != null) {
            final ts = data['selfDestructAt'];
            if (ts is Timestamp) expiresAt = ts.toDate();
          } else if (data.containsKey('createdAt') && data['createdAt'] != null) {
            final created = data['createdAt'];
            final destroyAfter = (data['destroyAfter'] is int) ? data['destroyAfter'] as int : int.tryParse('${data['destroyAfter']}') ?? 0;
            if (created is Timestamp) {
              expiresAt = created.toDate().add(Duration(seconds: destroyAfter));
            }
          }
        } catch (e) {
          debugPrint('Error computing expiresAt for ${doc.id}: $e');
        }

        if (expiresAt == null) {
          // Nothing to schedule
          continue;
        }

        final keyTimer = _messageKey(chatCollectionPath, doc.id);
        // If already have a timer, skip scheduling a new one
        if (_messageTimers.containsKey(keyTimer)) continue;

        // If already expired, delete immediately
        if (now.isAfter(expiresAt) || now.isAtSameMomentAs(expiresAt)) {
          _deleteMessage(doc.reference, data);
          continue;
        }

        // Schedule deletion at the exact expiry time
        final duration = expiresAt.difference(now);
        try {
          final timer = Timer(duration, () async {
            await _deleteMessage(doc.reference, data);
            _messageTimers.remove(keyTimer);
          });
          _messageTimers[keyTimer] = timer;
        } catch (e) {
          debugPrint('Failed to schedule self-destruct timer for ${doc.id}: $e');
          // As fallback, attempt immediate delete if something went wrong
          if (DateTime.now().isAfter(expiresAt)) {
            _deleteMessage(doc.reference, data);
          }
        }
      }
    }, onError: (err) {
      debugPrint('SelfDestruct listener error for $chatCollectionPath: $err');
    });

    _subscriptions[chatCollectionPath] = subscription;

    // Start a short periodic safety check (2 seconds) to catch any missed expirations.
    // We keep one safety timer per chatCollectionPath.
    _safetyTimers[chatCollectionPath] = Timer.periodic(Duration(seconds: 2), (_) async {
      try {
        final now = DateTime.now();
        final querySnapshot = await _firestore
            .collection(chatCollectionPath)
            .where('selfDestruct', isEqualTo: true)
            .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          DateTime? expiresAt;
          if (data.containsKey('selfDestructAt') && data['selfDestructAt'] != null) {
            final ts = data['selfDestructAt'];
            if (ts is Timestamp) expiresAt = ts.toDate();
          } else if (data.containsKey('createdAt') && data['createdAt'] != null) {
            final created = data['createdAt'];
            final destroyAfter = (data['destroyAfter'] is int) ? data['destroyAfter'] as int : int.tryParse('${data['destroyAfter']}') ?? 0;
            if (created is Timestamp) {
              expiresAt = created.toDate().add(Duration(seconds: destroyAfter));
            }
          }

          if (expiresAt != null && now.isAfter(expiresAt)) {
            final key = _messageKey(chatCollectionPath, doc.id);
            // Cancel any existing timer for this message and ensure deletion
            _cancelMessageTimer(key);
            await _deleteMessage(doc.reference, data);
          }
        }
      } catch (e) {
        debugPrint('Safety check failed for $chatCollectionPath: $e');
      }
    });
  }

  /// Stop listening and cancel timers for a chat collection path
  static Future<void> stopListening(String chatCollectionPath) async {
    if (_subscriptions.containsKey(chatCollectionPath)) {
      await _subscriptions[chatCollectionPath]?.cancel();
      _subscriptions.remove(chatCollectionPath);
    }

    // Cancel all message timers for this chat path
    final keysToCancel = _messageTimers.keys.where((k) => k.startsWith('$chatCollectionPath|')).toList();
    for (final k in keysToCancel) _cancelMessageTimer(k);

    // Cancel safety timer
    if (_safetyTimers.containsKey(chatCollectionPath)) {
      _safetyTimers[chatCollectionPath]?.cancel();
      _safetyTimers.remove(chatCollectionPath);
    }
  }

  static String _messageKey(String path, String docId) => '$path|$docId';

  static void _cancelMessageTimer(String key) {
    final t = _messageTimers[key];
    if (t != null && t.isActive) t.cancel();
    _messageTimers.remove(key);
  }

  static Future<void> _deleteMessage(DocumentReference ref, Map<String, dynamic> data) async {
    try {
      // Double-check the document still exists before attempting delete
      final snapshot = await ref.get();
      if (!snapshot.exists) return;

      await ref.delete();

      // If message had media stored on Cloudinary (or similar) delete it too
      // We expect the message to have fields like 'mediaType' and 'decryptedUrl' (or 'mediaUrl')
      final mediaUrl = (data['decryptedUrl'] ?? data['mediaUrl']) as String?;
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        await _deleteCloudinaryFile(mediaUrl);
      }
    } catch (e) {
      debugPrint('Failed to delete self-destruct message: $e');
    }
  }

  static Future<void> _deleteCloudinaryFile(String url) async {
    // Implement Cloudinary deletion logic here
    // Example: await CloudinaryService.deleteFile(url);
    // NOTE: keep this implementation minimal here; call your project's Cloudinary helper.
  }
}
