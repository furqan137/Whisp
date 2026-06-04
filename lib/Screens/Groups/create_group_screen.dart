import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateGroupScreen extends StatefulWidget {
  final bool isAddMembersMode;
  final Set<String>? initialSelectedUserIds;
  final Function(List<String>)? onMembersAdded;
  const CreateGroupScreen({
    Key? key,
    this.isAddMembersMode = false,
    this.initialSelectedUserIds,
    this.onMembersAdded,
  }) : super(key: key);
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  List<String> _selectedUserIds = [];
  final currentUser = FirebaseAuth.instance.currentUser;
  List<String> _chattedUserIds = [];
  bool _loadingUsers = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedUserIds != null) {
      _selectedUserIds = List<String>.from(widget.initialSelectedUserIds!);
    }
    _prefetchChattedUserIds();
  }

  Future<void> _prefetchChattedUserIds() async {
    final ids = await _fetchChattedUserIds();
    setState(() {
      _chattedUserIds = ids;
      _loadingUsers = false;
    });
  }

  Future<List<String>> _fetchChattedUserIds() async {
    final uid = currentUser?.uid;
    if (uid == null) return [];
    final Set<String> peerUids = {};

    // Fetch sent messages
    try {
      final sent = await FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('fromUid', isEqualTo: uid)
          .get();
      for (final doc in sent.docs) {
        final data = doc.data();
        if (data.containsKey('toUid') && data['toUid'] != null && data['toUid'] != uid) {
          peerUids.add(data['toUid']);
        }
      }
    } catch (e) {
      print('Error fetching sent messages: $e');
    }

    // Fetch received messages
    try {
      final received = await FirebaseFirestore.instance
          .collectionGroup('messages')
          .where('toUid', isEqualTo: uid)
          .get();
      for (final doc in received.docs) {
        final data = doc.data();
        if (data.containsKey('fromUid') && data['fromUid'] != null && data['fromUid'] != uid) {
          peerUids.add(data['fromUid']);
        }
      }
    } catch (e) {
      print('Error fetching received messages: $e');
    }

    return peerUids.toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    if (_chattedUserIds.isEmpty) return [];
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: _chattedUserIds)
        .get();
    return usersSnap.docs.map((doc) => doc.data()).toList();
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty || _selectedUserIds.isEmpty) return;
    final uid = currentUser?.uid;
    final members = [uid, ..._selectedUserIds].toSet().toList();
    final groupRef = await FirebaseFirestore.instance.collection('groups').add({
      'name': groupName,
      'createdBy': uid,
      'admin': uid,
      'members': members,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Add welcome message
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.isAddMembersMode ? 'Add Members' : 'Create Group', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF5B5FE9),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5B5FE9), Color(0xFF7F53AC)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isAddMembersMode)
                TextField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              if (!widget.isAddMembersMode) const SizedBox(height: 18),
              const Text('Select Members:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Expanded(
                child: _loadingUsers
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _fetchUsers(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: Colors.white));
                        }
                        final users = snapshot.data!;
                        if (users.isEmpty) {
                          return const Center(child: Text('No chat contacts found', style: TextStyle(color: Colors.white)));
                        }
                        return ListView(
                          children: users.where((u) => u['uid'] != currentUser?.uid).map((user) {
                            final isSelected = _selectedUserIds.contains(user['uid']);
                            final isDisabled = widget.isAddMembersMode && widget.initialSelectedUserIds != null && widget.initialSelectedUserIds!.contains(user['uid']);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white,
                                child: Text((user['username'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.black)),
                              ),
                              title: Text(user['username'] ?? '', style: const TextStyle(color: Colors.white)),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: isDisabled
                                  ? null
                                  : (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedUserIds.add(user['uid']);
                                        } else {
                                          _selectedUserIds.remove(user['uid']);
                                        }
                                      });
                                    },
                              ),
                              subtitle: isDisabled ? const Text('Already member', style: TextStyle(color: Colors.green, fontSize: 12)) : null,
                            );
                          }).toList(),
                        );
                      },
                    ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  ),
                  onPressed: () async {
                    if (widget.isAddMembersMode) {
                      final newMembers = _selectedUserIds.where((uid) => !(widget.initialSelectedUserIds?.contains(uid) ?? false)).toList();
                      if (widget.onMembersAdded != null) widget.onMembersAdded!(newMembers);
                      Navigator.of(context).pop();
                    } else {
                      final groupName = _groupNameController.text.trim();
                      if (groupName.isEmpty || _selectedUserIds.isEmpty) return;
                      final uid = currentUser?.uid;
                      final members = [uid, ..._selectedUserIds].toSet().toList();
                      await FirebaseFirestore.instance.collection('groups').add({
                        'name': groupName,
                        'createdBy': uid,
                        'admin': uid,
                        'members': members,
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text(widget.isAddMembersMode ? 'Add Selected' : 'Create Group', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
