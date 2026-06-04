// -------------------------------
// File: reset_password_page.dart
// UPDATED & FIXED VERSION
// -------------------------------

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ResetPasswordPage extends StatefulWidget {
  final String uid;
  final String email;

  const ResetPasswordPage({
    super.key,
    required this.uid,
    required this.email,
  });

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _isSaving = false;
  String? _msg;

  /// Unified hashing function (case-insensitive + trimmed)
  String _hash(String input) {
    final normalized = input.trim().toLowerCase();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNewPassword() async {
    final newPass = _newCtrl.text.trim();
    final confirmPass = _confirmCtrl.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      setState(() => _msg = "Please fill both fields");
      return;
    }
    if (newPass.length < 6) {
      setState(() => _msg = "Password must be at least 6 characters");
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _msg = "Passwords do not match");
      return;
    }

    setState(() {
      _isSaving = true;
      _msg = null;
    });

    try {
      final hashed = _hash(newPass);

      // Update Firestore password
      await FirebaseFirestore.instance.collection("users").doc(widget.uid).set({
        "password": hashed,
        "passwordLastChangedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Send Firebase reset email only if email is real
      if (widget.email.isNotEmpty &&
          !widget.email.endsWith("@skip.whisp.com")) {
        try {
          await FirebaseAuth.instance.sendPasswordResetEmail(
            email: widget.email,
          );
        } on FirebaseAuthException catch (e) {
          // Firebase errors shown more clearly
          if (e.code == "invalid-email") {
            debugPrint("Invalid password reset email: ${widget.email}");
          } else if (e.code == "user-not-found") {
            debugPrint("No Firebase user found for reset email.");
          } else {
            debugPrint("Reset email error: ${e.message}");
          }
        }
      }

      if (!mounted) return;
      setState(() => _msg = "Password updated successfully");

      // Return back to login screen
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.popUntil(context, (route) => route.isFirst);
      });

    } catch (e) {
      debugPrint("Password update error: $e");

      if (!mounted) return;
      setState(() => _msg = "Failed to update password. Try again.");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Set New Password"),
        backgroundColor: const Color(0xFF101526),
      ),
      backgroundColor: const Color(0xFF101526),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),

            // New password field
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: gradient,
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF0B1220),
                ),
                child: TextField(
                  controller: _newCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "New password",
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Confirm password field
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: gradient,
              ),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFF0B1220),
                ),
                child: TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Confirm password",
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            if (_msg != null)
              Text(
                _msg!,
                style: const TextStyle(color: Colors.white70),
              ),

            const SizedBox(height: 14),

            // SAVE BUTTON
            SizedBox(
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  onPressed: _isSaving ? null : _saveNewPassword,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Save New Password",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
