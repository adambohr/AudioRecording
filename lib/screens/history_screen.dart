import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _dbService = DatabaseService();
  final ExportService _exportService = ExportService();

  List<Recording> _recordings = [];
  bool _isLoading = true;
  bool _isExporting = false;

  // Column widths (px) — keep in sync between header and rows
  static const double _wId       = 36;
  static const double _wFileId   = 100;
  static const double _wInhaler  = 88;
  static const double _wFlow     = 64;
  static const double _wAct      = 56;
  static const double _wInhal    = 60;
  static const double _wNoise    = 68;
  static const double _wDose     = 64;
  static const double _wDist     = 60;
  static const double _wDur      = 52;
  static const double _wDel      = 40;
  static const double _colGap    = 6;

  static String _fmtDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    setState(() => _isLoading = true);
    try {
      final recs = await _dbService.getAllRecordings();
      setState(() {
        _recordings = recs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load recordings: $e', isError: true);
    }
  }

  Future<void> _exportCsv() async {
    if (_recordings.isEmpty) {
      _showSnackBar('No recordings to export.', isError: true);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final path = await _exportService.exportToCsv(_recordings);
      _showSnackBar('Exported: $path');
    } catch (e) {
      _showSnackBar('Export failed: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _deleteRecording(Recording recording) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2E3A),
        title: const Text('Delete Recording',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${recording.fileId}.wav from the database?\n'
          'The audio file on storage will not be deleted.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );

    if (confirmed == true && recording.id != null) {
      await _dbService.deleteRecording(recording.id!);
      _loadRecordings();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _cell(String text, double width,
      {Color color = Colors.white70, bool mono = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontFamily: mono ? 'monospace' : null,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _headerCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _gap() => const SizedBox(width: _colGap);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F2D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recording History',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        Text('SQLite metadata store',
                            style: TextStyle(
                                color: Colors.tealAccent, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loadRecordings,
                    icon: const Icon(Icons.refresh_rounded,
                        color: Colors.white54),
                    tooltip: 'Refresh',
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: _isExporting ? null : _exportCsv,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isExporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Export CSV',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),

            // Stats bar
            if (_recordings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.tealAccent.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statChip('Total', '${_recordings.length}'),
                      _statChip(
                          'Duration',
                          '${_recordings.fold(0, (s, r) => s + r.durationSec)}s'),
                      _statChip(
                          'Latest',
                          _recordings.isNotEmpty
                              ? _fmtDate(_recordings.first.timestamp)
                              : '—'),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Scrollable data table
            if (!_isLoading && _recordings.isNotEmpty) ...[
              // Table header
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A2E3A),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _headerCell('#', _wId),
                      _gap(),
                      _headerCell('File ID', _wFileId),
                      _gap(),
                      _headerCell('Inhaler', _wInhaler),
                      _gap(),
                      _headerCell('Flow\n(LPM)', _wFlow),
                      _gap(),
                      _headerCell('Act.', _wAct),
                      _gap(),
                      _headerCell('Inhal.', _wInhal),
                      _gap(),
                      _headerCell('Noise', _wNoise),
                      _gap(),
                      _headerCell('Dose\n(mg)', _wDose),
                      _gap(),
                      _headerCell('Dist\n(cm)', _wDist),
                      _gap(),
                      _headerCell('Dur\n(s)', _wDur),
                      _gap(),
                      SizedBox(width: _wDel),
                    ],
                  ),
                ),
              ),
            ],

            // Table body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.tealAccent))
                  : _recordings.isEmpty
                      ? _buildEmptyState()
                      : Container(
                          margin:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF152535),
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10)),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(10)),
                            child: ListView.separated(
                              itemCount: _recordings.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: Colors.white12),
                              itemBuilder: (ctx, index) {
                                final rec = _recordings[index];
                                return _buildRow(rec);
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(Recording rec) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _cell('${rec.id ?? ''}', _wId,
                color: Colors.white38),
            _gap(),
            _cell(rec.fileId, _wFileId,
                color: Colors.white, mono: true),
            _gap(),
            _cell(rec.inhalerType, _wInhaler),
            _gap(),
            _cell('${rec.flowRate}', _wFlow),
            _gap(),
            _cell(rec.actuations, _wAct),
            _gap(),
            _cell(rec.isInhalation ? 'Yes' : 'No', _wInhal,
                color: rec.isInhalation
                    ? Colors.tealAccent
                    : Colors.white54),
            _gap(),
            _cell(rec.environment, _wNoise),
            _gap(),
            _cell('${rec.doseMg}', _wDose),
            _gap(),
            _cell('${rec.distanceCm}', _wDist),
            _gap(),
            _cell('${rec.durationSec}', _wDur),
            _gap(),
            SizedBox(
              width: _wDel,
              child: IconButton(
                onPressed: () => _deleteRecording(rec),
                icon: const Icon(Icons.delete_outline,
                    color: Colors.red, size: 17),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Delete entry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_off_outlined, size: 56, color: Colors.white24),
          const SizedBox(height: 14),
          const Text('No recordings yet',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
              'Switch to the Record tab to start capturing data.',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.tealAccent,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        Text(label,
            style:
                const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }
}
