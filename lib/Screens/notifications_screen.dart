import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/theme_provider.dart';
import 'package:provider/provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  User? currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _notificationStream() {
    if (currentUser == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1220) : const Color(0xFFF5F6FA),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF0C1220) : Colors.white,
        title: Text(
          "Notifications",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: themeProv.accentColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No notifications yet",
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data();
              final title = data["title"] ?? "Notification";
              final message = data["message"] ?? "";
              final timestamp = data["timestamp"] != null
                  ? (data["timestamp"] as Timestamp).toDate()
                  : null;

              return _notificationCard(
                title: title,
                message: message,
                timestamp: timestamp,
                themeProv: themeProv,
                isDark: isDark,
              );
            },
          );
        },
      ),
    );
  }

  Widget _notificationCard({
    required String title,
    required String message,
    required DateTime? timestamp,
    required ThemeProvider themeProv,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: themeProv.accentColor.withOpacity(0.25),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // Gradient accent top bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: themeProv.chatGradient,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  message,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                  ),
                ),

                if (timestamp != null) ...[
                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      "${timestamp.day}/${timestamp.month}/${timestamp.year}  •  "
                          "${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}",
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
