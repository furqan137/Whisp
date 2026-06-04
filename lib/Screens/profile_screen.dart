import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/theme_provider.dart';
import '../../Service/chatfeature.dart';
import 'privacy_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userUid; // If null → show current user
  const ProfileScreen({super.key, this.userUid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;
  Map<String, dynamic>? userData;

  bool isLoading = true;
  bool viewingOthers = false;
  bool isEditingName = false;

  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  // ----------------------- LOAD USER ----------------------------
  Future<void> _loadUser() async {
    setState(() => isLoading = true);

    currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final uidToShow = widget.userUid ?? currentUser!.uid;
    viewingOthers = uidToShow != currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uidToShow)
        .get();

    userData = doc.exists
        ? doc.data()
        : {
      'username': 'Unknown',
      'name': '',
      'profileUrl': null,
      'vpnLocation': "Not Set",
      'isVPNConnected': false,
    };

    _nameController.text = userData?['name'] ?? "";

    setState(() => isLoading = false);
  }

  // ----------------------- PICK IMAGE ----------------------------
  Future<void> _pickProfileImage() async {
    if (viewingOthers) return;

    final file =
    await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    _profileImage = File(file.path);
    setState(() {});

    await _uploadProfileImage();
  }

  // ----------------------- UPLOAD IMAGE ----------------------------
  Future<void> _uploadProfileImage() async {
    if (_profileImage == null || currentUser == null) return;

    final url =
    await ChatFeatures.uploadToCloudinary(_profileImage!, "image");
    if (url == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"profileUrl": url});

    setState(() => userData?["profileUrl"] = url);
  }

  // ----------------------- UPDATE NAME ----------------------------
  Future<void> _updateName() async {
    if (viewingOthers) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({"name": newName});

    setState(() {
      userData?["name"] = newName;
      isEditingName = false;
    });
  }

  // ----------------------- UI BUILD ----------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    final gradient = LinearGradient(
      colors: [theme.accentColor, theme.accentColor.withOpacity(0.5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    if (isLoading) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: theme.accentColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1220) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0C1220) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          viewingOthers ? "User Profile" : "My Profile",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // ---------------- PROFILE IMAGE ----------------
              GestureDetector(
                onTap: viewingOthers ? null : _pickProfileImage,
                child: Container(
                  decoration:
                  BoxDecoration(shape: BoxShape.circle, gradient: gradient),
                  padding: const EdgeInsets.all(3),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: userData?['profileUrl'] != null
                        ? NetworkImage(userData!['profileUrl'])
                        : null,
                    child: userData?['profileUrl'] == null
                        ? Text(
                      (userData?['name'] ??
                          userData?['username'] ??
                          "?")
                          .toString()
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                        : null,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ---------------- USERNAME BOX ----------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(14)),
                child: Text(
                  "Username: ${userData?['username'] ?? 'User'}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ---------------- ALWAYS SHOW LOCATION ----------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  "Location: ${userData?["vpnLocation"] ?? "Not Set"}",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ---------------- NAME SECTION ----------------
              viewingOthers
                  ? Text(
                userData?["name"] ?? "",
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : isEditingName
                  ? Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: TextStyle(
                          color: textColor, fontSize: 22),
                      decoration: InputDecoration(
                        hintText: "Enter name",
                        hintStyle: TextStyle(
                            color: textColor.withOpacity(0.5)),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check,
                        color: Colors.green),
                    onPressed: _updateName,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.red),
                    onPressed: () {
                      setState(() {
                        isEditingName = false;
                        _nameController.text =
                            userData?["name"] ?? "";
                      });
                    },
                  ),
                ],
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    userData?["name"] ?? "",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!viewingOthers)
                    IconButton(
                      icon:
                      Icon(Icons.edit, color: textColor),
                      onPressed: () =>
                          setState(() => isEditingName = true),
                    ),
                ],
              ),

              const SizedBox(height: 35),

              // ---------------- PRIVACY SETTINGS ----------------
              if (!viewingOthers)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PrivacySettingsScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            color: theme.accentColor, size: 26),
                        const SizedBox(width: 12),
                        Text(
                          "Privacy Settings",
                          style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios,
                            color: textColor.withOpacity(0.5),
                            size: 18),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
