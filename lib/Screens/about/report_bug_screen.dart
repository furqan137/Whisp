import 'package:flutter/material.dart';

class ReportBugScreen extends StatefulWidget {
  const ReportBugScreen({super.key});

  @override
  State<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends State<ReportBugScreen> {
  final TextEditingController reportController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xff090F21) : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fieldColor = isDark ? const Color(0xFF111A2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Report Bug",
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [

            const SizedBox(height: 15),

            // ---------------------------------------------------------
            // HEADER ICON WITH GLOW
            // ---------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF5350), Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: const Icon(Icons.report_problem, size: 85, color: Colors.white),
            ),

            const SizedBox(height: 25),

            Text(
              "Found a problem?",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              "Tell us something isn't working so we can fix it.",
              style: TextStyle(
                fontSize: 15,
                color: textColor.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            // ---------------------------------------------------------
            // INPUT FIELD
            // ---------------------------------------------------------
            TextField(
              controller: reportController,
              maxLines: 6,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: fieldColor,
                labelText: "Describe the bug",
                labelStyle: TextStyle(color: textColor.withOpacity(0.6)),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ---------------------------------------------------------
            // SEND BUTTON
            // ---------------------------------------------------------
            ElevatedButton(
              onPressed: () {
                if (reportController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Please describe the bug before sending."),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                /// TODO: Send bug report to Firestore or email
                reportController.clear();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Bug report sent successfully!"),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              child: const Text(
                "Send Report",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
