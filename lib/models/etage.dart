part of "../main.dart";

// modele_batiment.dart
class Etage {
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
    return Etage(
      id: json['id'],
      name: json['name'],
      batimentId: json['batiment_id'],
      carte: json['carte'] != null ? Carte.fromJson(json['carte']) : null,
      baes: baesList,
    );
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
