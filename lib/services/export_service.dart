import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/recording.dart';

class ExportService {
  /// Exports all recordings to a CSV file and shares it.
  /// Returns the path of the exported file on success.
  Future<String> exportToCsv(List<Recording> recordings) async {
    final List<List<dynamic>> rows = [];

    // Header row
    rows.add([
      'id',
      'file_id',
      'flow_rate_lpm',
      'environment',
      'dose_mg',
      'distance_cm',
      'duration_sec',
      'timestamp',
    ]);

    // Data rows
    for (final rec in recordings) {
      rows.add([
        rec.id ?? '',
        rec.fileId,
        rec.flowRate,
        rec.environment,
        rec.doseMg,
        rec.distanceCm,
        rec.durationSec,
        rec.timestamp.toIso8601String(),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);

    // Save to external storage Documents folder if available, else app docs
    Directory? saveDir;
    try {
      final externalDirs = await getExternalStorageDirectories(
        type: StorageDirectory.documents,
      );
      saveDir = externalDirs?.first;
    } catch (_) {}

    saveDir ??= await getApplicationDocumentsDirectory();

    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final filePath = p.join(saveDir.path, 'sonohaler_metadata.csv');
    final file = File(filePath);
    await file.writeAsString(csvData);

    // Share / open the file so the user can save it elsewhere
    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'text/csv')],
      subject: 'Sonohaler Lab Metadata Export',
    );

    return filePath;
  }
}
