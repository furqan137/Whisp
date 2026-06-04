String formatTimestamp(DateTime time) {
  final now = DateTime.now();
  final difference = now.difference(time);

  if (difference.inSeconds < 60) {
    return "Just now";
  } else if (difference.inMinutes < 60) {
    return "${difference.inMinutes}m ago";
  } else if (difference.inHours < 24) {
    return "${difference.inHours}h ago";
  } else if (difference.inDays < 7) {
    return "${difference.inDays}d ago";
  } else {
    return "${time.day}/${time.month}/${time.year}";
  }
}
