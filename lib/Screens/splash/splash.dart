import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/Login.dart';
import '../chat/startchat.dart';
import '../home/home.dart';
import 'package:whisp/Screens/onboarding/onboardingscreen1.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  bool _isFirstInstall = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initSplash();
  }

  // ---------------------------
  // ✨ Setup splash animations
  // ---------------------------
  void _setupAnimations() {
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  // ---------------------------
  // ✨ Initialize splash logic
  // ---------------------------
  Future<void> _initSplash() async {
    await _checkFirstInstall();

    // wait so splash animation shows
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    await _handleNavigation();
  }

  // ---------------------------
  // ✨ First install check
  // ---------------------------
  Future<void> _checkFirstInstall() async {
    final prefs = await SharedPreferences.getInstance();

    final isFirst = prefs.getBool('isFirstInstall') ?? true;

    if (mounted) {
      setState(() {
        _isFirstInstall = isFirst;
      });
    }

    if (isFirst) {
      await prefs.setBool('isFirstInstall', false);
    }
  }

  // ---------------------------
  // ✨ Navigation Logic
  // ---------------------------
  Future<void> _handleNavigation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (_isFirstInstall) {
      _push(const OnboardingScreen1());
      return;
    }

    if (user != null) {
      final hasChats = await _hasChats(user.uid);

      if (!mounted) return;

      if (hasChats) {
        _push(const HomePageWrapper(forceShowHome: true));
      } else {
        _push(
          StartChatPage(
            onStartChat: () {
              _push(const HomePageWrapper(forceShowHome: true));
            },
          ),
        );
      }
    } else {
      _push(const LoginScreen());
    }
  }

  // ---------------------------
  // ✨ Check if user has chats
  // ---------------------------
  Future<bool> _hasChats(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('messages')
        .where('fromUid', isEqualTo: uid)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // ---------------------------
  // ✨ Navigation Helper
  // ---------------------------
  void _push(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ---------------------------
  // ✨ UI
  // ---------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A1A), Color(0xFF6D6D6D)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LOGO
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 25,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Image.asset(
                      'assets/Splashlogo.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "WHISP",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.8,
                      fontFamily: "Montserrat",
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Secure Conversations. Simplified.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontFamily: "Montserrat",
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 55),

                  // Explore Button
                  GestureDetector(
                    onTapDown: (_) => _animController.value = 0.85,
                    onTapUp: (_) => _animController.forward(),
                    onTap: _handleNavigation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 160,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3C8CE7), Color(0xFF6D5DF6)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "Explore",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Montserrat",
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}