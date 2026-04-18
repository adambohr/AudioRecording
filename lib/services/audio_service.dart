import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentFilePath;

  /// Generates a unique file ID in format SH_XXXXX
  String generateFileId() {
    final random = Random();
    final number = random.nextInt(90000) + 10000;
    return 'SH_$number';
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Starts recording using unprocessed audio source (disables AGC and noise suppression)
  /// Returns the generated file ID for this recording session.
  Future<String> startRecording() async {
    // Save to public Downloads/SonohalerLab on Android so files are visible
    // in any file manager without root or ADB.
    Directory recordingsDir;
    if (!kIsWeb && Platform.isAndroid) {
      recordingsDir = Directory('/storage/emulated/0/Download/SonohalerLab');
    } else {
      final base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      recordingsDir = Directory(p.join(base.path, 'SonohalerLab'));
    }

    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }

    final fileId = generateFileId();
    _currentFilePath = p.join(recordingsDir.path, '$fileId.wav');

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.unprocessed,
          muteAudio: false,
        ),
      ),
      path: _currentFilePath!,
    );

    return fileId;
  }

  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    return path;
  }

  Future<void> cancelRecording() async {
    final path = await _recorder.stop();
    final toDelete = path ?? _currentFilePath;
    _currentFilePath = null;
    if (toDelete != null) {
      final f = File(toDelete);
      if (await f.exists()) await f.delete();
    }
  }

  String? get currentFilePath => _currentFilePath;

  void dispose() {
    _recorder.dispose();
  }
}
