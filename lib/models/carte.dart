// modele_carte.dart
part of "../main.dart";

class Carte {
  static final List<Carte> allCartes = [];

  final int id;
  final String chemin;
  final int? etageId;
  final int? siteId;
  final double centerLat;
  final double centerLng;
  final double zoom;

  Carte({
    required this.id,
    required this.chemin,
    this.etageId,
    this.siteId,
    required this.centerLat,
    required this.centerLng,
    required this.zoom,
  });

  factory Carte.fromJson(Map<String, dynamic> json) {
    // Create the Carte instance
    final carte = Carte(
      id: json['id'] ?? 0,  // Use 0 if id is null
      chemin: json['chemin'] ?? '',  // Use empty string if chemin is null
      etageId: json['etage_id'] as int?,
      siteId: json['site_id'] as int?,
      centerLat: json['center_lat'] != null && json['center_lat'] is num 
          ? (json['center_lat'] as num).toDouble() 
          : 0.0,
      centerLng: json['center_lng'] != null && json['center_lng'] is num 
          ? (json['center_lng'] as num).toDouble() 
          : 0.0,
      zoom: json['zoom'] != null && json['zoom'] is num 
          ? (json['zoom'] as num).toDouble() 
          : 0.0,
    );

    // Check if a carte with the same ID already exists in the list
    final existingIndex = allCartes.indexWhere((c) => c.id == carte.id);
    if (existingIndex >= 0) {
      // Replace the existing carte
      allCartes[existingIndex] = carte;
    } else {
      // Add the new carte to the list
      allCartes.add(carte);
    }

    return carte;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chemin': chemin,
      'etage_id': etageId,
      'site_id': siteId,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'zoom': zoom,
    };
  }
}
