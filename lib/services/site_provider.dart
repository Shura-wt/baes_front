part of '../main.dart';

class SiteProvider with ChangeNotifier {
  static String baseUrl = Config.baseUrl;

  List<SiteAssociation> _sites = [];
  SiteAssociation? _selectedSite;

  List<SiteAssociation> get sites => _sites;

  SiteAssociation? get selectedSite => _selectedSite;

  // La liste complète des sites (récupérée d'une API, mise à jour ultérieurement, etc.)
  List<Site> completeSites = [];

  /// Retourne le site complet ayant l'ID correspondant.
  /// Si aucun site n'est trouvé, retourne null.
  Site? getCompleteSiteById(int id) {
    try {
      final site = Site.allSites.firstWhere(
        (site) => site.id == id,
      );
      return site;
    } catch (e) {
      return null;
    }
  }

  /// Rafraîchit les données d'un site depuis l'API.
  /// Retourne le site mis à jour ou null en cas d'erreur.
  Future<Site?> refreshSiteData(int siteId) async {
    try {
      // Récupère le site complet depuis l'API
      final site = await SiteApi.getCompleteSiteById(siteId);

      if (site != null) {
        // Le site est automatiquement mis à jour dans la liste Site.allSites
        // grâce à la méthode updateOrAddSite appelée dans Site.fromJson

        // Notifie les écouteurs que les données ont changé
        notifyListeners();

        return site;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Met à jour le site sélectionné et notifie les écouteurs.
  void setSelectedSite(SiteAssociation site) {
    _selectedSite = site;
    notifyListeners();
  }

  /// Charge les sites depuis l'API et met à jour la liste.
  Future<void> loadSites() async {
    final url = Uri.parse('$baseUrl/sites/');

    // Log the API call

    final response = await http.get(url);

    // Log the API response

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
    try {
      // Utiliser la méthode consolidée de SiteApi
      final site = await SiteApi.createSite(name: name);

      // Convertir Site en SiteAssociation
      SiteAssociation newSite = SiteAssociation.fromJson(site.toJson());

      // Ajouter à la liste et notifier les écouteurs
      _sites.add(newSite);
      notifyListeners();

      return newSite;
    } catch (e) {
      throw Exception('Erreur lors de la création du site: ${e.toString()}');
    }
  }
}
