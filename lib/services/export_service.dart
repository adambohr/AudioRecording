import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recording.dart';

class ExportService {
  /// Exports all recordings to sonohaler_master_log.csv in the device's public
  /// Documents folder, then opens the system share sheet.
  ///
  /// Returns the absolute path of the written file.
  Future<String> exportToCsv(List<Recording> recordings) async {
    final List<List<dynamic>> rows = [];

    // Header
    rows.add([
      'id',
      'file_id',
      'inhaler_type',
      'flow_rate_lpm',
      'actuations',
      'is_inhalation',
      'background_noise',
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
        rec.inhalerType,
        rec.flowRate,
        rec.actuations,
        rec.isInhalation ? 'Yes' : 'No',
        rec.environment,
        rec.doseMg,
        rec.distanceCm,
        rec.durationSec,
        rec.timestamp.toIso8601String(),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);

    // Write to public Documents folder so the file is immediately visible in
    // any file manager. Fall back to app-documents dir on non-Android.
    final Directory saveDir;
    if (Platform.isAndroid) {
      saveDir = Directory('/storage/emulated/0/Documents');
    } else {
      final base = await getApplicationDocumentsDirectory();
      saveDir = Directory(p.join(base.path, 'SonohalerLab'));
    }

    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    const fileName = 'sonohaler_master_log.csv';
    final filePath = p.join(saveDir.path, fileName);
    await File(filePath).writeAsString(csvData);

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'text/csv')],
      subject: 'Sonohaler Lab — Master Log Export',
    );

    return filePath;
  }
}
