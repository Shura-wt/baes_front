part of "../main.dart";

class Baes {
  static final List<Baes> allBaes = [];

  /// Récupère les BAES pour un étage donné de manière plus sûre
  static List<Baes> getBaesForFloor(int etageId) {
    return allBaes.where((b) => b.etageId == etageId).toList();
  }

  /// Récupère les BAES pour un bâtiment (tous les étages) de manière plus sûre
  static List<Baes> getBaesForBuilding(List<Etage> etages) {
    List<Baes> result = [];
    for (var etage in etages) {
      result.addAll(getBaesForFloor(etage.id));
    }
    return result;
  }

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

    // Handle erreurs array with error handling
    try {
      if (json['erreurs'] != null) {
        if (json['erreurs'] is List) {
          erreursList = (json['erreurs'] as List)
              .map((e) => HistoriqueErreur.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        // If erreurs is not a List, leave erreursList as an empty list
      }
    } catch (e) {
      // If there's an error parsing the erreurs list, use an empty list
      erreursList = <HistoriqueErreur>[];
    }

    // Handle null or missing values with default values
    final id = json['id'] ?? 0;
    final name = json['name'] ?? '';

    // Process position data to ensure it has the expected structure
    Map<String, dynamic> position = <String, dynamic>{};
    if (json['position'] != null) {
      if (json['position'] is Map) {
        position = json['position'] as Map<String, dynamic>;

        // Debug: Print the raw position data
        print("Raw position data for BAES $id: $position");

        // Ensure position has lat/lng keys (might be under latitude/longitude)
        if (position['lat'] == null && position['latitude'] != null) {
          position['lat'] = position['latitude'];
        }
        if (position['lng'] == null && position['longitude'] != null) {
          position['lng'] = position['longitude'];
        }

        // If we still don't have lat/lng, check if they're at the root level
        if (position['lat'] == null && json['lat'] != null) {
          position['lat'] = json['lat'];
        }
        if (position['lng'] == null && json['lng'] != null) {
          position['lng'] = json['lng'];
        }

        // Debug: Print the processed position data
        print("Processed position data for BAES $id: $position");
      } else {
        print("Position is not a Map for BAES $id: ${json['position']}");
      }
    } else {
      print("No position data for BAES $id");
    }

    // Try to get etageId from different possible keys
    int etageId = 0;
    if (json['etage_id'] != null) {
      etageId = json['etage_id'] as int;
    } else if (json['etageId'] != null) {
      etageId = json['etageId'] as int;
    } else if (json['floor_id'] != null) {
      etageId = json['floor_id'] as int;
    }

    // Debug: Print the etageId
    print("BAES ID: ${json['id']}, etageId: $etageId");

    // Create the Baes instance
    final baes = Baes(
      id: id,
      name: name,
      position: position,
      etageId: etageId,
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
