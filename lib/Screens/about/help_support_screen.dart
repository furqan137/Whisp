import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xff090F21) : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;
    final tileColor = isDark ? const Color(0xFF111A2E) : Colors.white;

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
          "Help & Support",
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [

            const SizedBox(height: 15),

            // ---------------------------------------------------------
            // HEADER ICON
            // ---------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 14,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: const Icon(Icons.help_outline, size: 80, color: Colors.white),
            ),

            const SizedBox(height: 25),

            Text(
              "How can we help?",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),

            const SizedBox(height: 20),

            // ---------------------------------------------------------
            // FAQ SECTION
            // ---------------------------------------------------------
            _sectionTitle("Frequently Asked Questions", textColor),

            _faqCard(
              question: "How to reset my password?",
              answer:
              "Go to login screen → Tap on 'Forgot Password' → Follow the instructions sent to your email.",
              tileColor: tileColor,
              textColor: textColor,
            ),
            _faqCard(
              question: "How to enable 2FA security?",
              answer:
              "Open Settings → Security → Enable Two-Factor Authentication.",
              tileColor: tileColor,
              textColor: textColor,
            ),
            _faqCard(
              question: "How to report someone?",
              answer:
              "Open their chat → Click options on top right → Select 'Report user'.",
              tileColor: tileColor,
              textColor: textColor,
            ),

            const SizedBox(height: 25),

            _sectionTitle("Need More Help?", textColor),

            Container(
              margin: const EdgeInsets.only(bottom: 30),
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Add email or live chat
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.blueAccent : Colors.black87,
                  padding: const EdgeInsets.symmetric(horizontal: 70, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Contact Support",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // SECTION TITLE
  // ---------------------------------------------------------
  Widget _sectionTitle(String title, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 12),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 20,
            color: textColor.withOpacity(0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // EXPANDABLE FAQ CARD
  // ---------------------------------------------------------
  Widget _faqCard({
    required String question,
    required String answer,
    required Color tileColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        collapsedIconColor: textColor,
        iconColor: textColor,
        title: Text(
          question,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Container(
            padding: const EdgeInsets.only(
                left: 16, right: 16, bottom: 14),
            child: Text(
              answer,
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          )
        ],
      ),
    );
  }
}
