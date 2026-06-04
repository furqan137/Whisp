// lib/Service/self_destruct_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class SelfDestructService {
  static final _firestore = FirebaseFirestore.instance;

  // Map of listeners
  static final Map<String, StreamSubscription> _listeners = {};

  // Timers per message
  static final Map<String, Timer> _messageTimers = {};

  // Safety timers per chat path
  static final Map<String, Timer> _safetyTimers = {};

  // -------------------------------------------------------------
  //  NEW API
  // -------------------------------------------------------------

  static void startListener(String chatId, {bool isGroup = false}) {
    final path = isGroup
        ? "groups/$chatId/messages"
        : "chats/$chatId/messages";

    if (_listeners.containsKey(path)) return;

    final listener = _firestore
        .collection(path)
        .where("selfDestruct", isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();

      for (final change in snapshot.docChanges) {
        final doc = change.doc;
        final data = doc.data() ?? {};
        final docKey = "$path|${doc.id}";

        // Cancel timer on deletion
        if (change.type == DocumentChangeType.removed) {
          _cancelTimer(docKey);
          continue;
        }

        // Not self-destruct anymore
        if (data["selfDestruct"] != true) {
          _cancelTimer(docKey);
          continue;
        }

        DateTime? createdAt;
        int? destroyAfter;

        try {
          final ts = data["createdAt"];
          final d = data["destroyAfter"];
          if (ts is Timestamp) createdAt = ts.toDate();
          if (d is int) destroyAfter = d;
          if (d is String) destroyAfter = int.tryParse(d);
        } catch (_) {}

        if (createdAt == null || destroyAfter == null) continue;

        final expiresAt = createdAt.add(Duration(seconds: destroyAfter));

        // ------------- FIX: SAFE DELETE (prevents negative index crash) -------------
        if (now.isAfter(expiresAt)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _deleteMessage(doc.reference, data);
          });
          continue;
        }

        // Already has timer
        if (_messageTimers.containsKey(docKey)) continue;

        // Schedule delete
        final delay = expiresAt.difference(now);
        _messageTimers[docKey] = Timer(delay, () async {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _deleteMessage(doc.reference, data);
          });
          _messageTimers.remove(docKey);
        });
      }
    });

    _listeners[path] = listener;

    // SAFETY timer to catch missed deletes
    _safetyTimers[path] =
        Timer.periodic(const Duration(seconds: 2), (_) => _runSafetyCheck(path));
  }

  // -------------------------------------------------------------
  //  STOP LISTENER
  // -------------------------------------------------------------

  static Future<void> stopListener(String chatId, {bool isGroup = false}) async {
    final path = isGroup
        ? "groups/$chatId/messages"
        : "chats/$chatId/messages";

    await _listeners[path]?.cancel();
    _listeners.remove(path);

    // Cancel message timers for this path
    final keys = _messageTimers.keys
        .where((key) => key.startsWith(path))
        .toList();

    for (final k in keys) _cancelTimer(k);

    _safetyTimers[path]?.cancel();
    _safetyTimers.remove(path);
  }

  // -------------------------------------------------------------
  // OLD API — Backwards compatibility
  // -------------------------------------------------------------

  static void listenForSelfDestructMessages(String fullPath) {
    try {
      final parts = fullPath.split('/');
      if (parts.length >= 3 && (parts[0] == "chats" || parts[0] == "groups")) {
        final isGroup = parts[0] == "groups";
        final id = parts[1];
        startListener(id, isGroup: isGroup);
        return;
      }
    } catch (_) {}

    // fallback
    if (_listeners.containsKey(fullPath)) return;

    final listener = _firestore
        .collection(fullPath)
        .where("selfDestruct", isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        DateTime? createdAt;
        int? destroyAfter;

        final ts = data["createdAt"];
        final d = data["destroyAfter"];
        if (ts is Timestamp) createdAt = ts.toDate();
        if (d is int) destroyAfter = d;
        if (d is String) destroyAfter = int.tryParse(d);

        if (createdAt == null || destroyAfter == null) continue;

        final expiresAt =
        createdAt.add(Duration(seconds: destroyAfter));

        if (now.isAfter(expiresAt)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _deleteMessage(doc.reference, data);
          });
        }
      }
    });

    _listeners[fullPath] = listener;

    _safetyTimers[fullPath] =
        Timer.periodic(const Duration(seconds: 2), (_) => _runSafetyCheck(fullPath));
  }

  static Future<void> stopListening(String fullPath) async {
    try {
      final parts = fullPath.split('/');
      if (parts.length >= 3 && (parts[0] == "chats" || parts[0] == "groups")) {
        final isGroup = parts[0] == "groups";
        final id = parts[1];
        await stopListener(id, isGroup: isGroup);
        return;
      }
    } catch (_) {}

    await _listeners[fullPath]?.cancel();
    _listeners.remove(fullPath);

    final keys = _messageTimers.keys
        .where((key) => key.startsWith(fullPath))
        .toList();
    for (final k in keys) _cancelTimer(k);

    _safetyTimers[fullPath]?.cancel();
    _safetyTimers.remove(fullPath);
  }

  // -------------------------------------------------------------
  //  INTERNAL HELPERS
  // -------------------------------------------------------------

  static Future<void> _runSafetyCheck(String path) async {
    try {
      final now = DateTime.now();

      final snap = await _firestore
          .collection(path)
          .where("selfDestruct", isEqualTo: true)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();

        DateTime? createdAt;
        int? destroyAfter;

        final ts = data["createdAt"];
        final d = data["destroyAfter"];
        if (ts is Timestamp) createdAt = ts.toDate();
        if (d is int) destroyAfter = d;
        if (d is String) destroyAfter = int.tryParse(d);

        if (createdAt == null || destroyAfter == null) continue;

        final expiresAt =
        createdAt.add(Duration(seconds: destroyAfter));

        if (now.isAfter(expiresAt)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _deleteMessage(doc.reference, data);
          });
        }
      }
    } catch (e) {
      debugPrint("Safety check failed: $e");
    }
  }

  static Future<void> _deleteMessage(
      DocumentReference ref,
      Map<String, dynamic> data,
      ) async {
    try {
      final exists = await ref.get();
      if (!exists.exists) return;

      await ref.delete();

      final mediaUrl =
      (data['decryptedUrl'] ?? data['mediaUrl']) as String?;
      if (mediaUrl != null && mediaUrl.isNotEmpty) {
        _deleteCloudinaryFile(mediaUrl);
      }
    } catch (e) {
      debugPrint("Failed to delete message: $e");
    }
  }

  static void _deleteCloudinaryFile(String url) {
    // optional: call your Cloudinary delete function
  }

  static void _cancelTimer(String key) {
    final t = _messageTimers[key];
    if (t != null && t.isActive) t.cancel();
    _messageTimers.remove(key);
  }
}
