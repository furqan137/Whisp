import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'Login.dart';
import 'emailauthentication.dart';
import 'security_question_2fa.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController(); // <-- Add name controller
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isChecking = false;
  String? _message;

  final CollectionReference usersRef =
  FirebaseFirestore.instance.collection('users');

  // --- Generate Random Username ---
  String _generateUsername() {
    const letters = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    final rand = Random();
    final namePart = List.generate(
        4 + rand.nextInt(3),
            (index) => letters[rand.nextInt(letters.length)]
    ).join();
    final numberPart = List.generate(
        3 + rand.nextInt(3),
            (index) => numbers[rand.nextInt(numbers.length)]
    ).join();
    return '${namePart}_$numberPart';
  }

  Future<bool> _isUsernameTaken(String username) async {
    final snapshot =
    await usersRef.where('username', isEqualTo: username).get();
    return snapshot.docs.isNotEmpty;
  }

  // --- Hash Password ---
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // --- Signup Flow ---
  Future<void> _signup() async {
    final username = _usernameController.text.trim();
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    setState(() => _message = null);

    if (username.isEmpty || name.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() => _message = 'Please fill all fields');
      return;
    }

    if (password.length < 6) {
      setState(() => _message = 'Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _message = 'Passwords do not match');
      return;
    }

    setState(() => _isChecking = true);

    try {
      final existingUser =
      await usersRef.where('username', isEqualTo: username).limit(1).get();

      if (existingUser.docs.isNotEmpty) {
        setState(() {
          _isChecking = false;
          _message = '⚠️ This username is already taken!';
        });
        return;
      }

      setState(() => _isChecking = false);

      if (!mounted) return;

      // Navigate to Security Question Page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SecurityQuestion2FA(
            uid: '', // No user yet, just collecting data
            onComplete: (securityData) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => EmailAuthenticationPage(
                    username: username,
                    password: password,
                    deviceToken: null,
                    name: name,
                    securityQuestion: securityData['question'],
                    securityAnswer: securityData['answer'],
                  ),
                ),
              );
            },
          ),
        ),
      );

    } catch (e) {
      setState(() {
        _isChecking = false;
        _message = '❌ Error during signup: $e';
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient =
    const LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)]);

    return Scaffold(
      backgroundColor: const Color(0xFF101526),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 30),
              const Text(
                "Sign Up",
                style: TextStyle(
                  fontSize: 36,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: "Montserrat",
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // ---- INPUT CONTAINER ----
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF101526),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.18 * 255).toInt()),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [

                    // Username Field
                    Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: gradient,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2.2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF101526),
                        ),
                        child: TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Username',
                            hintStyle: const TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              tooltip: 'Generate random username',
                              onPressed: () async {
                                String newUsername = _generateUsername();
                                bool taken = await _isUsernameTaken(newUsername);
                                while (taken) {
                                  newUsername = _generateUsername();
                                  taken = await _isUsernameTaken(newUsername);
                                }
                                setState(() {
                                  _usernameController.text = newUsername;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Name Field
                    Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: gradient,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2.2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF101526),
                        ),
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Full Name',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                          ),
                        ),
                      ),
                    ),



                    // Password Field
                    Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: gradient,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2.2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF101526),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Password',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                          ),
                        ),
                      ),
                    ),

                    // Confirm Password Field
                    Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: gradient,
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2.2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF101526),
                        ),
                        child: TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Confirm Password',
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Signup error message
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _message!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: "Montserrat",
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // ---- Signup Button ----
              SizedBox(
                width: 315,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _isChecking ? null : _signup,
                    child: _isChecking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Montserrat",
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),
              Divider(height: 1, thickness: 1, color: Colors.white12),
              const SizedBox(height: 18),

              // ---- Navigate to Login ----
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      gradient.createShader(bounds),
                  child: const Text(
                    "Already have an account? Login",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: "Montserrat",
                      decoration: TextDecoration.underline,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
