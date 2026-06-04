import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../components/bottomnavigator.dart';
import '../auth/login.dart'; // Make sure this path matches your login.dart

class StartChatPage extends StatelessWidget {
  final VoidCallback? onStartChat;
  const StartChatPage({Key? key, this.onStartChat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5B5FE9), Color(0xFF7F53AC)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 120),
            Align(
              alignment: Alignment.topCenter,
              child: Image.asset(
                'assets/startchat.png',
                width: 260,
                height: 260,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Start your first\nConversation\nSecurely',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: 160,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    // User not logged in, redirect to LoginScreen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  } else {
                    // User logged in, open BottomNavigator
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BottomNavigator(
                          initialIndex: BottomNavigator.homeIndex,
                          forceShowHome: true,
                        ),
                      ),
                          (route) => false,
                    );
                  }
                },
                child: const Text(
                  'Start Chat',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
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
