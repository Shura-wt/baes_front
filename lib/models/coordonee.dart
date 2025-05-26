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
    // Add null checks for coordinate values
    num? lat1Value = json['lat1'] as num?;
    num? lng1Value = json['lng1'] as num?;
    num? lat2Value = json['lat2'] as num?;
    num? lng2Value = json['lng2'] as num?;

    return Coords(
      lat1: lat1Value?.toDouble() ?? 0.0,
      lng1: lng1Value?.toDouble() ?? 0.0,
      lat2: lat2Value?.toDouble() ?? 0.0,
      lng2: lng2Value?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'lat1': lat1,
        'lng1': lng1,
        'lat2': lat2,
        'lng2': lng2,
      };
}
