import 'dart:async';
import 'package:flutter/material.dart';
import '../models/recording.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  final DatabaseService _dbService = DatabaseService();

  // Dropdown values
  int _selectedFlowRate = 30;
  String _selectedEnvironment = 'Quiet';
  int _selectedDose = 0;
  int _selectedDistance = 10;
  int _selectedDuration = 10;

  // Recording state
  bool _isRecording = false;
  bool _isSaving = false;
  int _secondsRemaining = 0;
  int _secondsElapsed = 0;
  Timer? _timer;
  String? _currentFileId;
  String? _lastSavedFileId;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const List<int> _flowRates = [10, 20, 30, 40, 50, 60, 70, 80, 90];
  static const List<String> _environments = ['Quiet', 'Low', 'Medium', 'High'];
  static const List<int> _doses = [0, 10, 20, 30, 40, 50, 60];
  static const List<int> _distances = [5, 10, 20, 30];
  static const List<int> _durations = [5, 10, 15];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.stop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioService.hasPermission();
    if (!hasPermission) {
      _showSnackBar('Microphone permission denied. Please enable it in Settings.', isError: true);
      return;
    }

    setState(() {
      _isRecording = true;
      _secondsRemaining = _selectedDuration;
      _secondsElapsed = 0;
      _lastSavedFileId = null;
    });

    _pulseController.repeat(reverse: true);

    try {
      _currentFileId = await _audioService.startRecording();
    } catch (e) {
      setState(() => _isRecording = false);
      _pulseController.stop();
      _showSnackBar('Failed to start recording: $e', isError: true);
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
        _secondsRemaining--;
      });
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _stopAndSave();
      }
    });
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isRecording = false;
      _isSaving = true;
    });

    try {
      await _audioService.stopRecording();

      final recording = Recording(
        fileId: _currentFileId!,
        flowRate: _selectedFlowRate,
        environment: _selectedEnvironment,
        doseMg: _selectedDose,
        distanceCm: _selectedDistance,
        durationSec: _secondsElapsed,
        timestamp: DateTime.now(),
      );

      await _dbService.insertRecording(recording);

      setState(() {
        _lastSavedFileId = _currentFileId;
        _isSaving = false;
      });

      _showSnackBar('Saved: ${_currentFileId!}.wav');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Error saving recording: $e', isError: true);
    }
  }

  Future<void> _cancelRecording() async {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    await _audioService.cancelRecording();
    setState(() {
      _isRecording = false;
      _secondsRemaining = 0;
      _secondsElapsed = 0;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.teal.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required void Function(T?) onChanged,
    String Function(T)? labelBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
                letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            dropdownColor: const Color(0xFF1A2E3A),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.tealAccent),
            items: items.map((item) {
              final text = labelBuilder != null ? labelBuilder(item) : item.toString();
              return DropdownMenuItem<T>(
                value: item,
                child: Text(text),
              );
            }).toList(),
            onChanged: _isRecording ? null : onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordButton() {
    if (_isRecording) {
      return Column(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: GestureDetector(
              onTap: _stopAndSave,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.shade600,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.stop_rounded, color: Colors.white, size: 44),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.cancel_outlined, color: Colors.white54, size: 18),
            label: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _isSaving ? null : _startRecording,
      child: Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: _isSaving
                ? [Colors.grey.shade600, Colors.grey.shade700]
                : [Colors.tealAccent.shade400, Colors.teal.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.tealAccent.withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: _isSaving
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Icon(Icons.mic_rounded, color: Colors.white, size: 44),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _selectedDuration > 0
        ? _secondsElapsed / _selectedDuration
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1F2D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.tealAccent.withOpacity(0.15),
                    ),
                    child: const Icon(Icons.graphic_eq,
                        color: Colors.tealAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sonohaler Lab',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text('Acoustic Data Collection',
                          style: TextStyle(
                              color: Colors.tealAccent, fontSize: 11)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Parameters card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF152535),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Recording Parameters',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown<int>(
                            label: 'FLOW RATE (LPM)',
                            value: _selectedFlowRate,
                            items: _flowRates,
                            labelBuilder: (v) => '$v LPM',
                            onChanged: (v) =>
                                setState(() => _selectedFlowRate = v!),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildDropdown<String>(
                            label: 'BACKGROUND NOISE',
                            value: _selectedEnvironment,
                            items: _environments,
                            onChanged: (v) =>
                                setState(() => _selectedEnvironment = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown<int>(
                            label: 'CAPSULE DOSE (mg)',
                            value: _selectedDose,
                            items: _doses,
                            labelBuilder: (v) => '$v mg',
                            onChanged: (v) =>
                                setState(() => _selectedDose = v!),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildDropdown<int>(
                            label: 'DISTANCE TO MIC (cm)',
                            value: _selectedDistance,
                            items: _distances,
                            labelBuilder: (v) => '$v cm',
                            onChanged: (v) =>
                                setState(() => _selectedDistance = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown<int>(
                      label: 'TIMER (seconds)',
                      value: _selectedDuration,
                      items: _durations,
                      labelBuilder: (v) => '${v}s',
                      onChanged: (v) =>
                          setState(() => _selectedDuration = v!),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Timer + Record button
              Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF152535),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isRecording
                        ? Colors.red.withOpacity(0.5)
                        : Colors.white12,
                  ),
                ),
                child: Column(
                  children: [
                    if (_isRecording) ...[
                      Text(
                        '${_secondsRemaining}s',
                        style: TextStyle(
                          color: _secondsRemaining <= 3
                              ? Colors.red.shade300
                              : Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w200,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _secondsRemaining <= 3
                                ? Colors.red.shade400
                                : Colors.tealAccent,
                          ),
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'RECORDING  •  ${_currentFileId ?? ''}',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else ...[
                      Text(
                        '${_selectedDuration}s',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 48,
                          fontWeight: FontWeight.w200,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildRecordButton(),
                    const SizedBox(height: 16),
                    if (!_isRecording && !_isSaving)
                      const Text(
                        'Tap to start recording',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    if (_lastSavedFileId != null && !_isRecording && !_isSaving)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Colors.tealAccent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Saved: $_lastSavedFileId.wav',
                              style: const TextStyle(
                                  color: Colors.tealAccent, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Spec badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _specBadge('44100 Hz'),
                  _specBadge('Mono'),
                  _specBadge('PCM WAV'),
                  _specBadge('Unprocessed Src'),
                  _specBadge('No AGC / NS'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _specBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.tealAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 11,
              letterSpacing: 0.5)),
    );
  }
}
