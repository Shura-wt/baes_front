part of "../main.dart";

// Classe pour représenter des coordonnées (par exemple, pour définir la zone d’un bâtiment).
/// Ici, nous utilisons deux points : le coin supérieur gauche (lat1, lng1)
/// et le coin inférieur droit (lat2, lng2).
class Coords {
  final double lat1;
  final double lng1;
  final double lat2;
  final double lng2;

  Coords({
    required this.lat1,
    required this.lng1,
    required this.lat2,
    required this.lng2,
  });

  factory Coords.fromJson(Map<String, dynamic> json) {
    return Coords(
      lat1: (json['lat1'] as num).toDouble(),
      lng1: (json['lng1'] as num).toDouble(),
      lat2: (json['lat2'] as num).toDouble(),
      lng2: (json['lng2'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'lat1': lat1,
        'lng1': lng1,
        'lat2': lat2,
        'lng2': lng2,
      };
}
