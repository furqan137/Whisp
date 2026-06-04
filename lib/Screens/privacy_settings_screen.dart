import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  User? currentUser;

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance.currentUser;
  }

  // STREAM FOR BLOCKED USERS
  Stream<QuerySnapshot<Map<String, dynamic>>> _blockedUsersStream() {
    if (currentUser == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('blocked')
        .snapshots();
  }

  // UNBLOCK USER
  Future<void> _unblockUser(String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('blocked')
        .doc(uid)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;

    final Color bg = isDark ? const Color(0xFF0C1220) : Colors.white;
    final Color cardBg = isDark ? Colors.white10 : Colors.black.withOpacity(0.05);
    final Color borderColor = isDark ? Colors.white12 : Colors.black12;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,

      appBar: AppBar(
        title: Text(
          "Privacy Settings",
          style: TextStyle(color: textColor),
        ),
        backgroundColor: bg,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- SECTION TITLE ----
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "Blocked Users",
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // ---- BLOCKED USERS LIST ----
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _blockedUsersStream(),
              builder: (context, snapshot) {

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: themeProv.accentColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "No blocked users",
                      style: TextStyle(color: textColor.withOpacity(0.6)),
                    ),
                  );
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data();
                    final userId = users[index].id;
                    final username = data["username"] ?? "Unknown";

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),

                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: themeProv.accentColor.withOpacity(0.3),
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : "?",
                              style: TextStyle(
                                  color: themeProv.accentColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Text(
                              username,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                              ),
                            ),
                          ),

                          GestureDetector(
                            onTap: () => _unblockUser(userId),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                "Unblock",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
