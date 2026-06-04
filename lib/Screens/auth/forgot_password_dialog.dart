// -------------------------------
// File: forgot_password_dialog.dart
// FINAL UPDATED + FIXED VERSION
// -------------------------------

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'security_question_2fa.dart';
import 'reset_password_page.dart';

class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final TextEditingController _inputCtrl = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // SEND RESET EMAIL — SAFE ERRORS
  // ----------------------------------------------------------
  Future<void> _sendResetEmail(String email) async {
    if (!mounted) return;

    if (!email.contains("@") || !email.contains(".")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid email format")),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent!")),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String msg = "Unable to send reset email";

      if (e.code == "user-not-found") msg = "No account exists with this email";
      else if (e.code == "invalid-email") msg = "Invalid email address";
      else if (e.code == "too-many-requests") msg = "Too many attempts, try again later";
      else if (e.message != null) msg = e.message!;

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ----------------------------------------------------------
  // USE SECURITY QUESTION FLOW
  // ----------------------------------------------------------
  Future<void> _useSecurityQuestions(String input) async {
    setState(() => _isProcessing = true);

    try {
      final users = FirebaseFirestore.instance.collection("users");

      final byEmail = await users.where("email", isEqualTo: input).limit(1).get();
      final byUsername = await users.where("username", isEqualTo: input).limit(1).get();

      if (byEmail.docs.isEmpty && byUsername.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not found")),
        );
        return;
      }

      final doc = byEmail.docs.isNotEmpty ? byEmail.docs.first : byUsername.docs.first;

      final uid = doc.id;
      final email = (doc.data()["email"] ?? "").toString();

      // Close dialog first
      Navigator.of(context).pop(false);

      // Navigate to Security Question Screen
      final passed = await Navigator.push<bool?>(
        context,
        MaterialPageRoute(
          builder: (_) => SecurityQuestion2FA(
            uid: uid,
            isForPasswordReset: true,
          ),
        ),
      );

      // If verified → go to reset password page
      if (passed == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordPage(uid: uid, email: email),
          ),
        );
      }
    } catch (e) {
      debugPrint("Security Question Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)],
    );

    return Dialog(
      backgroundColor: const Color(0xFF0B1220),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Reset Password",
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 14),

            // INPUT FIELD
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: gradient,
              ),
              child: Container(
                margin: const EdgeInsets.all(2.4),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFF101526),
                ),
                child: TextField(
                  controller: _inputCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Email or Username",
                    hintStyle: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // SEND RESET EMAIL BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () {
                  final text = _inputCtrl.text.trim();
                  if (text.isEmpty) return;
                  _sendResetEmail(text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Send Reset Email"),
              ),
            ),

            const SizedBox(height: 12),

            // SECURITY QUESTION OPTION
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () {
                  final text = _inputCtrl.text.trim();
                  if (text.isEmpty) return;
                  _useSecurityQuestions(text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3C8CE7),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Use Security Question"),
              ),
            ),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
