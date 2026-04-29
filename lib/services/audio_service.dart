import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'wav_utils.dart';

class AudioService {
  AudioRecorder _recorder = AudioRecorder();
  String? _currentFilePath;

  static const int _sampleRate = 44100;
  static const int _numChannels = 1;
  static const int _bitsPerSample = 16;

  /// Generates a unique file ID in format SH_XXXXX
  String generateFileId() {
    final random = Random();
    final number = random.nextInt(90000) + 10000;
    return 'SH_$number';
  }

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  /// Starts recording. Tries UNPROCESSED source first (disables AGC / noise
  /// suppression). Falls back to DEFAULT_MICROPHONE if the device does not
  /// support UNPROCESSED, so recording always succeeds.
  Future<String> startRecording() async {
    // Use public Downloads/SonohalerLab on Android so files are visible in
    // any file manager without root or ADB.
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

    // Try UNPROCESSED first; fall back to default mic if unsupported.
    bool started = await _tryStart(
      AndroidAudioSource.unprocessed,
      _currentFilePath!,
    );

    if (!started) {
      // Re-create recorder — a failed start leaves the instance in a bad state.
      await _recorder.dispose();
      _recorder = AudioRecorder();
      started = await _tryStart(
        AndroidAudioSource.defaultSource,
        _currentFilePath!,
      );
    }

    if (!started) {
      throw Exception(
          'Could not start recording with either UNPROCESSED or DEFAULT audio source.');
    }

    return fileId;
  }

  Future<bool> _tryStart(
    AndroidAudioSource source,
    String path,
  ) async {
    try {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: _numChannels,
          androidConfig: AndroidRecordConfig(
            audioSource: source,
            muteAudio: false,
          ),
        ),
        path: path,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Stops recording, then repairs the WAV header to ensure the file is
  /// playable regardless of whether the record package wrote correct sizes.
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    if (path != null) {
      await WavUtils.repairWavFile(
        path,
        sampleRate: _sampleRate,
        numChannels: _numChannels,
        bitsPerSample: _bitsPerSample,
      );
    }
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
