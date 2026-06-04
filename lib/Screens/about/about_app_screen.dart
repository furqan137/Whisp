import 'package:flutter/material.dart';
import 'help_support_screen.dart';
import 'report_bug_screen.dart';
import '../privacy_policy_screen.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark ? const Color(0xff090F21) : Colors.grey.shade100;
    final textColor = isDark ? Colors.white : Colors.black87;
    final tileColor = isDark ? const Color(0xFF111A2E) : Colors.white;

    return Scaffold(
      backgroundColor: bg,

      // 🔥 CLEAN APP BAR (NO BACK ICON)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // ❌ remove back arrow
        title: Text(
          "About Whisp",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Column(
          children: [

            const SizedBox(height: 10),

            // ---------------------------------------------------------
            // APP ICON / LOGO
            // ---------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6D5DF6), Color(0xFF3C8CE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: const Icon(Icons.lock_outline,
                  size: 80, color: Colors.white),
            ),

            const SizedBox(height: 22),

            Text(
              "Whisp Secure Chat",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "Private • Fast • Anonymous",
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 30),

            // ---------------------------------------------------------
            // APP INFO
            // ---------------------------------------------------------
            _infoCard(
              title: "Version",
              value: "1.0.0",
              tileColor: tileColor,
              textColor: textColor,
            ),
            _infoCard(
              title: "Developer",
              value: "Furqan Zafar",
              tileColor: tileColor,
              textColor: textColor,
            ),

            const SizedBox(height: 24),

            // ---------------------------------------------------------
            // SUPPORT & REPORT
            // ---------------------------------------------------------
            _navTile(
              icon: Icons.help_outline,
              title: "Help & Support",
              context: context,
              tileColor: tileColor,
              textColor: textColor,
              screen: const HelpSupportScreen(),
            ),

            _navTile(
              icon: Icons.bug_report_outlined,
              title: "Report a Bug",
              context: context,
              tileColor: tileColor,
              textColor: textColor,
              screen: const ReportBugScreen(),
            ),

            const SizedBox(height: 36),

            // ---------------------------------------------------------
            // PRIVACY POLICY
            // ---------------------------------------------------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  isDark ? Colors.blueAccent : Colors.black,
                  padding:
                  const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Privacy Policy",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // INFO CARD
  // ---------------------------------------------------------
  Widget _infoCard({
    required String title,
    required String value,
    required Color tileColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor.withOpacity(0.65),
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // NAV TILE
  // ---------------------------------------------------------
  Widget _navTile({
    required IconData icon,
    required String title,
    required BuildContext context,
    required Color tileColor,
    required Color textColor,
    required Widget screen,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: textColor.withOpacity(0.6),
          size: 16,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => screen),
          );
        },
      ),
    );
  }
}
