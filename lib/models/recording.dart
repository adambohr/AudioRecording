class Recording {
  final int? id;
  final String fileId;
  final int flowRate;
  final String environment;
  final int doseMg;
  final int distanceCm;
  final int durationSec;
  final DateTime timestamp;

  Recording({
    this.id,
    required this.fileId,
    required this.flowRate,
    required this.environment,
    required this.doseMg,
    required this.distanceCm,
    required this.durationSec,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_id': fileId,
      'flow_rate': flowRate,
      'environment': environment,
      'dose_mg': doseMg,
      'distance_cm': distanceCm,
      'duration_sec': durationSec,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Recording.fromMap(Map<String, dynamic> map) {
    return Recording(
      id: map['id'] as int?,
      fileId: map['file_id'] as String,
      flowRate: map['flow_rate'] as int,
      environment: map['environment'] as String,
      doseMg: map['dose_mg'] as int,
      distanceCm: map['distance_cm'] as int,
      durationSec: map['duration_sec'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
