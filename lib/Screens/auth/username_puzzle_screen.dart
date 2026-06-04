import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsernamePuzzleScreen extends StatefulWidget {
  const UsernamePuzzleScreen({super.key});

  @override
  State<UsernamePuzzleScreen> createState() => _UsernamePuzzleScreenState();
}

class _UsernamePuzzleScreenState extends State<UsernamePuzzleScreen>
    with SingleTickerProviderStateMixin {
  final usersRef = FirebaseFirestore.instance.collection('users');

  String generatedId = "";
  bool isDone = false;

  late AnimationController glowController;
  late Animation<double> glowAnim;

  // Fake HEX characters for background grid
  final List<String> hexGrid = List.generate(
    225,
        (_) => "ABCDEF0123456789"[Random().nextInt(16)],
  );

  @override
  void initState() {
    super.initState();

    glowController =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    glowController.dispose();
    super.dispose();
  }

  // ---------- RANDOM ID ----------
  String _randomID() {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    final r = Random();
    return List.generate(7, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<String> _generateUniqueID() async {
    String id = _randomID();
    bool exists = true;

    while (exists) {
      final q = await usersRef.where("username", isEqualTo: id).limit(1).get();
      exists = q.docs.isNotEmpty;
      if (exists) id = _randomID();
    }
    return id;
  }

  void _onDrag(DragUpdateDetails details) async {
    if (isDone) return;

    setState(() => generatedId = "Generating…");

    final id = await _generateUniqueID();

    setState(() {
      generatedId = id;
      isDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    const gradient = LinearGradient(
      colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF101526),

      body: SafeArea(
        child: Center(   // <-- FULL CENTERING OF PUZZLE SCREEN
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // ------------------- TITLE -------------------
              ShaderMask(
                shaderCallback: (rect) => gradient.createShader(rect),
                child: const Text(
                  "Generate Your Whisp ID",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.3,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                "Move your finger inside the box",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 35),

              // ------------------- PUZZLE BOX -------------------
              AnimatedBuilder(
                animation: glowAnim,
                builder: (context, child) {
                  return Container(
                    height: 320,
                    width: 320,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: gradient,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D5DF6)
                              .withOpacity(glowAnim.value * 0.6),
                          blurRadius: 30,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: const Color(0xFF0D1120),
                      ),
                      child: GestureDetector(
                        onPanUpdate: _onDrag,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // ---------- HEX GRID (Threema Style) ----------
                            GridView.count(
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 15,
                              padding: const EdgeInsets.all(14),
                              children: hexGrid
                                  .map(
                                    (c) => Text(
                                  c,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.12),
                                    fontSize: 12,
                                    fontFamily: "monospace",
                                  ),
                                ),
                              )
                                  .toList(),
                            ),

                            // ---------- GENERATED ID ----------
                            Text(
                              generatedId.isEmpty ? "Touch & Move" : generatedId,
                              style: const TextStyle(
                                color: Color(0xFF70FFBE),
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // ------------------- BUTTON -------------------
              if (isDone)
                Container(
                  height: 54,
                  width: 230,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, generatedId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "Use This ID",
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
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
