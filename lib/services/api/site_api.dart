part of "../../main.dart";

class SiteApi {
  static String baseUrl = Config.baseUrl;

  /// Crée un nouveau site via l'API.
  /// Le corps de la requête est au format { "name": "NomDuSite" }.
  /// En cas de succès (HTTP 201), retourne un objet [Site] construit à partir de la réponse.
  static Future<Site> createSite({required String name}) async {
    final url = Uri.parse('$baseUrl/sites/');

    // Log the API call
    print("API CALL: POST $baseUrl/sites/ with data: ${jsonEncode({
          'name': name
        })}");

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );

    // Log the API response

    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Site.fromJson(json);
    } else {
      throw Exception(
          'Erreur lors de la création du site. Code HTTP: ${response.statusCode}');
    }
  }

  /// Récupère un site complet avec ses bâtiments et étages via l'API.
  /// En cas de succès (HTTP 200), retourne un objet [Site] construit à partir de la réponse.
  static Future<Site?> getCompleteSiteById(int siteId) async {
    try {
      final url = Uri.parse('$baseUrl/sites/$siteId/');

      // Log the API call
      print("API CALL: GET $baseUrl/sites/$siteId/");

      final response = await http.get(url);

      // Log the API response

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Site.fromJson(json);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
