class Recording {
  final int? id;
  final String fileId;
  final String inhalerType;
  final int flowRate;
  final String actuations;
  final bool isInhalation;
  final String environment;
  final int doseMg;
  final int distanceCm;
  final int durationSec;
  final DateTime timestamp;

  Recording({
    this.id,
    required this.fileId,
    required this.inhalerType,
    required this.flowRate,
    required this.actuations,
    required this.isInhalation,
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
      'inhaler_type': inhalerType,
      'flow_rate': flowRate,
      'actuations': actuations,
      'is_inhalation': isInhalation ? 1 : 0,
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
      // Graceful defaults for rows that predate the v2 migration
      inhalerType: (map['inhaler_type'] as String?) ?? 'None',
      flowRate: map['flow_rate'] as int,
      actuations: (map['actuations'] as String?) ?? 'No',
      isInhalation: ((map['is_inhalation'] as int?) ?? 0) == 1,
      environment: map['environment'] as String,
      doseMg: map['dose_mg'] as int,
      distanceCm: map['distance_cm'] as int,
      durationSec: map['duration_sec'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}
