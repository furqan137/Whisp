import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Login.dart';

class EmailAuthenticationPage extends StatefulWidget {
  final String username;
  final String password;
  final String? deviceToken;
  final String name;
  final String securityQuestion;
  final String securityAnswer;

  const EmailAuthenticationPage({
    super.key,
    required this.username,
    required this.password,
    this.deviceToken,
    required this.name,
    required this.securityQuestion,
    required this.securityAnswer,
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
  Timer? _checkTimer;

  @override
  void dispose() {
    _checkTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  // --- HASH PASSWORD ---
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // --- SAVE USER TO FIRESTORE ---
  Future<void> _saveUserToFirestore(String email, String uid) async {
    final usersRef = FirebaseFirestore.instance.collection('users');

    String? deviceToken = widget.deviceToken;
    if (deviceToken == null) {
      deviceToken = await FirebaseMessaging.instance.getToken();
    }

    final hashedPassword = _hashPassword(widget.password);
    final hashedSecurityAnswer = _hashPassword(widget.securityAnswer);

    final doc = await usersRef.doc(uid).get();
    if (!doc.exists) {
      await usersRef.doc(uid).set({
        'uid': uid,
        'username': widget.username,
        'name': widget.name, // <-- Store name in Firestore
        'email': email,
        'password': hashedPassword,
        'createdAt': FieldValue.serverTimestamp(),
        'deviceToken': deviceToken,
        'is2FAEnabled': true,
        'securityQuestion': widget.securityQuestion,
        'securityAnswer': hashedSecurityAnswer,
      });
    }
  }

  // --- SEND VERIFICATION EMAIL ---
  Future<void> _sendVerificationEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _message = 'Please enter your email address.');
      return;
    }

    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: widget.password);

      await userCredential.user?.sendEmailVerification();

      setState(() => _emailSent = true);

      // Poll every 5 seconds for verification
      _checkTimer?.cancel();
      _checkTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          timer.cancel();
          return;
        }
        await user.reload();
        if (user.emailVerified) {
          timer.cancel();
          await _saveUserToFirestore(email, user.uid);
          if (!mounted) return;
          setState(() => _message = '✅ Email verified successfully!');
          Future.delayed(const Duration(seconds: 1), () {
            Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()));
          });
        }
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _message = e.message ?? 'Error during email verification.');
    } finally {
      setState(() => _isSending = false);
    }
  }

  // --- SKIP EMAIL VERIFICATION ---
  Future<void> _skipEmailVerification() async {
    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      final safeUsername =
      widget.username.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');
      final skipEmail =
          '${safeUsername}_${DateTime.now().millisecondsSinceEpoch}@skip.whisp.com';

      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: skipEmail, password: widget.password);

      await _saveUserToFirestore(skipEmail, userCredential.user!.uid);

      if (!mounted) return;
      setState(() => _message = 'Account created without email verification.');
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()));
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _message = e.message ?? 'Failed to create account.');
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient =
    const LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)]);
    final accent = const Color(0xFF6D5DF6);

    return Scaffold(
      backgroundColor: const Color(0xFF101526),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  const Text(
                    'Verify Your Email',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Montserrat',
                        letterSpacing: 1.2),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: gradient,
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(2.2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF101526),
                      ),
                      child: TextField(
                        controller: _emailController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Enter Email',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.email_outlined,
                              color: Colors.white70),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _message!,
                        style: TextStyle(
                            color: _message!.startsWith('✅')
                                ? accent
                                : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            fontFamily: 'Montserrat'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_emailSent && _message == null)
                    const Text(
                      '📩 Verification email sent! Please check your inbox.',
                      style: TextStyle(
                          color: Color(0xFF6D5DF6),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Montserrat'),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 20),
                  _isSending
                      ? const CircularProgressIndicator(color: Color(0xFF6D5DF6))
                      : SizedBox(
                    width: 340,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(16)),
                      child: ElevatedButton(
                        onPressed: _sendVerificationEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Send Verification Email',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Montserrat'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 24,
            child: _isSending
                ? const SizedBox(width: 48)
                : SizedBox(
              width: 120,
              height: 48,
              child: ElevatedButton(
                onPressed: _skipEmailVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Skip',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
