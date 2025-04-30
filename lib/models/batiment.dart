part of "../main.dart";

class Batiment {
  static final List<Batiment> allBatiments = [];

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

    // Ensure polygon_points is in the correct format
    dynamic polygonPoints = json['polygon_points'];
    if (polygonPoints != null) {
      // If it's already a Map with 'points' key, use it as is
      if (polygonPoints is Map && polygonPoints.containsKey('points')) {
        // It's already in the correct format
      }
      // If it's a List, convert it to the expected format
      else if (polygonPoints is List) {
        // Convert the list to a map with 'points' key
        polygonPoints = polygonPoints;
      }
      // For any other format, use an empty map
      else {
        polygonPoints = {};
      }
    } else {
      polygonPoints = {};
    }

    // Create the Batiment instance
    final batiment = Batiment(
      id: json['id'] ?? 0,
      // Use 0 if id is null
      name: json['name'] ?? '',
      // Use empty string if name is null
      polygonPoints: polygonPoints,
      // Use the processed polygon points
      siteId: json['site_id'],
      etages: etagesList,
    );

    // Check if a batiment with the same ID already exists in the list
    final existingIndex = allBatiments.indexWhere((b) => b.id == batiment.id);
    if (existingIndex >= 0) {
      // Replace the existing batiment
      allBatiments[existingIndex] = batiment;
    } else {
      // Add the new batiment to the list
      allBatiments.add(batiment);
    }

    return batiment;
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
