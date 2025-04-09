part of "../main.dart";

class HistoriqueErreur {
  final int id;
  final int baesId;
  final String typeErreur;
  final DateTime timestamp;

  HistoriqueErreur({
    required this.id,
    required this.baesId,
    required this.typeErreur,
    required this.timestamp,
  });

  factory HistoriqueErreur.fromJson(Map<String, dynamic> json) {
    return HistoriqueErreur(
      id: json['id'],
      baesId: json['baes_id'],
      typeErreur: json['type_erreur'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baes_id': baesId,
      'type_erreur': typeErreur,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
