import 'package:flutter/material.dart';
import '../auth/SIgnup.dart';

class OnboardingScreen4 extends StatefulWidget {
  const OnboardingScreen4({super.key});

  @override
  State<OnboardingScreen4> createState() => _OnboardingScreen4State();
}

class _OnboardingScreen4State extends State<OnboardingScreen4>
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
      begin: const Offset(0, 0.25),
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

  void _goToSignup() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF0B223A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isSmallScreen = constraints.maxHeight < 700;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: isSmallScreen ? 20 : 40,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: isSmallScreen ? 40 : 80),

                      // 🔥 Onboarding Image
                      SizedBox(
                        width: isSmallScreen ? 200 : 260,
                        height: isSmallScreen ? 200 : 260,
                        child: Image.asset(
                          'assets/onboarding4.png',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🔥 Heading
                      const Text(
                        "Let's Begin",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Montserrat',
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const Spacer(),

                      // 🔥 Animated Next Button
                      GestureDetector(
                        onTap: _goToSignup,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 160,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF19B5FE),
                                Color(0xFF4D9DFE),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Montserrat',
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 30 : 80),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
