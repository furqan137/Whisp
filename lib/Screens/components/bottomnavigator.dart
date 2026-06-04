import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// APP PAGES
import '../Groups/group.dart';
import '../home/home.dart';
import '../chat/startchat.dart';

// NEW PAGES
import '../about/about_app_screen.dart';
import '../about/help_support_screen.dart';
import '../about/report_bug_screen.dart';
import '../settings/settings_screen.dart';
import '../vpn_screen.dart';  // ⭐ ADD VPN SCREEN

// THEME
import '../../theme/theme_provider.dart';

class BottomNavigator extends StatefulWidget {
  static const int homeIndex = 0;
  static const int groupsIndex = 1;
  static const int settingsIndex = 2;
  static const int vpnIndex = 3;      // ⭐ NEW
  static const int aboutIndex = 4;

  final int initialIndex;
  final bool forceShowHome;

  const BottomNavigator({
    Key? key,
    this.initialIndex = homeIndex,
    this.forceShowHome = false,
  }) : super(key: key);

  @override
  State<BottomNavigator> createState() => _BottomNavigatorState();
}

class _BottomNavigatorState extends State<BottomNavigator> {
  int _selectedIndex = 0;
  bool _showStartChat = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    if (widget.forceShowHome) {
      _showStartChat = false;
      _loading = false;
    } else {
      _checkChats();
    }
  }

  Future<void> _checkChats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _showStartChat = false;
        _loading = false;
      });
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collectionGroup('messages')
        .where('fromUid', isEqualTo: user.uid)
        .limit(1)
        .get();

    setState(() {
      _showStartChat = snapshot.docs.isEmpty;
      _loading = false;
    });
  }

  void _onStartChat() {
    setState(() {
      _showStartChat = false;
      _selectedIndex = 0;
    });
  }

  static final List<Widget> _screens = <Widget>[
    const HomePage(),          // 0
    const GroupScreen(),       // 1
    const SettingsScreen(),    // 2
    const VpnScreen(),         // ⭐ 3 — NEW VPN PAGE
    const AboutAppScreen(),    // 4
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;
    final accent = themeProv.accentColor;

    final Color selectedColor = accent;
    final Color unselectedColor = isDark ? Colors.white70 : Colors.black54;

    if (_loading && !widget.forceShowHome) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1220) : Colors.white,

      body: _selectedIndex == 0 && _showStartChat
          ? StartChatPage(onStartChat: _onStartChat)
          : _screens[_selectedIndex],

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0C1220) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, -2),
            )
          ],
        ),

        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,

          backgroundColor: Colors.transparent,
          elevation: 0,

          selectedItemColor: selectedColor,
          unselectedItemColor: unselectedColor,

          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),

          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home, color: selectedColor),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.groups_outlined),
              activeIcon: Icon(Icons.groups, color: selectedColor),
              label: 'Groups',
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings, color: selectedColor),
              label: 'Settings',
            ),

            // ⭐ NEW VPN BUTTON
            BottomNavigationBarItem(
              icon: const Icon(Icons.vpn_lock_outlined),
              activeIcon: Icon(Icons.vpn_lock, color: selectedColor),
              label: 'VPN',
            ),

            BottomNavigationBarItem(
              icon: const Icon(Icons.info_outline),
              activeIcon: Icon(Icons.info, color: selectedColor),
              label: 'About',
            ),
          ],
        ),
      ),
    );
  }
}
