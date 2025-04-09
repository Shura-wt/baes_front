// modele_carte.dart
part of "../main.dart";

class Carte {
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
    return Carte(
      id: json['id'],
      chemin: json['chemin'],
      etageId: json['etage_id'],
      siteId: json['site_id'],
      centerLat: (json['center_lat'] as num).toDouble(),
      centerLng: (json['center_lng'] as num).toDouble(),
      zoom: (json['zoom'] as num).toDouble(),
    );
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
