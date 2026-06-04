import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../theme/theme_provider.dart';
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
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;

    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1220) : Colors.grey.shade100,

      appBar: AppBar(
        title: Text(
          "Groups",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: themeProv.accentColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white),
            tooltip: "Create Group",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateGroupScreen()),
              );
            },
          )
        ],
      ),

      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: themeProv.isDarkMode
                ? [
              Color(0xFF0C1220),
              Color(0xFF111A2E),
            ]
                : [
              Colors.white,
              Colors.blue.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('groups')
              .where('members', arrayContains: currentUser?.uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: themeProv.accentColor,
                ),
              );
            }

            final groups = snap.data?.docs ?? [];

            if (groups.isEmpty) {
              return Center(
                child: Text(
                  "No groups found.",
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 18,
                  ),
                ),
              );
            }

            return ListView.builder(
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index].data() as Map<String, dynamic>;
                final groupId = groups[index].id;

                final groupName = group['name'] ?? 'Unnamed Group';
                final groupImage = group['imageUrl'];

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('groups')
                      .doc(groupId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .limit(1)
                      .get(),
                  builder: (context, msgSnap) {
                    String lastMsg = "";
                    String lastTime = "";
                    Icon? msgIcon;

                    if (msgSnap.hasData && msgSnap.data!.docs.isNotEmpty) {
                      final msg = msgSnap.data!.docs.first.data()
                      as Map<String, dynamic>;

                      final mediaType = msg['mediaType'];
                      final text = msg['text'];

                      if (mediaType == null) {
                        lastMsg = text ?? "";
                      } else if (mediaType == "image") {
                        lastMsg = text?.isNotEmpty == true ? text : "Photo";
                        msgIcon = Icon(Icons.image,
                            color: Colors.grey.shade500, size: 16);
                      } else if (mediaType == "video") {
                        lastMsg = text?.isNotEmpty == true ? text : "Video";
                        msgIcon = Icon(Icons.videocam,
                            color: Colors.grey.shade500, size: 16);
                      } else if (mediaType == "audio") {
                        lastMsg = text?.isNotEmpty == true
                            ? text
                            : "Voice message";
                        msgIcon = Icon(Icons.mic,
                            color: Colors.grey.shade500, size: 16);
                      } else {
                        lastMsg = text?.isNotEmpty == true ? text : "File";
                        msgIcon = Icon(Icons.attach_file,
                            color: Colors.grey.shade500, size: 16);
                      }

                      if (msg['timestamp'] != null) {
                        lastTime = DateFormat("HH:mm")
                            .format((msg['timestamp'] as Timestamp).toDate());
                      }
                    }

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupChatScreen(
                              groupId: groupId,
                              groupName: groupName,
                            ),
                          ),
                        );
                      },

                      child: Container(
                        margin: EdgeInsets.symmetric(
                            vertical: 6, horizontal: 12),
                        padding: EdgeInsets.symmetric(
                            vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: isDark ? Color(0xFF111A2E) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              offset: Offset(0, 3),
                              blurRadius: 6,
                            )
                          ],
                        ),

                        child: Row(
                          children: [
                            // AVATAR
                            groupImage != null
                                ? CircleAvatar(
                              radius: 22,
                              backgroundImage:
                              NetworkImage(groupImage),
                            )
                                : CircleAvatar(
                              radius: 22,
                              backgroundColor: themeProv.accentColor,
                              child: Text(
                                groupName[0].toUpperCase(),
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),

                            SizedBox(width: 14),

                            // TEXT CONTENT
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),

                                  Row(
                                    children: [
                                      if (msgIcon != null) ...[
                                        msgIcon,
                                        SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          lastMsg,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(width: 12),

                            Text(
                              lastTime,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
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
