import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/login.dart';
import '../../screens/profile_screen.dart';
import '../../screens/notifications_screen.dart';
import '../../theme/theme_provider.dart';

class TopNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const TopNavBar({
    super.key,
    this.title = '',
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
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
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = themeProv.isDarkMode;

    final Color iconColor = isDark ? Colors.white : Colors.black87;

    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF0C1220) : Colors.white,

      title: Text(
        title,
        style: TextStyle(
          color: iconColor,
          fontWeight: FontWeight.w600,
        ),
      ),

      actions: [
        // 🛎 NOTIFICATIONS ICON
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: iconColor),
          tooltip: "Notifications",
          onPressed: () => _openNotifications(context),
        ),

        // 👤 PROFILE ICON
        IconButton(
          icon: Icon(Icons.person_outline, color: iconColor),
          tooltip: "Profile",
          onPressed: () => _openProfileScreen(context),
        ),

        // 🚪 LOGOUT ICON
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: IconButton(
            tooltip: "Logout",
            icon: Icon(Icons.logout, color: themeProv.accentColor),
            onPressed: () => _logout(context),
          ),
        ),
      ],
    );
  }
}
