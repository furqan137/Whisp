// check_email_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart'; // add this dependency

class CheckEmailScreen extends StatefulWidget {
  final String email;
  const CheckEmailScreen({super.key, required this.email});

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  bool _isResending = false;
  String? _message;

  // Attempt to open the user's email app (best-effort)
  Future<void> _openEmailApp() async {
    // Try mailto: as a best-effort to suggest opening an email client
    final mailto = Uri.parse('mailto:${widget.email}');
    try {
      if (await canLaunchUrl(mailto)) {
        await launchUrl(mailto);
      } else {
        // fallback: inform user to open their email app manually
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please open your email app and check the message.')));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open email app.')));
    }
  }

  Future<void> _resendEmail() async {
    setState(() {
      _isResending = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);
      setState(() => _message = 'Verification email resent. Check your inbox.');
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to resend email';
      if (e.code == 'invalid-email') msg = 'Email address is invalid.';
      else if (e.code == 'user-not-found') msg = 'No account found for this email.';
      else if (e.message != null) msg = e.message!;
      setState(() => _message = msg);
    } catch (e) {
      setState(() => _message = 'Error: $e');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _backToLogin() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)]);
    return Scaffold(
      backgroundColor: const Color(0xFF101526),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 20),
              // icon
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF3C8CE7), width: 2),
                ),
                child: const Icon(Icons.lock_outline, size: 56, color: Color(0xFF3C8CE7)),
              ),
              const SizedBox(height: 24),
              const Text('Check your email',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                'We sent a password reset link to',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(widget.email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 28),

              // Open email app button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(14)),
                  child: ElevatedButton(
                    onPressed: _openEmailApp,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                    child: const Text('Open Email App', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Resend
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isResending ? null : _resendEmail,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey.shade700),
                  child: _isResending ? const CircularProgressIndicator(color: Colors.white) : const Text('Resend Link'),
                ),
              ),

              const SizedBox(height: 18),
              if (_message != null) Text(_message!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
              const SizedBox(height: 18),

              TextButton(onPressed: _backToLogin, child: const Text('Back to Login', style: TextStyle(color: Color(0xFF6D5DF6)))),
            ]),
          ),
        ),
      ),
    );
  }
}
