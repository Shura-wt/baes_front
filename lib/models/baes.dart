part of "../main.dart";

class Baes {
  static final List<Baes> allBaes = [];

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

    // Create the Baes instance
    final baes = Baes(
      id: json['id'],
      name: json['name'],
      position: json['position'],
      etageId: json['etage_id'],
      erreurs: erreursList,
    );

    // Check if a baes with the same ID already exists in the list
    final existingIndex = allBaes.indexWhere((b) => b.id == baes.id);
    if (existingIndex >= 0) {
      // Replace the existing baes
      allBaes[existingIndex] = baes;
    } else {
      // Add the new baes to the list
      allBaes.add(baes);
    }

    return baes;
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
