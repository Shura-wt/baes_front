part of "../../main.dart";

class BaesApi {
  static String baseUrl = Config.baseUrl;

  /// Récupère tous les étages d'un bâtiment
  static Future<List<Etage>> getFloorByIdBatiment(int batimentId) async {
    // Get floors for building

    try {
      // Envoyer la requête
      final response = await http.get(
        Uri.parse('$baseUrl/batiments/$batimentId/floors'),
        headers: {'Content-Type': 'application/json'},
      );

      // Process response

      if (response.statusCode == 200) {
        // Créer une liste d'objets Etage à partir de la réponse
        final List<dynamic> jsonData = jsonDecode(response.body);
        final floors = jsonData.map((json) => Etage.fromJson(json)).toList();

        return floors;
      } else {
        // Error getting floors
        return [];
      }
    } catch (e) {
      // Exception handling
      return [];
    }
  }

  /// Récupère tous les BAES d'un étage
  static Future<List<Baes>> getBaesByIdFloor(int etageId) async {
    try {
      // Envoyer la requête
      final response = await http.get(
        Uri.parse('$baseUrl/etages/$etageId/baes'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        // Créer une liste d'objets Baes à partir de la réponse
        final List<dynamic> jsonData = jsonDecode(response.body);

        // Add etageId to each BAES JSON object if it's not already present
        for (var json in jsonData) {
          if (json is Map<String, dynamic> && json['etage_id'] == null) {
            json['etage_id'] = etageId;
          }
        }

        return jsonData.map((json) => Baes.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Crée un nouvel étage
  static Future<Etage?> createFloor(String name, int batimentId) async {
    try {
      // Préparer les données à envoyer
      final Map<String, dynamic> data = {
        'name': name,
        'batiment_id': batimentId,
      };

      // Envoyer la requête
      final response = await http.post(
        Uri.parse('$baseUrl/etages/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        // Créer un objet Etage à partir de la réponse
        final jsonData = jsonDecode(response.body);
        return Etage.fromJson(jsonData);
      } else {
        // Error creating floor
        return null;
      }
    } catch (e) {
      // Exception handling
      return null;
    }
  }


  /// Récupère la carte d'un étage par son ID
  /// Cette méthode est un proxy vers APICarte.getFloorMapByFloorId()
  static Future<Carte?> getFloorMapByFloorId(int floorId) async {
    return APICarte.getFloorMapByFloorId(floorId);
  }

  /// Télécharge une image de carte pour un étage
  static Future<Carte?> uploadFloorMap(
      int etageId, Uint8List imageBytes, LatLng center, double zoom) async {
    // Upload floor map

    try {
      // Crée un objet FormData pour l'envoi multipart
      var request = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/cartes/upload-carte'));

      // Ajoute l'image au formulaire
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'floor_map.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));

      // Ajoute les paramètres de la carte
      request.fields['center_lat'] = center.latitude.toString();
      request.fields['center_lng'] = center.longitude.toString();
      request.fields['zoom'] = zoom.toString();
      request.fields['etage_id'] = etageId.toString();

      // Envoie la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Crée un objet Carte à partir de la réponse
        final jsonData = jsonDecode(response.body);
        if (jsonData.containsKey('carte')) {
          final carte = Carte.fromJson(jsonData['carte']);
          return carte;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Met à jour un étage existant
  static Future<Etage?> updateFloor(int etageId, String name) async {
    try {
      // Préparer les données à envoyer
      final Map<String, dynamic> data = {
        'name': name,
      };

      // Envoyer la requête
      final response = await http.put(
        Uri.parse('$baseUrl/etages/$etageId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        // Créer un objet Etage à partir de la réponse
        final jsonData = jsonDecode(response.body);
        return Etage.fromJson(jsonData);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Supprime un étage
  static Future<bool> deleteFloor(int etageId) async {
    try {
      // Envoyer la requête
      final response = await http.delete(
        Uri.parse('$baseUrl/etages/$etageId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Crée un nouveau BAES
  static Future<Baes?> createBaes(
      String name, Map<String, dynamic> position, int etageId) async {
    try {
      // Préparer les données à envoyer
      final Map<String, dynamic> data = {
        'name': name,
        'position': position,
        'etage_id': etageId,
      };

      // Envoyer la requête
      final response = await http.post(
        Uri.parse('$baseUrl/baes/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 201) {
        // Créer un objet Baes à partir de la réponse
        final jsonData = jsonDecode(response.body);
        return Baes.fromJson(jsonData);
      } else {
        // Error creating BAES
        return null;
      }
    } catch (e) {
      // Exception handling
      return null;
    }
  }

  /// Met à jour la position d'un BAES existant
  static Future<Baes?> updateBaesPosition(
      int baesId, Map<String, dynamic> position) async {
    try {
      // Préparer les données à envoyer
      final Map<String, dynamic> data = {
        'position': position,
      };

      // Envoyer la requête
      final response = await http.put(
        Uri.parse('$baseUrl/baes/$baesId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        // Créer un objet Baes à partir de la réponse
        final jsonData = jsonDecode(response.body);
        return Baes.fromJson(jsonData);
      } else {
        // Error updating BAES
        return null;
      }
    } catch (e) {
      // Exception handling
      return null;
    }
  }
}
