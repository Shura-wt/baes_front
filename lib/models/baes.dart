part of "../main.dart";

class Baes {
  final int id;
  final String name;
  final Map<String, dynamic> position;
  final int etageId;
  final List<HistoriqueErreur> erreurs;

  Baes({
    required this.id,
    required this.name,
    required this.position,
    required this.etageId,
    required this.erreurs,
  });

  factory Baes.fromJson(Map<String, dynamic> json) {
    var erreursList = <HistoriqueErreur>[];
    if (json['erreurs'] != null) {
      erreursList = (json['erreurs'] as List)
          .map((e) => HistoriqueErreur.fromJson(e))
          .toList();
    }
    return Baes(
      id: json['id'],
      name: json['name'],
      position: json['position'],
      etageId: json['etage_id'],
      erreurs: erreursList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'position': position,
      'etage_id': etageId,
      'erreurs': erreurs.map((e) => e.toJson()).toList(),
    };
  }
}
