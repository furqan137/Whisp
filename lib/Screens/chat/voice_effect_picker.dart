import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../Service/voice_effect_api_service.dart';

enum VoiceEffect {
  normal,
  male_deep,
  female,
  child,
  robot,
  monster,
  echo,
}

class VoiceEffectPicker extends StatefulWidget {
  final File rawAudio;
  final ValueChanged<File> onApply;
  final VoidCallback onCancel;

  const VoiceEffectPicker({
    super.key,
    required this.rawAudio,
    required this.onApply,
    required this.onCancel,
  });

  @override
  State<VoiceEffectPicker> createState() => _VoiceEffectPickerState();
}

class _VoiceEffectPickerState extends State<VoiceEffectPicker> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  VoiceEffect _selected = VoiceEffect.normal;
  File? _previewFile;

  bool _loading = false;
  bool _isPlaying = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _progressSub;

  // ------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player.openPlayer();

    /// 🔥 REQUIRED for progress updates
    await _player.setSubscriptionDuration(
      const Duration(milliseconds: 200),
    );

    _progressSub = _player.onProgress!.listen((event) {
      if (!mounted) return;
      setState(() {
        _position = event.position;
        _duration = event.duration;
      });
    });
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    _player.closePlayer();
    super.dispose();
  }

  // ------------------------------------------------
  // PREVIEW
  // ------------------------------------------------

  Future<void> _previewEffect(VoiceEffect effect) async {
    setState(() {
      _loading = true;
      _isPlaying = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });

    try {
      final processed = await VoiceEffectApiService.applyEffect(
        inputFile: widget.rawAudio,
        effect: effect.name,
      );

      _previewFile = processed;

      await _player.stopPlayer();

      await _player.startPlayer(
        fromURI: processed.path,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _position = _duration;
            });
          }
        },
      );

      setState(() => _isPlaying = true);
    } catch (e) {
      _showError("Failed to preview voice");
    }

    setState(() => _loading = false);
  }

  Future<void> _togglePlay() async {
    if (_previewFile == null) return;

    if (_isPlaying) {
      await _player.pausePlayer();
    } else {
      await _player.resumePlayer();
    }

    setState(() => _isPlaying = !_isPlaying);
  }

  Future<void> _seek(double value) async {
    await _player.seekToPlayer(
      Duration(milliseconds: value.toInt()),
    );
  }

  // ------------------------------------------------
  // APPLY
  // ------------------------------------------------

  void _apply() {
    if (_previewFile == null) {
      _showError("Preview an effect first");
      return;
    }
    widget.onApply(_previewFile!);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ------------------------------------------------
  // UI
  // ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final maxMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;

    final posMs = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds)
        .toDouble();

    return Center(
      child: Material(
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.92,
          padding: const EdgeInsets.all(20),
          color: theme.cardColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              Row(
                children: [
                  const Icon(Icons.graphic_eq, size: 28),
                  const SizedBox(width: 10),
                  const Text(
                    "Voice Changer",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                  )
                ],
              ),

              const SizedBox(height: 18),

              // EFFECTS
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: VoiceEffect.values.map((e) {
                  final selected = _selected == e;
                  return ChoiceChip(
                    avatar: Icon(
                      _icon(e),
                      size: 18,
                      color: selected ? Colors.white : null,
                    ),
                    label: Text(_label(e)),
                    selected: selected,
                    selectedColor: theme.colorScheme.primary,
                    onSelected: (_) async {
                      setState(() => _selected = e);
                      await _previewEffect(e);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 22),

              // PLAYER
              if (_previewFile != null)
                Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            size: 42,
                          ),
                          onPressed: _togglePlay,
                        ),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: maxMs,
                            value: posMs,
                            onChanged: _seek,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(_position)),
                          Text(_fmt(_duration)),
                        ],
                      ),
                    ),
                  ],
                ),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),

              const SizedBox(height: 20),

              // ACTIONS
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text("Cancel"),
                      onPressed: widget.onCancel,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text("Apply"),
                      onPressed: _apply,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------
  // HELPERS
  // ------------------------------------------------

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(d.inMinutes)}:${two(d.inSeconds % 60)}";
  }

  String _label(VoiceEffect e) {
    switch (e) {
      case VoiceEffect.normal:
        return "Normal";
      case VoiceEffect.male_deep:
        return "Male Deep";
      case VoiceEffect.female:
        return "Female";
      case VoiceEffect.child:
        return "Child";
      case VoiceEffect.robot:
        return "Robot";
      case VoiceEffect.monster:
        return "Monster";
      case VoiceEffect.echo:
        return "Echo";
    }
  }

  IconData _icon(VoiceEffect e) {
    switch (e) {
      case VoiceEffect.normal:
        return Icons.person;
      case VoiceEffect.male_deep:
        return Icons.record_voice_over;
      case VoiceEffect.female:
        return Icons.face_3;
      case VoiceEffect.child:
        return Icons.child_care;
      case VoiceEffect.robot:
        return Icons.smart_toy;
      case VoiceEffect.monster:
        return Icons.bug_report;
      case VoiceEffect.echo:
        return Icons.surround_sound;
    }
  }
}
