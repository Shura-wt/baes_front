part of '../../main.dart';

class APIBatiment {
  static String baseUrl = Config.baseUrl;

  /// Récupère toutes les données d'un bâtiment (étages, cartes, BAES)
  static Future<Batiment?> getBuildingAllData(int batimentId) async {
    try {
      // Log the API call

      // Envoyer la requête
      final response = await http.get(
        Uri.parse('$baseUrl/general/batiment/$batimentId/alldata'),
        headers: {'Content-Type': 'application/json'},
      );

      // Log the API response

      if (response.statusCode == 200) {
        // Créer un objet Batiment à partir de la réponse
        final jsonData = jsonDecode(response.body);
        return Batiment.fromJson(jsonData);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Crée un nouveau bâtiment
  static Future<Batiment?> createBatiment(
      String name, List<LatLng> polygonPoints, int siteId) async {
    try {
      // Convertir les points du polygone au format attendu par l'API
      final List<List<double>> points = polygonPoints
          .map((point) => [point.latitude, point.longitude])
          .toList();

      // Préparer les données à envoyer
      final Map<String, dynamic> data = {
        'name': name,
        'polygon_points': {'points': points},
        'site_id': siteId
      };

      // Log the API call

      // Envoyer la requête
      final response = await http.post(
        Uri.parse('$baseUrl/batiments/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      // Log the API response

      if (response.statusCode == 201) {
        // Créer un objet Batiment à partir de la réponse
        final jsonData = jsonDecode(response.body);
        return Batiment.fromJson(jsonData);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Met à jour un bâtiment existant
  static Future<Batiment?> updateBatiment(int batimentId, String name) async {
    try {
      // Préparer les données à envoyer
      final Map<String, dynamic> data = {
        'name': name,
      };

      // Log the API call

      // Envoyer la requête
      final response = await http.put(
        Uri.parse('$baseUrl/batiments/$batimentId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      // Log the API response

      if (response.statusCode == 200) {
        // Créer un objet Batiment à partir de la réponse
        final jsonData = jsonDecode(response.body);
        return Batiment.fromJson(jsonData);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Supprime un bâtiment
  static Future<bool> deleteBatiment(int batimentId) async {
    try {
      // Log the API call
      print("API CALL: DELETE $baseUrl/batiments/$batimentId");

      // Envoyer la requête
      final response = await http.delete(
        Uri.parse('$baseUrl/batiments/$batimentId'),
        headers: {'Content-Type': 'application/json'},
      );

      // Log the API response

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
