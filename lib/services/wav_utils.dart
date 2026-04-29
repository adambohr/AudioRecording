import 'dart:io';
import 'dart:typed_data';

/// Utilities for verifying and repairing WAV file headers.
///
/// The `record` package on Android writes the RIFF/data chunk sizes at the
/// start of recording (when the final size is unknown) and is supposed to
/// patch them after stopping. If the process is interrupted, or the device
/// audio driver doesn't flush correctly, those size fields remain 0 and every
/// audio app rejects the file as corrupt.
///
/// Call [repairWavFile] immediately after every recording stops.
class WavUtils {
  /// Ensures [filePath] is a valid WAV file with correct RIFF and data chunk
  /// sizes. Handles three cases:
  ///   1. File has no RIFF header at all (raw PCM) — prepends a full header.
  ///   2. File has a RIFF header but chunk sizes are 0 — patches them.
  ///   3. File is already valid — no-op.
  static Future<void> repairWavFile(
    String filePath, {
    int sampleRate = 44100,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    final bool hasRiff = bytes.length >= 4 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46;   // F

    if (!hasRiff) {
      // Raw PCM — wrap it in a proper WAV container.
      await _writeWithHeader(file, bytes, sampleRate, numChannels, bitsPerSample);
      return;
    }

    // Has RIFF header — check whether the size fields are correct.
    if (bytes.length < 44) {
      // Header is present but truncated; rewrite from scratch.
      final pcm = bytes.length > 44 ? bytes.sublist(44) : Uint8List(0);
      await _writeWithHeader(file, pcm, sampleRate, numChannels, bitsPerSample);
      return;
    }

    final bd = ByteData.sublistView(bytes);
    final riffSize = bd.getUint32(4, Endian.little);
    final expectedRiffSize = bytes.length - 8;

    if (riffSize == 0 || riffSize != expectedRiffSize) {
      final fixed = Uint8List.fromList(bytes);
      final fixedBd = ByteData.sublistView(fixed);

      // Patch RIFF chunk size.
      fixedBd.setUint32(4, expectedRiffSize, Endian.little);

      // Walk the sub-chunks and fix the 'data' chunk size.
      int pos = 12;
      while (pos + 8 <= fixed.length) {
        final id = String.fromCharCodes(fixed.sublist(pos, pos + 4));
        final chunkSize = fixedBd.getUint32(pos + 4, Endian.little);
        if (id == 'data') {
          final expectedDataSize = fixed.length - pos - 8;
          fixedBd.setUint32(pos + 4, expectedDataSize, Endian.little);
          break;
        }
        // Advance; guard against a corrupt chunk size of 0 to avoid looping.
        final advance = chunkSize == 0 ? 1 : chunkSize;
        pos += 8 + advance;
      }

      await file.writeAsBytes(fixed);
    }
  }

  // ---------------------------------------------------------------------------

  static Future<void> _writeWithHeader(
    File file,
    Uint8List pcm,
    int sampleRate,
    int numChannels,
    int bitsPerSample,
  ) async {
    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final dataSize = pcm.length;
    final riffSize = 36 + dataSize;

    final out = Uint8List(44 + dataSize);
    final bd = ByteData.sublistView(out);

    // RIFF descriptor
    out[0] = 0x52; out[1] = 0x49; out[2] = 0x46; out[3] = 0x46; // 'RIFF'
    bd.setUint32(4, riffSize, Endian.little);
    out[8] = 0x57; out[9] = 0x41; out[10] = 0x56; out[11] = 0x45; // 'WAVE'

    // fmt sub-chunk
    out[12] = 0x66; out[13] = 0x6D; out[14] = 0x74; out[15] = 0x20; // 'fmt '
    bd.setUint32(16, 16, Endian.little);            // PCM fmt size
    bd.setUint16(20, 1, Endian.little);             // PCM audio format
    bd.setUint16(22, numChannels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);

    // data sub-chunk
    out[36] = 0x64; out[37] = 0x61; out[38] = 0x74; out[39] = 0x61; // 'data'
    bd.setUint32(40, dataSize, Endian.little);

    out.setAll(44, pcm);
    await file.writeAsBytes(out);
  }
}
