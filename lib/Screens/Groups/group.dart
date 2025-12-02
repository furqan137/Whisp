import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'create_group_screen.dart';
import 'group_chat_screen.dart';

class GroupScreen extends StatelessWidget {
  const GroupScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GroupListScreenWithNav();
  }
}

class GroupListScreenWithNav extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Groups', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5B5FE9),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CreateGroupScreen()),
              );
            },
            tooltip: 'Create Group',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5B5FE9), Color(0xFF7F53AC)],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .where('members', arrayContains: currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            final groups = snapshot.data?.docs ?? [];
            if (groups.isEmpty) {
              return const Center(
                child: Text('No groups found.', style: TextStyle(color: Colors.white, fontSize: 18)),
              );
            }
            return ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index].data() as Map<String, dynamic>;
                final groupId = groups[index].id;
                final groupName = group['name'] ?? 'Unnamed Group';
                final groupImageUrl = group['imageUrl'];
                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(groupId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .get(),
                  builder: (context, msgSnapshot) {
                    String lastMsg = '';
                    String lastTime = '';
                    Icon? messageIcon;
                    if (msgSnapshot.hasData && msgSnapshot.data!.docs.isNotEmpty) {
                      final msg = msgSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                      final mediaType = msg['mediaType'];
                      if (mediaType == null) {
                        lastMsg = msg['text'] ?? '';
                        messageIcon = null;
                      } else if (mediaType == 'image') {
                        lastMsg = msg['text']?.isNotEmpty == true ? msg['text'] : 'Photo';
                        messageIcon = Icon(Icons.image, color: Colors.grey[600], size: 16);
                      } else if (mediaType == 'video') {
                        lastMsg = msg['text']?.isNotEmpty == true ? msg['text'] : 'Video';
                        messageIcon = Icon(Icons.videocam, color: Colors.grey[600], size: 16);
                      } else if (mediaType == 'audio') {
                        lastMsg = msg['text']?.isNotEmpty == true ? msg['text'] : 'Voice message';
                        messageIcon = Icon(Icons.mic, color: Colors.grey[600], size: 16);
                      } else {
                        lastMsg = msg['text']?.isNotEmpty == true ? msg['text'] : 'File';
                        messageIcon = Icon(Icons.attach_file, color: Colors.grey[600], size: 16);
                      }
                      if (msg['timestamp'] != null) {
                        final dt = (msg['timestamp'] as Timestamp).toDate();
                        lastTime = DateFormat('HH:mm').format(dt);
                      }
                    }
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GroupChatScreen(
                              groupId: groupId,
                              groupName: groupName,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            groupImageUrl != null
                                ? CircleAvatar(radius: 19, backgroundImage: NetworkImage(groupImageUrl))
                                : CircleAvatar(
                                    radius: 19,
                                    backgroundColor: Color(0xFF5B5FE9),
                                    child: Text(
                                      groupName[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupName,
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      if (messageIcon != null) ...[
                                        messageIcon,
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          lastMsg,
                                          style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  lastTime,
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
