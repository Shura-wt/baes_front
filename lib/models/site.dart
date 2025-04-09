part of "../main.dart";

class Site {
  final int id;
  final String name;
  final List<Batiment> batiments;
  final Carte? carte;

  Site({
    required this.id,
    required this.name,
    required this.batiments,
    this.carte,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    var batimentsList = <Batiment>[];
    if (json['batiments'] != null) {
      batimentsList =
          (json['batiments'] as List).map((e) => Batiment.fromJson(e)).toList();
    }
    return Site(
      id: json['id'],
      name: json['name'],
      batiments: batimentsList,
      carte: json['carte'] != null ? Carte.fromJson(json['carte']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'batiments': batiments.map((e) => e.toJson()).toList(),
      'carte': carte?.toJson(),
    };
  }
}
