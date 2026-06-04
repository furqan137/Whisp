import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ShareMessageScreen extends StatelessWidget {
  final Map<String, dynamic> message;
  final Function(String userId, Map<String, dynamic> message) onSend;

  const ShareMessageScreen({Key? key, required this.message, required this.onSend}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Share Message')),
        body: Center(child: Text('User not logged in')),
      );
    }
    final myUid = currentUser.uid;
    return Scaffold(
      appBar: AppBar(title: Text('Share Message')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getPeersWithMessages(myUid),
        builder: (context, peerSnapshot) {
          if (peerSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final peers = peerSnapshot.data ?? [];
          if (peers.isEmpty) {
            return Center(child: Text('No users to share with'));
          }
          return ListView.builder(
            itemCount: peers.length,
            itemBuilder: (context, index) {
              final user = peers[index];
              final username = user['username'] ?? 'Unknown';
              final uid = user['uid'];
              return ListTile(
                leading: CircleAvatar(child: Text(username.isNotEmpty ? username[0] : '?')),
                title: Text(username),
                onTap: () {
                  onSend(uid, message);
                  Navigator.pop(context);
                },
              );
            },
          );
        },
      ),
    );
  }

  // Helper to get unique peer users with whom the current user has exchanged messages in either direction
  Future<List<Map<String, dynamic>>> _getPeersWithMessages(String myUid) async {
    final Set<String> peerUids = {};
    // Fetch sent messages
    try {
      final sent = await FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('fromUid', isEqualTo: myUid)
          .get();
      for (final doc in sent.docs) {
        final data = doc.data();
        if (data.containsKey('toUid') && data['toUid'] != null && data['toUid'] != myUid) {
          peerUids.add(data['toUid']);
        }
      }
    } catch (e) {
      // Handle error if needed
    }
    // Fetch received messages
    try {
      final received = await FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('toUid', isEqualTo: myUid)
          .get();
      for (final doc in received.docs) {
        final data = doc.data();
        if (data.containsKey('fromUid') && data['fromUid'] != null && data['fromUid'] != myUid) {
          peerUids.add(data['fromUid']);
        }
      }
    } catch (e) {
      // Handle error if needed
    }
    if (peerUids.isEmpty) return [];
    // Firestore whereIn supports max 10 items, so batch if needed
    final List<Map<String, dynamic>> users = [];
    final peerUidList = peerUids.toList();
    for (var i = 0; i < peerUidList.length; i += 10) {
      final batch = peerUidList.sublist(i, i + 10 > peerUidList.length ? peerUidList.length : i + 10);
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      users.addAll(userDocs.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'username': data['username'] ?? '',
        };
      }));
    }
    return users;
  }
}
