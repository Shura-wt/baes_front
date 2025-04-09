part of '../main.dart';

class SiteProvider with ChangeNotifier {
  static const String baseUrl = 'http://localhost:5000';

  List<SiteAssociation> _sites = [];
  SiteAssociation? _selectedSite;

  List<SiteAssociation> get sites => _sites;

  SiteAssociation? get selectedSite => _selectedSite;

  /// Met à jour le site sélectionné et notifie les écouteurs.
  void setSelectedSite(SiteAssociation site) {
    _selectedSite = site;
    notifyListeners();
  }

  /// Charge les sites depuis l'API et met à jour la liste.
  Future<void> loadSites() async {
    final url = Uri.parse('$baseUrl/sites/');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      if (response.body.isEmpty || response.body == 'null') {
        _sites = [];
      } else {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          _sites = decoded
              .map<SiteAssociation>((data) =>
                  SiteAssociation.fromJson(data as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception(
              "Format de données invalide : une liste était attendue.");
        }
      }
      notifyListeners();
    } else {
      throw Exception(
          "Erreur lors de la récupération des sites. Code: ${response.statusCode}");
    }
  }

  /// Crée un nouveau site via l'API et l'ajoute à la liste.
  Future<SiteAssociation> createSite(String name) async {
    final url = Uri.parse('$baseUrl/sites/');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 201) {
      final json = jsonDecode(response.body);
      SiteAssociation newSite = SiteAssociation.fromJson(json);
      _sites.add(newSite);
      notifyListeners();
      return newSite;
    } else {
      throw Exception(
          'Erreur lors de la création du site. Code HTTP: ${response.statusCode}');
    }
  }
}
