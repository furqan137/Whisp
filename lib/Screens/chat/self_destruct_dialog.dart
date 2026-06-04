import 'package:flutter/material.dart';

class SelfDestructDialog extends StatefulWidget {
  final String messagePreview;
  final Function(int) onSend;
  final bool hasMedia;

  const SelfDestructDialog({
    Key? key,
    required this.messagePreview,
    required this.onSend,
    this.hasMedia = false,
  }) : super(key: key);

  @override
  State<SelfDestructDialog> createState() => _SelfDestructDialogState();
}

class _SelfDestructDialogState extends State<SelfDestructDialog> {
  int _selectedDuration = 10; // default like screenshot

  final List<int> _durations = [5, 10, 60];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Title
            Text(
              "Self-Destruct Message",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            SizedBox(height: 20),

            // Preview Box
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.messagePreview.isEmpty
                    ? "This is a self-destructing message."
                    : widget.messagePreview,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),

            SizedBox(height: 28),

            // Timer segmented UI
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _durations.map((d) {
                  bool selected = _selectedDuration == d;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedDuration = d),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 160),
                      padding: EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 22,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: selected
                            ? Border.all(color: Colors.redAccent, width: 2)
                            : null,
                      ),
                      child: Text(
                        d == 60 ? "1m" : "${d}s",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: 32),

            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  widget.onSend(_selectedDuration);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.black87, width: 1.4),
                  padding: EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "Send",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
