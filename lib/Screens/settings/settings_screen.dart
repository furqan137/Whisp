import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String selectedChatTheme = "Blue";

  final List<String> chatThemes = [
    "Blue",
    "Purple",
    "Green",
    "Red",
    "Orange",
  ];

  @override
  Widget build(BuildContext context) {
    // Access ThemeProvider
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.isDarkMode ? const Color(0xff090F21) : Colors.white,

      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: themeProvider.isDarkMode ? Colors.white : Colors.black,
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const SizedBox(height: 20),

          // -------------------- App Theme Switch --------------------
          SwitchListTile(
            value: themeProvider.isDarkMode,
            activeColor: Colors.blue,
            title: Text(
              "Dark Theme",
              style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                fontSize: 18,
              ),
            ),
            onChanged: (value) {
              themeProvider.toggleTheme(value); // Apply theme immediately
            },
          ),

          const Divider(color: Colors.white24),

          const Padding(
            padding: EdgeInsets.only(left: 15, top: 25, bottom: 10),
            child: Text(
              "Chat Theme",
              style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: ListView.builder(
              itemCount: chatThemes.length,
              itemBuilder: (context, index) {
                String themeName = chatThemes[index];

                return ListTile(
                  title: Text(
                    themeName,
                    style: TextStyle(
                      color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  trailing: selectedChatTheme == themeName
                      ? Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    setState(() {
                      selectedChatTheme = themeName;
                    });

                    // TODO: store this in Firestore later
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
