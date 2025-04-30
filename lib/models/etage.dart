part of "../main.dart";

// modele_batiment.dart
class Etage {
  static final List<Etage> allEtages = [];

  final int id;
  final String name;
  final int batimentId;
  final Carte? carte;
  final List<Baes> baes;

  Etage({
    required this.id,
    required this.name,
    required this.batimentId,
    this.carte,
    required this.baes,
  });

  factory Etage.fromJson(Map<String, dynamic> json) {
    var baesList = <Baes>[];
    if (json['baes'] != null) {
      baesList = (json['baes'] as List).map((e) => Baes.fromJson(e)).toList();
    }

    // Create the Etage instance
    final etage = Etage(
      id: json['id'] ?? 0,  // Use 0 if id is null
      name: json['name'] ?? '',  // Use empty string if name is null
      batimentId: json['batiment_id'] ?? 0,  // Use 0 if batiment_id is null
      carte: json['carte'] != null ? Carte.fromJson(json['carte']) : null,
      baes: baesList,
    );

    // Check if an etage with the same ID already exists in the list
    final existingIndex = allEtages.indexWhere((e) => e.id == etage.id);
    if (existingIndex >= 0) {
      // Replace the existing etage
      allEtages[existingIndex] = etage;
    } else {
      // Add the new etage to the list
      allEtages.add(etage);
    }

    return etage;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'batiment_id': batimentId,
      'carte': carte?.toJson(),
      'baes': baes.map((e) => e.toJson()).toList(),
    };
  }
}
