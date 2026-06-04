import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? additionalActions;
  final VoidCallback? onMorePressed;

  const ChatAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.additionalActions,
    this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 1,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white, // 🔥 important for Android 12+
      titleSpacing: 0,

      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),

      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
        ],
      ),

      actions: [
        if (additionalActions != null) ...additionalActions!,
        if (onMorePressed != null)
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: onMorePressed,
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(60);
}
