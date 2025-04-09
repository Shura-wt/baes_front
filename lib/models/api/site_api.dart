part of "../../main.dart";

class SiteApi {
  static const String baseUrl = 'http://localhost:5000';

  /// Crée un nouveau site via l'API.
  /// Le corps de la requête est au format { "name": "NomDuSite" }.
  /// En cas de succès (HTTP 201), retourne un objet [Site] construit à partir de la réponse.
  static Future<Site> createSite({required String name}) async {
    final url = Uri.parse('$baseUrl/sites/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Site.fromJson(json);
    } else {
      throw Exception(
          'Erreur lors de la création du site. Code HTTP: ${response.statusCode}');
    }
  }
}
