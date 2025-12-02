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
  int _selectedDuration = 5;
  final List<int> _durations = [5, 10, 60];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Color(0xFF5B5FE9),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send Self-Destruct Message',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                )),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.hasMedia ? Icons.image : Icons.message, color: Color(0xFF5B5FE9)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.messagePreview.isEmpty ? 'No text entered' : widget.messagePreview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 22),
            Text('Choose timer:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _durations.map((d) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(d == 60 ? '1m' : '${d}s', style: TextStyle(color: _selectedDuration == d ? Colors.white : Color(0xFF5B5FE9), fontWeight: FontWeight.bold)),
                  selected: _selectedDuration == d,
                  selectedColor: Color(0xFF7F53AC),
                  backgroundColor: Colors.white,
                  onSelected: (_) => setState(() => _selectedDuration = d),
                  elevation: 2,
                ),
              )).toList(),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.local_fire_department, color: Colors.white),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                label: Text('Send Self-Destruct Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onPressed: () {
                  widget.onSend(_selectedDuration);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
