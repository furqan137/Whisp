import 'package:flutter/material.dart';
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
import '../settings/settings_screen.dart';   // << NEW


class BottomNavigator extends StatefulWidget {
  static const int homeIndex = 0;
  static const int groupsIndex = 1;
  static const int settingsIndex = 2;
  static const int aboutIndex = 3;

  final int initialIndex;
  final bool forceShowHome;

  const BottomNavigator({Key? key, this.initialIndex = homeIndex, this.forceShowHome = false}) : super(key: key);

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


  static List<Widget> _screens = <Widget>[
    const HomePage(),
    const GroupScreen(),
    const SettingsScreen(),       // << NEW
    const AboutAppScreen(),
  ];


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }


  @override
  Widget build(BuildContext context) {
    if (_loading && !widget.forceShowHome) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: _selectedIndex == 0 && _showStartChat
          ? StartChatPage(onStartChat: _onStartChat)
          : _screens[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.black54,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            activeIcon: Icon(Icons.groups),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info_outline),
            activeIcon: Icon(Icons.info),
            label: 'About',
          ),
        ],
      ),
    );
  }
}

