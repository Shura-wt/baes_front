part of "../main.dart";

class HistoriqueErreur {
  final int id;
  final int baesId;
  final String typeErreur;
  final DateTime timestamp;
  final bool isSolved;
  final bool isIgnored;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;

  HistoriqueErreur({
    required this.id,
    required this.baesId,
    required this.typeErreur,
    required this.timestamp,
    this.isSolved = false,
    this.isIgnored = false,
    this.acknowledgedBy,
    this.acknowledgedAt,
  });

  factory HistoriqueErreur.fromJson(Map<String, dynamic> json) {
    // Handle null or missing values with default values
    final id = json['id'] ?? 0;
    final baesId = json['baes_id'] ?? 0;
    final typeErreur = json['type_erreur'] ?? 'unknown';
    final isSolved = json['is_solved'] ?? false;
    final isIgnored = json['is_ignored'] ?? false;
    final acknowledgedBy = json['acknowledged_by'];

    // Handle timestamp parsing with error handling
    DateTime timestamp;
    try {
      timestamp = json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now();
    } catch (e) {
      // If parsing fails, use current time as fallback
      timestamp = DateTime.now();
    }

    // Handle acknowledged_at parsing
    DateTime? acknowledgedAt;
    try {
      acknowledgedAt = json['acknowledged_at'] != null 
          ? DateTime.parse(json['acknowledged_at']) 
          : null;
    } catch (e) {
      acknowledgedAt = null;
    }

    final erreur = HistoriqueErreur(
      id: id,
      baesId: baesId,
      typeErreur: typeErreur,
      timestamp: timestamp,
      isSolved: isSolved,
      isIgnored: isIgnored,
      acknowledgedBy: acknowledgedBy,
      acknowledgedAt: acknowledgedAt,
    );

    return erreur;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baes_id': baesId,
      'type_erreur': typeErreur,
      'timestamp': timestamp.toIso8601String(),
      'is_solved': isSolved,
      'is_ignored': isIgnored,
      'acknowledged_by': acknowledgedBy,
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
    };
  }
}
