import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  final _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

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
      _showSnackBar('Exported to: $path');
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
          'Delete ${recording.fileId}.wav from the database?\nThe audio file will not be deleted.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F2D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.tealAccent.withOpacity(0.2)),
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
                              ? _dateFormat
                                  .format(_recordings.first.timestamp)
                              : '—'),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Table header
            if (!_isLoading && _recordings.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2E3A),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 32),
                    Expanded(
                        flex: 3,
                        child: _HeaderCell('File ID')),
                    Expanded(
                        flex: 2,
                        child: _HeaderCell('Flow (LPM)')),
                    Expanded(
                        flex: 2,
                        child: _HeaderCell('Noise')),
                    Expanded(
                        flex: 2,
                        child: _HeaderCell('Dose (mg)')),
                    Expanded(
                        flex: 2,
                        child: _HeaderCell('Dist (cm)')),
                    Expanded(
                        flex: 2,
                        child: _HeaderCell('Dur (s)')),
                    SizedBox(width: 40),
                  ],
                ),
              ),

            // Table body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Colors.tealAccent))
                  : _recordings.isEmpty
                      ? _buildEmptyState()
                      : Container(
                          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                                return _RecordingRow(
                                  recording: rec,
                                  onDelete: () => _deleteRecording(rec),
                                );
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_off_outlined, size: 56, color: Colors.white24),
          const SizedBox(height: 14),
          const Text('No recordings yet',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Switch to the Record tab to start capturing data.',
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

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5),
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _RecordingRow extends StatelessWidget {
  final Recording recording;
  final VoidCallback onDelete;

  const _RecordingRow({required this.recording, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${recording.id ?? ''}',
              style:
                  const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              recording.fileId,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${recording.flowRate}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              recording.environment,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${recording.doseMg}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${recording.distanceCm}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${recording.durationSec}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Delete entry',
            ),
          ),
        ],
      ),
    );
  }
}
