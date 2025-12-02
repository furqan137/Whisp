import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'auth/login.dart';
import '../../Service/chatfeature.dart';

class ProfileScreen extends StatefulWidget {
  final String? userUid;
  const ProfileScreen({super.key, this.userUid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isEditingName = false;
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => isLoading = true);
    currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      final uid = widget.userUid ?? currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        userData = doc.data();
        _nameController.text = userData?['name'] ?? '';
      } else {
        userData = {
          'username': 'Anonymous',
          'name': '',
          'profileUrl': null,
        };
      }
    }
    setState(() => isLoading = false);
  }

  Future<void> _pickProfileImage() async {
    final XFile? pickedFile =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
      await _uploadProfileImage();
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImage == null || currentUser == null) return;
    // Upload to Cloudinary using chatfeature
    final url = await ChatFeatures.uploadToCloudinary(_profileImage!, 'image');
    if (url != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({'profileUrl': url});
      setState(() => userData?['profileUrl'] = url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload image to Cloudinary.')),
      );
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty || currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .update({'name': newName});
    setState(() {
      userData?['name'] = newName;
      isEditingName = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)]);
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF101526),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF101526),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFF101526),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Align to top
            children: [
              // Profile Image
              GestureDetector(
                onTap: _pickProfileImage,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                  ),
                  padding: const EdgeInsets.all(3.5),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.grey[300],
                    backgroundImage: userData?['profileUrl'] != null
                        ? NetworkImage(userData!['profileUrl'])
                        : null,
                    child: userData?['profileUrl'] == null
                        ? Text(
                            (userData?['name'] ?? userData?['username'] ?? '?').toString().isNotEmpty
                                ? (userData?['name'] ?? userData?['username'] ?? '?')[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Username (read-only)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: gradient,
                ),
                child: Text(
                  'Username:  ${userData?['username'] ?? 'Anonymous'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Name (editable)
              isEditingName
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            style: const TextStyle(color: Colors.white, fontSize: 22),
                            decoration: const InputDecoration(
                              hintText: 'Enter name',
                              hintStyle: TextStyle(color: Colors.white54),
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: _updateName,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              isEditingName = false;
                              _nameController.text = userData?['name'] ?? '';
                            });
                          },
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          userData?['name'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              isEditingName = true;
                            });
                          },
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
