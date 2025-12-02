// login_with_reset_and_2fa.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'SIgnup.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../home/home.dart';
import 'security_question_2fa.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _forgotEmailController = TextEditingController();

  bool _isLoading = false;
  String? _message;

  String _hash(String input) => sha256.convert(utf8.encode(input)).toString();

  // ===================== LOGIN FUNCTION =====================
  Future<void> _loginUser() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Please fill in all fields';
        _isLoading = false;
      });
      return;
    }

    try {
      final users = FirebaseFirestore.instance.collection('users');
      final querySnapshot = await users.where('username', isEqualTo: username).limit(1).get();

      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _message = 'Username does not exist.';
          _isLoading = false;
        });
        return;
      }

      final doc = querySnapshot.docs.first;
      final userData = doc.data();
      final savedPasswordHash = (userData['password'] ?? '') as String;
      final email = (userData['email'] ?? '') as String;
      final uid = doc.id;

      final hashedInput = _hash(password);

      if (hashedInput != savedPasswordHash) {
        setState(() {
          _message = 'Incorrect password.';
          _isLoading = false;
        });
        return;
      }

      // ================== Firebase Auth Login ==================
      try {
        if (email.isNotEmpty) {
          final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          final firebaseUser = userCredential.user;
          if (firebaseUser != null) {
            await _updateUserLogin(uid: firebaseUser.uid); // save deviceToken + isOnline
            _navigateToHome();
            return;
          }
        }
      } catch (authErr) {
        debugPrint('FirebaseAuth login failed, fallback to Firestore: $authErr');
      }

      // ================== Firestore fallback ==================
      await _updateUserLogin(uid: uid);
      _navigateToHome();
    } catch (e) {
      debugPrint('Login error: $e');
      setState(() {
        _message = 'An error occurred. Please try again.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ================ UPDATE USER LOGIN INFO ==================
  Future<void> _updateUserLogin({required String uid}) async {
    try {
      final deviceToken = await FirebaseMessaging.instance.getToken();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'deviceToken': deviceToken ?? '',
        'isOnline': true,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Failed updating user login info: $e');
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePageWrapper(forceShowHome: true)),
    );
  }

  // ================= FORGOT PASSWORD DIALOG =================
  Future<void> _showForgotPasswordDialog() async {
    final gradient = const LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)]);
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF101526),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Reset Password', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                const SizedBox(height: 18),

                // email / username input
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: gradient),
                  child: Container(
                    margin: const EdgeInsets.all(2.2),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFF101526)),
                    child: TextField(
                      controller: _forgotEmailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Enter email OR username',
                        hintStyle: TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Send reset email
                SizedBox(
                  height: 40,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(12)),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: const Text("Send Reset Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Montserrat')),
                      onPressed: () async {
                        final input = _forgotEmailController.text.trim();
                        if (input.isEmpty) return;

                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: input);
                          Navigator.pop(context);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password reset email sent!")));
                        } catch (e) {
                          Navigator.pop(context);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Security Question option
                SizedBox(
                  height: 40,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3C8CE7), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text("Use Security Questions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Montserrat')),
                    onPressed: () async {
                      final input = _forgotEmailController.text.trim();
                      if (input.isEmpty) return;

                      final users = FirebaseFirestore.instance.collection("users");
                      final snapshotEmail = await users.where("email", isEqualTo: input).limit(1).get();
                      final snapshotUser = await users.where("username", isEqualTo: input).limit(1).get();

                      if (snapshotEmail.docs.isEmpty && snapshotUser.docs.isEmpty) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not found for reset")));
                        return;
                      }

                      final doc = snapshotEmail.docs.isNotEmpty ? snapshotEmail.docs.first : snapshotUser.docs.first;
                      final uid = doc.id;
                      final email = (doc.data()['email'] ?? '') as String;

                      Navigator.pop(context);

                      final result = await Navigator.push<bool?>(
                        context,
                        MaterialPageRoute(builder: (_) => SecurityQuestion2FA(uid: uid, isForPasswordReset: true)),
                      );

                      if (result == true && mounted) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ResetPasswordPage(uid: uid, email: email)));
                      }
                    },
                  ),
                ),

                const SizedBox(height: 18),

                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white70))),
              ],
            ),
          ),
        );
      },
    );
  }

  // ======================= UI =======================
  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)]);
    final accent = const Color(0xFF6D5DF6);

    return Scaffold(
      backgroundColor: const Color(0xFF101526),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Text('Login', style: TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'Montserrat')),
              const SizedBox(height: 36),

              // username
              _buildTextField(_usernameController, 'Username', gradient),
              const SizedBox(height: 18),

              // password
              _buildTextField(_passwordController, 'Password', gradient, isPassword: true),
              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _showForgotPasswordDialog,
                  child: ShaderMask(
                    shaderCallback: (bounds) => gradient.createShader(bounds),
                    child: const Text('Forget Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Montserrat', decoration: TextDecoration.underline)),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              if (_message != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_message!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Montserrat'))),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                    onPressed: _isLoading ? null : _loginUser,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat')),
                  ),
                ),
              ),

              const SizedBox(height: 22),
              const Divider(height: 1, thickness: 1, color: Colors.white12),
              const SizedBox(height: 18),

              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                child: Text("Don't have an account? Sign Up", style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: "Montserrat", decoration: TextDecoration.underline, letterSpacing: 1.1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, Gradient gradient, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: gradient),
      child: Container(
        margin: const EdgeInsets.all(2.2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF101526)),
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      ),
    );
  }
}

/// ====================== ResetPasswordPage ======================
class ResetPasswordPage extends StatefulWidget {
  final String uid;
  final String email;

  const ResetPasswordPage({super.key, required this.uid, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();
  bool _isSaving = false;
  String? _msg;

  String _hash(String input) => sha256.convert(utf8.encode(input)).toString();

  Future<void> _saveNewPassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();

    if (newPass.isEmpty || confirm.isEmpty) {
      setState(() => _msg = 'Please fill both fields.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _msg = 'Password must be at least 6 characters.');
      return;
    }
    if (newPass != confirm) {
      setState(() => _msg = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSaving = true;
      _msg = null;
    });

    try {
      final hashed = _hash(newPass);

      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'password': hashed,
        'passwordLastChangedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (widget.email.isNotEmpty) {
        try {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);
        } catch (e) {
          debugPrint('Failed to send reset email: $e');
        }
      }

      setState(() => _msg = 'Password updated (Firestore). A reset email was sent if email exists.');
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.popUntil(context, (route) => route.isFirst);
      });
    } catch (e) {
      setState(() => _msg = 'Error updating password: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)]);
    return Scaffold(
      appBar: AppBar(title: const Text('Set New Password'), backgroundColor: const Color(0xFF101526)),
      backgroundColor: const Color(0xFF101526),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildTextField(_newPassCtrl, 'New password', gradient, isPassword: true),
            const SizedBox(height: 12),
            _buildTextField(_confirmPassCtrl, 'Confirm password', gradient, isPassword: true),
            const SizedBox(height: 18),
            if (_msg != null) Text(_msg!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(12)),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                  onPressed: _isSaving ? null : _saveNewPassword,
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save New Password', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, Gradient gradient, {bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: gradient),
      child: Container(
        margin: const EdgeInsets.all(2.2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: const Color(0xFF101526)),
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }
}
