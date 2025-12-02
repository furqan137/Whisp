import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login.dart';
import '../../screens/profile_screen.dart';
import '../../screens/notifications_screen.dart';

class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  final Color backgroundColor;
  final Color iconColor;
  final String title;

  const TopNavBar({
    super.key,
    this.backgroundColor = Colors.transparent,
    this.iconColor = Colors.white,
    this.title = '',
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  void _openNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openProfileScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      title: Text(title, style: TextStyle(color: iconColor)),
      actions: [
        IconButton(
          icon: Icon(Icons.notifications, color: iconColor),
          onPressed: () => _openNotifications(context),
        ),
        IconButton(
          icon: Icon(Icons.person, color: iconColor),
          onPressed: () => _openProfileScreen(context), // directly open ProfileScreen
        ),
        IconButton(
          icon: Icon(Icons.logout, color: Colors.redAccent),
          onPressed: () => _logout(context),
        ),
      ],
    );
  }
}
