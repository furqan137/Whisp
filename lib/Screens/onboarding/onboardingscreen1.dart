import 'package:flutter/material.dart';
import '../auth/Login.dart';
import 'onboardingscreen2.dart';

class OnboardingScreen1 extends StatefulWidget {
  const OnboardingScreen1({super.key});

  @override
  State<OnboardingScreen1> createState() => _OnboardingScreen1State();
}

class _OnboardingScreen1State extends State<OnboardingScreen1>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
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

  void _goLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goNext() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen2()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0B223A);
    const Color buttonBlue = Color(0xFF19B5FE);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  const SizedBox(height: 80),

                  // 🔥 Image
                  SizedBox(
                    width: 260,
                    height: 260,
                    child: Image.asset(
                      'assets/onboarding1.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 🔥 Heading
                  const Text(
                    'Connect with\nusername only',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Montserrat',
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(),

                  // 🔥 Buttons with beautiful design
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 34, vertical: 40),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Skip Button
                        _animatedButton(
                          label: "Skip",
                          bgColor: Colors.white,
                          textColor: buttonBlue,
                          onTap: _goLogin,
                        ),

                        // Next Button
                        _animatedButton(
                          label: "Next",
                          bgColor: buttonBlue,
                          textColor: Colors.white,
                          onTap: _goNext,
                        ),
                      ],
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

  // ----------------------------------------------------
  // 🔥 Modern Animated Button Widget
  // ----------------------------------------------------
  Widget _animatedButton({
    required String label,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => setState(() {}),
      onTapUp: (_) => setState(() {}),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 110,
        height: 45,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            fontSize: 16,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
    );
  }
}
