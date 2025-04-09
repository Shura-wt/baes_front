part of "../main.dart";

class Batiment {
  final int id;
  final String name;
  final dynamic
      polygonPoints; // Vous pouvez ajuster le type en fonction du format (ex. List<dynamic>)
  final int? siteId;
  final List<Etage> etages;

  Batiment({
    required this.id,
    required this.name,
    required this.polygonPoints,
    this.siteId,
    required this.etages,
  });

  factory Batiment.fromJson(Map<String, dynamic> json) {
    var etagesList = <Etage>[];
    if (json['etages'] != null) {
      etagesList =
          (json['etages'] as List).map((e) => Etage.fromJson(e)).toList();
    }
    return Batiment(
      id: json['id'],
      name: json['name'],
      polygonPoints: json['polygon_points'],
      siteId: json['site_id'],
      etages: etagesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'polygon_points': polygonPoints,
      'site_id': siteId,
      'etages': etages.map((e) => e.toJson()).toList(),
    };
  }
}
