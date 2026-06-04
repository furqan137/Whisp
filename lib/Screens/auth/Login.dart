// File: login_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'SIgnup.dart';
import 'forgot_password_dialog.dart';
import '../home/home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _isLoading = false;
  String? _error;

  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  String _hash(String v) => sha256.convert(utf8.encode(v)).toString();

  // -------------------------------------------------------------
  // LOGIN FUNCTION
  // -------------------------------------------------------------
  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = "Please enter username & password");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = FirebaseFirestore.instance.collection('users');
      final q = await users.where('username', isEqualTo: username).limit(1).get();

      if (q.docs.isEmpty) {
        setState(() => _error = "Username not found");
        return;
      }

      final doc = q.docs.first;
      final data = doc.data();
      final storedHash = data['password'] ?? "";
      final email = data['email'] ?? "";
      final uid = doc.id;

      if (_hash(password) != storedHash) {
        setState(() => _error = "Incorrect password");
        return;
      }

      //-----------------------------------------------------------------
      // TRY FIREBASE LOGIN IF EMAIL EXISTS
      //-----------------------------------------------------------------
      if (email is String && email.isNotEmpty) {
        try {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          if (cred.user != null) {
            await _updateLoginDeviceToken(cred.user!.uid);
            _goHome();
            return;
          }
        } on FirebaseAuthException catch (e) {
          debugPrint("Firebase Auth Error: $e");
          // Provide user-friendly errors
          if (e.code == "invalid-email") {
            setState(() => _error = "Invalid email linked to this account.");
          } else if (e.code == "user-not-found") {
            setState(() => _error = "This account email is not registered.");
          } else if (e.code == "wrong-password") {
            setState(() => _error = "Incorrect password for linked email.");
          } else {
            // Ignore and fallback to Firestore login
          }
        }
      }

      //-----------------------------------------------------------------
      // FALLBACK LOGIN (Firestore only)
      //-----------------------------------------------------------------
      await _updateLoginDeviceToken(uid);
      _goHome();
    } catch (e) {
      setState(() => _error = "Login failed. Try again");
      debugPrint("Login exception: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // STORE DEVICE TOKEN, UPDATE LOGIN TIME
  Future<void> _updateLoginDeviceToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        "deviceToken": token,
        "isOnline": true,
        "lastLogin": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Device token update failed: $e");
    }
  }

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomePageWrapper(forceShowHome: true),
      ),
    );
  }

  // -------------------------------------------------------------
  // OPEN FORGOT PASSWORD DIALOG
  // -------------------------------------------------------------
  Future<void> _openForgot() async {
    final result = await showDialog(
      context: context,
      builder: (_) => const ForgotPasswordDialog(),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset started")),
      );
    }
  }

  // -------------------------------------------------------------
  // UI BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF101526),
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Welcome Back",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold)),

                const SizedBox(height: 30),

                _field(_usernameCtrl, "Username", gradient),
                const SizedBox(height: 14),

                _field(_passwordCtrl, "Password", gradient, isPassword: true),
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _openForgot,
                    child: const Text("Forgot Password?",
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),

                const SizedBox(height: 10),

                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),

                const SizedBox(height: 10),

                SizedBox(
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : const Text("Sign In",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),

                const SizedBox(height: 25),
                const Divider(color: Colors.white12),
                const SizedBox(height: 15),

                GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()));
                  },
                  child: const Center(
                    child: Text(
                      "Don't have an account? Sign up",
                      style: TextStyle(
                          color: Color(0xFF6D5DF6),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // INPUT FIELD WITH GRADIENT OUTLINE
  // -------------------------------------------------------------
  Widget _field(TextEditingController c, String h, Gradient g,
      {bool isPassword = false}) {
    return Container(
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: g),
      child: Container(
        margin: const EdgeInsets.all(2.6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF101526),
        ),
        child: TextField(
          controller: c,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: h,
            hintStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}
