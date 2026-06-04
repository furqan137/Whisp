import 'package:flutter/material.dart';
import '../auth/Login.dart';
import 'onboardingscreen3.dart';

class OnboardingScreen2 extends StatefulWidget {
  const OnboardingScreen2({super.key});

  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    // 🔥 Smooth onboarding animation
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 🔥 Custom modern rounded button
  Widget _buildButton({
    required String text,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 110,
      height: 44,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            fontFamily: 'Montserrat',
          ),
        ),
        onPressed: onTap,
        child: Text(text),
      ),
    );
  }

  void _nextPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen3()),
    );
  }

  void _skipToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0B223A);
    const accentBlue = Color(0xFF19B5FE);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Column(
              children: [
                const SizedBox(height: 80),

                // 🔥 Onboarding Illustration
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Image.asset(
                    'assets/onboarding2.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 26),

                // 🔥 Title
                const Text(
                  'Private &\nEncrypted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Montserrat',
                    height: 1.2,
                  ),
                ),

                const Spacer(),

                // 🔥 Buttons Row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 34,
                    vertical: 40,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildButton(
                        text: "Skip",
                        bg: Colors.white,
                        fg: accentBlue,
                        onTap: _skipToLogin,
                      ),
                      _buildButton(
                        text: "Next",
                        bg: accentBlue,
                        fg: Colors.white,
                        onTap: _nextPage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
