import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityQuestion2FA extends StatefulWidget {
  final String uid;

  /// FLOW CONTROLLERS
  final bool isForLoginVerify;     // login verification
  final bool isForPasswordReset;   // forgot password
  final Function(Map<String, dynamic>)? onComplete; // only for signup

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

  List<String> questions = [
    "What is your mother's maiden name?",
    "What was your first pet's name?",
    "What is your favorite color?",
    "What city were you born in?",
    "What is your favorite food?",
  ];

  String? selectedQuestion;
  String hashedCorrectAnswer = "";

  @override
  void initState() {
    super.initState();
    if (widget.uid.isEmpty) {
      // Signup flow: no user yet, skip loading
      setState(() {
        isLoading = false;
        selectedQuestion = null;
        hashedCorrectAnswer = "";
      });
    } else {
      _loadSecurityData();
    }
  }

  Future<void> _loadSecurityData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .get();

      final data = userDoc.data() ?? {};

      setState(() {
        selectedQuestion = data['securityQuestion'];
        hashedCorrectAnswer = data['securityAnswer'] ?? "";
        isLoading = false;
      });
    } catch (e) {
      _showSnack("Error loading data: $e");
      isLoading = false;
    }
  }

  String _hash(String input) {
    return sha256.convert(utf8.encode(input.trim().toLowerCase())).toString();
  }

  /// --------------------- SIGNUP FLOW ----------------------
  Future<void> _saveSecurityQA() async {
    if (selectedQuestion == null || answerCtrl.text.trim().isEmpty) {
      _showSnack("Please select a question and enter your answer.");
      return;
    }

    setState(() => isVerifying = true);

    final hashed = _hash(answerCtrl.text.trim());

    if (widget.uid.isEmpty) {
      // Signup flow: just return data, do not update Firestore
      Future.delayed(const Duration(milliseconds: 400), () {
        if (widget.onComplete != null) {
          widget.onComplete!({
            "question": selectedQuestion,
            "answer": hashed,
          });
        }
      });
      setState(() => isVerifying = false);
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .update({
        "securityQuestion": selectedQuestion,
        "securityAnswer": hashed,
        "is2FAEnabled": true,
      });

      _showSnack("✔ Security Question Set Successfully!");

      Future.delayed(const Duration(milliseconds: 400), () {
        if (widget.onComplete != null) {
          widget.onComplete!({
            "question": selectedQuestion,
            "answer": hashed,
          });
        }
      });
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      setState(() => isVerifying = false);
    }
  }

  /// -------------------- LOGIN & FORGOT PASSWORD ---------------------
  Future<void> _verifyAnswer() async {
    if (answerCtrl.text.trim().isEmpty) {
      _showSnack("Enter your answer");
      return;
    }

    setState(() => isVerifying = true);

    final inputHash = _hash(answerCtrl.text.trim());

    await Future.delayed(const Duration(milliseconds: 500));

    if (inputHash != hashedCorrectAnswer) {
      _showSnack("❌ Incorrect answer");
      setState(() => isVerifying = false);
      return;
    }

    /// LOGIN FLOW
    if (widget.isForLoginVerify) {
      _showSnack("✔ Verified");
      Navigator.pushReplacementNamed(context, "/home");
    }

    /// FORGOT PASSWORD FLOW
    else if (widget.isForPasswordReset) {
      Navigator.pop(context, true); // return success
    }

    setState(() => isVerifying = false);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF101526);
    const gradient = LinearGradient(
      colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)],
    );

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text("Security Verification",
            style: TextStyle(color: Colors.white)),
      ),

      /// FIXED → Added scrolling to avoid RenderFlex Overflow
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Security Question",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: gradient,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: bgColor,
                  value: selectedQuestion,
                  hint: const Text("Choose a question",
                      style: TextStyle(color: Colors.white54)),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down,
                      color: Colors.white70),
                  items: questions.map((q) {
                    return DropdownMenuItem(
                      value: q,
                      child: Text(q,
                          style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() => selectedQuestion = v);
                  },
                ),
              ),
            ),

            const SizedBox(height: 25),

            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: gradient,
              ),
              child: Container(
                margin: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: bgColor,
                ),
                child: TextField(
                  controller: answerCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Enter your answer",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 35),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : hashedCorrectAnswer.isEmpty
                      ? _saveSecurityQA
                      : _verifyAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: isVerifying
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    hashedCorrectAnswer.isEmpty
                        ? "Save & Continue"
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
