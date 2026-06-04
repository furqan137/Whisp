import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home.dart';

class SecurityQuestion2FA extends StatefulWidget {
  final String uid;

  /// FLOW CONTROLLERS
  final bool isForLoginVerify;       // Login 2FA flow
  final bool isForPasswordReset;     // Forgot password flow
  final Function(Map<String, dynamic>)? onComplete; // Signup flow only

  const SecurityQuestion2FA({
    super.key,
    required this.uid,
    this.isForLoginVerify = false,
    this.isForPasswordReset = false,
    this.onComplete,
  });

  @override
  State<SecurityQuestion2FA> createState() => _SecurityQuestion2FAState();
}

class _SecurityQuestion2FAState extends State<SecurityQuestion2FA> {
  final TextEditingController answerCtrl = TextEditingController();

  bool isLoading = true;
  bool isVerifying = false;

  final List<String> questions = [
    "What is your mother's maiden name?",
    "What was your first pet's name?",
    "What is your favorite color?",
    "What city were you born in?",
    "What is your favorite food?",
  ];

  String? selectedQuestion;
  String hashedCorrectAnswer = "";

  static const Color _bgColor = Color(0xFF101526);
  static const LinearGradient _gradient = LinearGradient(
    colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool get _isSignupFlow => widget.uid.isEmpty;
  bool get _isSettingMode => hashedCorrectAnswer.isEmpty;

  @override
  void initState() {
    super.initState();

    /// SIGNUP → no Firestore load
    if (_isSignupFlow) {
      setState(() {
        isLoading = false;
        hashedCorrectAnswer = ""; // means: setting mode
      });
    } else {
      _loadSecurityData();
    }
  }

  @override
  void dispose() {
    answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSecurityData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .get();

      final data = doc.data() ?? {};

      if (!mounted) return;
      setState(() {
        selectedQuestion = data["securityQuestion"] as String?;
        hashedCorrectAnswer = (data["securityAnswer"] ?? "") as String;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      _showSnack("Error loading: $e");
    }
  }

  // FINAL HASH FORMAT (always lowercase + trimmed)
  String _normalizedHash(String input) {
    return sha256
        .convert(utf8.encode(input.trim().toLowerCase()))
        .toString();
  }

  // ---------------------------- SIGNUP FLOW ----------------------------
  Future<void> _saveForSignupFlow() async {
    final answer = answerCtrl.text.trim();

    if (selectedQuestion == null || answer.isEmpty) {
      _showSnack("Please select a question and enter an answer.");
      return;
    }

    setState(() => isVerifying = true);

    final hashed = _normalizedHash(answer);

    widget.onComplete?.call({
      "question": selectedQuestion!,
      "answer": hashed,
    });

    if (!mounted) return;
    setState(() => isVerifying = false);
  }

  // -------------------------- UPDATE SECURITY Q/A -------------------------
  Future<void> _saveSecurityQA() async {
    final answer = answerCtrl.text.trim();

    if (selectedQuestion == null || answer.isEmpty) {
      _showSnack("Enter your answer");
      return;
    }

    setState(() => isVerifying = true);

    final hashed = _normalizedHash(answer);

    try {
      await FirebaseFirestore.instance.collection("users").doc(widget.uid).set({
        "securityQuestion": selectedQuestion!,
        "securityAnswer": hashed, // final correct storage
        "is2FAEnabled": true,
      }, SetOptions(merge: true));

      hashedCorrectAnswer = hashed; // update local

      _showSnack("Security question saved.");

      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack("Failed: $e");
    } finally {
      if (mounted) setState(() => isVerifying = false);
    }
  }

  // ----------------------------- VERIFY ANSWER -----------------------------
  Future<void> _verifyAnswer() async {
    final answer = answerCtrl.text.trim();

    if (answer.isEmpty) {
      _showSnack("Enter your answer");
      return;
    }

    setState(() => isVerifying = true);

    final hashedInput = _normalizedHash(answer);

    if (hashedInput == hashedCorrectAnswer) {
      await _onVerified();
      return;
    }

    setState(() => isVerifying = false);
    _showSnack("❌ Incorrect answer");
  }

  Future<void> _onVerified() async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (widget.isForLoginVerify) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePageWrapper(forceShowHome: true),
        ),
      );
    } else if (widget.isForPasswordReset) {
      if (mounted) Navigator.pop(context, true);
    } else {
      if (mounted) Navigator.pop(context, true);
    }

    if (mounted) setState(() => isVerifying = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------ UI ------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        title: const Text("Security Verification",
            style: TextStyle(color: Colors.white)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    "Security Question",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 14),

                  // DROPDOWN (disabled during login/reset)
                  AbsorbPointer(
                    absorbing:
                        widget.isForLoginVerify || widget.isForPasswordReset,
                    child: Opacity(
                      opacity:
                          widget.isForLoginVerify || widget.isForPasswordReset
                              ? 0.6
                              : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: _gradient),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: _bgColor,
                            value: selectedQuestion,
                            isExpanded: true,
                            hint: const Text("Choose a question",
                                style: TextStyle(color: Colors.white54)),
                            items: questions
                                .map((q) => DropdownMenuItem(
                                      value: q,
                                      child: Text(q,
                                          style: const TextStyle(
                                              color: Colors.white)),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() => selectedQuestion = v);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ANSWER FIELD
                  Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: _gradient),
                    child: Container(
                      margin: const EdgeInsets.all(2.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: _bgColor),
                      child: TextField(
                        controller: answerCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            hintText: "Enter your answer",
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // BUTTON
                  SizedBox(
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: _gradient),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent),
                        onPressed: isVerifying
                            ? null
                            : () async {
                                if (_isSignupFlow) {
                                  await _saveForSignupFlow();
                                } else if (_isSettingMode) {
                                  await _saveSecurityQA();
                                } else {
                                  await _verifyAnswer();
                                }
                              },
                        child: isVerifying
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(
                                _isSignupFlow
                                    ? "Save & Continue"
                                    : _isSettingMode
                                        ? "Save Security Question"
                                        : "Verify Answer",
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
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
