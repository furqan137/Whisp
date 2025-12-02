import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/Chatscreen.dart';
import '../auth/Login.dart';
import '../components/bottomnavigator.dart';
import '/screens/profile_screen.dart';
import '/screens/notifications_screen.dart';
import '../../Service/encryption.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = "";
  String? _currentUsername;
  final accent = Colors.black;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchText = _searchController.text.trim());
    });
    _fetchCurrentUsername();
  }

  Future<void> _fetchCurrentUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _currentUsername = doc.data()?['username'];
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<QueryDocumentSnapshot>> _searchUserStream(String currentUid) {
    if (_searchText.length < 2) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .map((snapshot) => snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final username = (data['username'] ?? '') as String;
      final needle = _searchText.toLowerCase();
      return username.isNotEmpty &&
          doc.id != currentUid &&
          username.toLowerCase().contains(needle);
    }).toList());
  }

  Stream<List<Map<String, dynamic>>> _recentChatsStream(String currentUid) {
    return FirebaseFirestore.instance
        .collectionGroup('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      final seen = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final fromUid = data['fromUid'];
        final toUid = data['toUid'];
        final message = data['message'] ?? '';
        final timestamp = data['timestamp'];
        final mediaType = data['mediaType'];
        final peerUid = fromUid == currentUid
            ? toUid
            : toUid == currentUid
            ? fromUid
            : null;
        if (peerUid == null) continue;
        if (!seen.containsKey(peerUid)) {
          seen[peerUid] = {
            'peerUid': peerUid,
            // Remove peerUsername here, will fetch later
            'lastMessage': message,
            'mediaType': mediaType,
            'timestamp': timestamp,
            'fromUsername': data['fromUsername'] ?? '',
          };
        }
      }
      return seen.values.toList();
    });
  }

  Future<Map<String, Map<String, String>>> _fetchUserInfos(List<String> uids) async {
    if (uids.isEmpty) return {};
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids)
        .get();
    return {
      for (final doc in usersSnap.docs)
        doc.id: {
          'username': (doc.data()['username'] ?? 'Unknown') as String,
          'name': (doc.data()['name'] ?? '') as String,
        }
    };
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUid = currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5B5FE9), Color(0xFF7F53AC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile Icon
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()));
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: accent, size: 28),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 10),
                          Icon(Icons.search, color: accent, size: 22),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(
                                  color: Colors.black87, fontSize: 15),
                              decoration: const InputDecoration(
                                  hintText: 'Search',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                  EdgeInsets.symmetric(vertical: 8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Notification Button
                  const SizedBox(width: 4),
                  // Logout Button
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red, size: 30),
                    onPressed: _logout,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _recentChatsStream(currentUid),
                  builder: (context, snapshot) {
                    final chats = snapshot.data ?? [];
                    final recentUids =
                        chats.map((c) => c['peerUid'] as String).toSet();
                    final showSearch = _searchText.length >= 2;
                    return FutureBuilder<Map<String, Map<String, String>>>(
                      future: _fetchUserInfos(recentUids.toList()),
                      builder: (context, userInfosSnap) {
                        final userInfos = userInfosSnap.data ?? {};
                        final chatsWithUserInfos = chats.map((chat) {
                          final peerUid = chat['peerUid'] as String;
                          final info = userInfos[peerUid] ?? {'username': 'Unknown', 'name': ''};
                          return {
                            ...chat,
                            'peerUsername': info['username'] ?? 'Unknown',
                            'peerName': info['name'] ?? '',
                          };
                        }).toList();
                        return showSearch
                            ? StreamBuilder<List<QueryDocumentSnapshot>>(
                          stream: _searchUserStream(currentUid),
                          builder: (context, snapshot) {
                            final users = (snapshot.data ?? [])
                                .where((user) => !recentUids.contains(user.id))
                                .toList();
                            if (users.isEmpty) {
                              return Column(
                                children: [
                                  const SizedBox(height: 30),
                                  const Text(
                                    'No users found',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 30),
                                  Expanded(
                                      child: _recentChatsList(chatsWithUserInfos, currentUid)),
                                ],
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...users.map((user) => Container(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: Colors.white,
                                        child: Text(
                                          ((user['username'] ?? '?')
                                              .toString()
                                              .isNotEmpty
                                              ? (user['username'] ?? '?')[0]
                                              .toUpperCase()
                                              : '?'),
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user['username'] ?? '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 17,
                                              ),
                                            ),
                                            if ((user['name'] ?? '').toString().isNotEmpty)
                                              Text(
                                                user['name'],
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        height: 36,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 18, vertical: 0),
                                          ),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatScreen(
                                                  peerUid: user.id,
                                                  peerUsername: user['username'],
                                                  peerName: user['name'] ?? '',
                                                ),
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'Start Chat',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                                const SizedBox(height: 20),
                                Expanded(
                                    child: _recentChatsList(chatsWithUserInfos, currentUid)),
                              ],
                            );
                          },
                        )
                            : _recentChatsList(chatsWithUserInfos, currentUid);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentChatsList(List<Map<String, dynamic>> chats, String currentUid) {
    if (chats.isEmpty) {
      return const Center(
        child: Text(
          'No recent chats',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, idx) {
        final chat = chats[idx];
        final peerName = chat['peerName'] ?? '';
        String lastMessage = chat['lastMessage'] ?? '';
        Icon? messageIcon;

        if (chat['mediaType'] == 'image') {
          lastMessage = 'Photo';
          messageIcon = Icon(Icons.image, color: Colors.grey[600], size: 16);
        } else if (chat['mediaType'] == 'video') {
          lastMessage = 'Video';
          messageIcon = Icon(Icons.videocam, color: Colors.grey[600], size: 16);
        } else if (chat['mediaType'] == 'audio') {
          lastMessage = 'Voice message';
          messageIcon = Icon(Icons.mic, color: Colors.grey[600], size: 16);
        } else if (chat['mediaType'] == null) {
          // Text message, decrypt if needed
          try {
            lastMessage = EncryptionService.decryptText(
                lastMessage, EncryptionService.getSharedKey(currentUid, chat['peerUid']));
          } catch (_) {
            lastMessage = 'Message';
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  peerUid: chat['peerUid'],
                  peerUsername: chat['peerUsername'],
                  peerName: peerName,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: accent,
                  child: Text(
                    peerName.isNotEmpty ? peerName[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        peerName,
                        style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Username is not shown at all
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (messageIcon != null) ...[
                            messageIcon,
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(color: Colors.grey[700], fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class HomePageWrapper extends StatelessWidget {
  final bool forceShowHome;
  const HomePageWrapper({super.key, this.forceShowHome = false});

  @override
  Widget build(BuildContext context) {
    return BottomNavigator(
      initialIndex: BottomNavigator.homeIndex,
      forceShowHome: forceShowHome,
    );
  }
}
