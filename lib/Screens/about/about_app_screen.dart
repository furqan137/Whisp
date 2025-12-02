import 'package:flutter/material.dart';
import 'help_support_screen.dart';
import 'report_bug_screen.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff090F21),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 15),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.apps, size: 80, color: Colors.blue),
          ),

          const SizedBox(height: 20),

          const Text(
            "About App",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),

          const SizedBox(height: 40),

          ListTile(
            title: const Text("Version", style: TextStyle(color: Colors.white70, fontSize: 17)),
            trailing: const Text("1.0.0", style: TextStyle(color: Colors.white, fontSize: 17)),
          ),

          ListTile(
            title: const Text("Developer", style: TextStyle(color: Colors.white70, fontSize: 17)),
            trailing: const Text("Furqan Zafar", style: TextStyle(color: Colors.white, fontSize: 17)),
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white24),

          // 👉 Help Support
          ListTile(
            leading: const Icon(Icons.help_outline, color: Colors.white),
            title: const Text("Help & Support", style: TextStyle(color: Colors.white, fontSize: 18)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
              );
            },
          ),

          // 👉 Report Bug
          ListTile(
            leading: const Icon(Icons.report, color: Colors.white),
            title: const Text("Report Bug", style: TextStyle(color: Colors.white, fontSize: 18)),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportBugScreen()),
              );
            },
          ),

          const Spacer(),

          Container(
            margin: const EdgeInsets.only(bottom: 40),
            child: ElevatedButton(
              onPressed: () {

              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Privacy Policy"),
            ),
          )
        ],
      ),
    );
  }
}
