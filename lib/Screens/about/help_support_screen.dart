import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

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

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline, size: 80, color: Colors.blue),
          ),

          const SizedBox(height: 20),

          const Text(
            "Help & Support",
            style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 40),

          ListTile(
            title: const Text("FAQs", style: TextStyle(color: Colors.white, fontSize: 17)),
            trailing: Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.8), size: 18),
          ),

          const Spacer(),

          Container(
            margin: const EdgeInsets.only(bottom: 40),
            child: ElevatedButton(
              onPressed: () {
                // Email support or open chat support later
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Contact Support"),
            ),
          ),
        ],
      ),
    );
  }
}
