import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VoiceEffectApiService {
  static const String _endpoint =
      "https://voice-effect-server.onrender.com/voice-effect";

  /// Sends raw recorded WAV to backend
  /// Returns processed WAV (44100hz PCM16 – backend standard)
  static Future<File> applyEffect({
    required File inputFile,
    required String effect,
  }) async {
    final uri = Uri.parse(_endpoint);

    final request = http.MultipartRequest("POST", uri)
      ..fields["effect"] = effect
      ..files.add(
        await http.MultipartFile.fromPath(
          "audio",
          inputFile.path,
          filename: p.basename(inputFile.path),
          contentType: MediaTypeHelper.wav,
        ),
      );

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      final err = await streamedResponse.stream.bytesToString();
      throw Exception("Voice API failed: $err");
    }

    // 🔒 Read raw bytes EXACTLY as backend produced
    final Uint8List audioBytes =
    await streamedResponse.stream.toBytes();

    // 🔑 Always write as .wav (NO re-encoding)
    final dir = await getTemporaryDirectory();
    final outputPath = p.join(
      dir.path,
      "voice_${effect}_${DateTime.now().millisecondsSinceEpoch}.wav",
    );

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(audioBytes, flush: true);

    return outputFile;
  }
}

/// ---- MEDIA TYPE HELPER (NO EXTRA PACKAGE) ----
class MediaTypeHelper {
  static const _wavMime = "audio/wav";

  static http.MediaType get wav =>
      http.MediaType.parse(_wavMime);
}
