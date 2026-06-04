// -------------------------------------------------------
// File: email_authentication.dart
// FINAL UPDATED & FIXED VERSION
// -------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Login.dart';

class EmailAuthenticationPage extends StatefulWidget {
  final String username;
  final String password;
  final String name;
  final String securityQuestion;
  final String securityAnswer;
  final String? deviceToken;

  const EmailAuthenticationPage({
    super.key,
     required this.username,
    required this.password,
    required this.name,
    required this.securityQuestion,
    required this.securityAnswer,
    this.deviceToken,
  });

  @override
  State<EmailAuthenticationPage> createState() =>
      _EmailAuthenticationPageState();
}

class _EmailAuthenticationPageState extends State<EmailAuthenticationPage> {
  final TextEditingController _emailController = TextEditingController();

  bool _isSending = false;
  bool _emailSent = false;
  String? _message;

  Timer? _verifyTimer;

  // -------------------------------------------------------
  // HASH FUNCTION (UNIVERSAL FORMAT)
  // -------------------------------------------------------
  String _hash(String s) =>
      sha256.convert(utf8.encode(s.trim().toLowerCase())).toString();

  // -------------------------------------------------------
  // SAVE USER TO FIRESTORE
  // -------------------------------------------------------
  Future<void> _saveUserToFirestore(String email, String uid) async {
    final users = FirebaseFirestore.instance.collection("users");

    await users.doc(uid).set({
      "uid": uid,
      "username": widget.username,
      "name": widget.name,
      "email": email,
      "password": _hash(widget.password),
      "securityQuestion": widget.securityQuestion,
      "securityAnswer": _hash(widget.securityAnswer),
      "deviceToken": widget.deviceToken ?? "",
      "is2FAEnabled": true,
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------
  // SEND VERIFICATION EMAIL
  // -------------------------------------------------------
  Future<void> _sendVerificationEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _message = "Please enter your email.");
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
      _message = null;
      _emailSent = false;
    });

    try {
      // Create Firebase user using email + password
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: widget.password,
      );

      await cred.user?.sendEmailVerification();
      setState(() => _emailSent = true);

      // Start verification loop
      _startVerificationLoop(email);
    } on FirebaseAuthException catch (e) {
      String msg = "Something went wrong";

      if (e.code == "email-already-in-use") {
        msg = "This email is already registered.";
      } else if (e.code == "invalid-email") {
        msg = "This email format is invalid.";
      } else if (e.code == "weak-password") {
        msg = "Password must be stronger.";
      } else if (e.code == "network-request-failed") {
        msg = "Network error. Check connection.";
      } else {
        msg = e.message ?? "Unknown error.";
      }

      setState(() => _message = msg);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // -------------------------------------------------------
  // AUTO CHECKING EMAIL VERIFICATION LOOP — FIXED VERSION
  // -------------------------------------------------------
  void _startVerificationLoop(String email) {
    _verifyTimer?.cancel();

    _verifyTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      try {
        await FirebaseAuth.instance.currentUser?.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;

        if (updatedUser != null && updatedUser.emailVerified) {
          timer.cancel();

          await _saveUserToFirestore(email, updatedUser.uid);

          if (!mounted) return;
          setState(() => _message = "✅ Email verified successfully!");

          await Future.delayed(const Duration(milliseconds: 900));

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } catch (e) {
        debugPrint("Verification loop error: $e");
      }
    });
  }

  // -------------------------------------------------------
  // SKIP EMAIL (AUTO GENERATE)
  // -------------------------------------------------------
  Future<void> _skipEmail() async {
    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      final safeUser =
          widget.username.replaceAll(RegExp(r"[^a-zA-Z0-9._-]"), "");
      final fakeEmail =
          "${safeUser}_${DateTime.now().millisecondsSinceEpoch}@skip.whisp.com";

      UserCredential cred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: widget.password,
      );

      await _saveUserToFirestore(fakeEmail, cred.user!.uid);

      if (!mounted) return;
      setState(() => _message = "Account created without verification.");

      await Future.delayed(const Duration(milliseconds: 900));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      setState(() => _message = "Failed: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // -------------------------------------------------------
  // UI
  // -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const gradient =
        LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)]);

    return Scaffold(
      backgroundColor: const Color(0xFF101526),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    "Verify Your Email",
                    style: TextStyle(
                      fontSize: 31,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: "Montserrat",
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Email Field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: gradient,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(2.4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF101526),
                      ),
                      child: TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "Enter Email",
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Colors.white70),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 18),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _message!.startsWith("✅")
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const SizedBox(height: 18),

                  // SEND BUTTON
                  SizedBox(
                    width: 330,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ElevatedButton(
                        onPressed: _isSending ? null : _sendVerificationEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: _isSending
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "Send Verification Email",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // SKIP BUTTON
          Positioned(
            right: 24,
            bottom: 24,
            child: !_isSending
                ? ElevatedButton(
                    onPressed: _skipEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "Skip",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  )
                : const SizedBox.shrink(),
          )
        ],
      ),
    );
  }
}
