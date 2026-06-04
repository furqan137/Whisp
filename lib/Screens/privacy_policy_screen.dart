import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xff090F21) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Privacy Policy",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: SingleChildScrollView(
          child: Text(
            _policyText,
            style: TextStyle(
              color: textColor.withOpacity(0.9),
              height: 1.5,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------
// ⚠️ LONG PRIVACY POLICY TEXT BELOW
// ----------------------------------
const String _policyText = """
Last updated: January 2025

This Privacy Policy explains how we collect, use, store, and protect your information when you use our Secure Chat App. By using the app, you agree to the terms described below.

------------------------------------------------------------
1. Information We Collect
------------------------------------------------------------
We may collect the following types of information:
• Account Information – your username, display name, and profile picture.
• Contact Data – only the user IDs you chat with (NOT your phone contacts).
• Messages – all messages are encrypted end-to-end and stored securely.
• Media Files – images, videos, audio, and documents you send.
• Device Information – basic data like your device model, OS version, and app version.
• Usage Data – crash reports, diagnostic logs, and general app activity.

We DO NOT collect:
✘ phone contacts  
✘ location  
✘ IP tracking  
✘ sensitive personal data  

------------------------------------------------------------
2. How We Use Your Information
------------------------------------------------------------
We use collected information for:
• Delivering chat messages  
• Improving app performance  
• Preventing fraud and abuse  
• Fixing bugs and enhancing security  
• Cloud backup of your encrypted messages & media  

Your data is NEVER sold or shared with third-party advertisers.

------------------------------------------------------------
3. End-to-End Encryption
------------------------------------------------------------
All messages exchanged in the app are encrypted using a private key generated between you and the user you chat with.  
We CANNOT:
• Read your messages  
• Access your media  
• Decrypt your conversations  

Only you and the person you chat with can read the content.

------------------------------------------------------------
4. Cloud Storage
------------------------------------------------------------
Profile images, media files, and encrypted messages may be stored on secure servers.  
We make sure this storage meets international security standards.

------------------------------------------------------------
5. User Rights
------------------------------------------------------------
You have the right to:
• Access and review your stored data  
• Delete your account  
• Request deletion of message history  
• Change your profile details  
• Block or report users  

------------------------------------------------------------
6. Account Deletion
------------------------------------------------------------
When you delete your account:
• All chats are permanently removed  
• Media files are deleted from cloud storage  
• Your profile data is erased  
This process cannot be undone.

------------------------------------------------------------
7. Children’s Privacy
------------------------------------------------------------
This app is not intended for children under 13.  
We do not knowingly collect data from minors.

------------------------------------------------------------
8. Security Measures
------------------------------------------------------------
We implement industry-level security including:
• AES / RSA encryption  
• Secure servers  
• Firewall protection  
• Encrypted connections (HTTPS)  
• Two-factor authentication (coming soon)  

------------------------------------------------------------
9. Third-Party Services
------------------------------------------------------------
Some services used:
• Cloud storage providers  
• Authentication services  
• Crash analytics  

We ensure all third-party services follow strict security requirements.

------------------------------------------------------------
10. Changes to Privacy Policy
------------------------------------------------------------
We may update this Privacy Policy occasionally.  
You will be notified inside the app if major changes occur.

------------------------------------------------------------
11. Contact Us
------------------------------------------------------------
If you have questions or concerns, reach out at:

Email: support@securechat.com  
Website: www.securechat.com  

Thank you for using Secure Chat App and trusting us with your privacy.
""";
