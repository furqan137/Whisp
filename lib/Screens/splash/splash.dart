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

class _SplashScreenState extends State<SplashScreen> {
  bool _isFirstInstall = false;

  @override
  void initState() {
    super.initState();
    _initSplash();
  }

  Future<void> _initSplash() async {
    await _checkFirstInstall();
    _listenAuthState();
  }

  Future<void> _checkFirstInstall() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool('isFirstInstall') ?? true;
    _isFirstInstall = isFirst;
    if (isFirst) {
      await prefs.setBool('isFirstInstall', false);
    }
  }

  void _listenAuthState() {
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      await Future.delayed(const Duration(milliseconds: 800)); // splash delay

      if (_isFirstInstall) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen1()),
        );
      } else if (user != null) {
        final hasChats = await _hasChats(user.uid);
        if (hasChats) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) =>
                const HomePageWrapper(forceShowHome: true)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StartChatPage(onStartChat: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                      const HomePageWrapper(forceShowHome: true)),
                );
              }),
            ),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  Future<bool> _hasChats(String uid) async {
    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('messages')
        .where('fromUid', isEqualTo: uid)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF3A3A3A), Color(0xFFBDBDBD)],
    );
    final buttonGradient = const LinearGradient(
      colors: [Color(0xFF3C8CE7), Color(0xFF6D5DF6)],
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Splash logo
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 70),
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Image.asset(
                      'assets/Splashlogo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                "WHISP",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  fontFamily: "Montserrat",
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Secure Conversations. Simplified.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontFamily: "Montserrat",
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              SizedBox(
                width: 140,
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: buttonGradient,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _listenAuthState,
                    child: const Text(
                      "Explore",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: "Montserrat",
                      ),
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
