part of '../main.dart';

class SiteProvider with ChangeNotifier {
  static String baseUrl = Config.baseUrl;

  // Cache pour éviter les appels API redondants
  static final Map<int, DateTime> _lastRefreshTime = {};
  static const Duration _cacheValidityDuration =
      Duration(minutes: 5); // Durée de validité du cache

  List<SiteAssociation> _sites = [];
  SiteAssociation? _selectedSite;

  List<SiteAssociation> get sites => _sites;

  SiteAssociation? get selectedSite => _selectedSite;

  // La liste complète des sites (récupérée d'une API, mise à jour ultérieurement, etc.)
  List<Site> completeSites = [];

  // Constructeur qui initialise la liste completeSites et charge les sites depuis l'API
  SiteProvider() {
    // Initialiser completeSites avec les sites déjà chargés
    updateCompleteSites();

    // Charger tous les sites depuis l'API
    loadAllSites().then((_) {
      print('SiteProvider: Sites chargés depuis l\'API dans le constructeur');
    });
  }

  /// Met à jour la liste completeSites avec les sites de Site.allSites
  void updateCompleteSites() {
    completeSites = List.from(Site.allSites);
    notifyListeners();
  }

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

  /// Rafraîchit les données d'un site depuis l'API, avec mise en cache.
  /// Retourne le site mis à jour ou null en cas d'erreur.
  Future<Site?> refreshSiteData(int siteId) async {
    try {
      // Vérifier si le site est déjà dans le cache et si le cache est encore valide
      final now = DateTime.now();
      final lastRefresh = _lastRefreshTime[siteId];

      // Si le site est dans le cache et que le cache est encore valide, utiliser le site du cache
      if (lastRefresh != null &&
          now.difference(lastRefresh) < _cacheValidityDuration) {
        // Récupérer le site depuis la liste statique (qui fait office de cache)
        final cachedSite = getCompleteSiteById(siteId);
        if (cachedSite != null) {
          print('Utilisation du site en cache pour l\'ID $siteId');
          return cachedSite;
        }
      }

      // Si le site n'est pas dans le cache ou si le cache n'est plus valide, faire un appel API
      print('Récupération du site depuis l\'API pour l\'ID $siteId');
      final site = await SiteApi.getCompleteSiteById(siteId);

      if (site != null) {
        // Le site est automatiquement mis à jour dans la liste Site.allSites
        // grâce à la méthode updateOrAddSite appelée dans Site.fromJson

        // Mettre à jour le cache
        _lastRefreshTime[siteId] = now;

        // Mettre à jour la liste completeSites
        updateCompleteSites();

        return site;
      } else {
        return null;
      }
    } catch (e) {
      print('Erreur lors du rafraîchissement des données du site $siteId: $e');
      return null;
    }
  }

  /// Met à jour le site sélectionné et notifie les écouteurs.
  void setSelectedSite(SiteAssociation site) {
    _selectedSite = site;
    notifyListeners();
  }

  /// Charge les sites depuis l'API et met à jour la liste.
  /// Si un contexte est fourni, charge uniquement les sites associés à l'utilisateur courant.
  Future<void> loadSites([BuildContext? context]) async {
    // Si un contexte est fourni, utiliser les sites de l'utilisateur courant
    if (context != null) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        // Utiliser directement les sites associés à l'utilisateur
        _sites = authProvider.currentUser!.sites;
        notifyListeners();
        return;
      }
    }

    // Sinon, charger tous les sites depuis l'API (comportement par défaut)
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

      // Mettre à jour la liste completeSites
      updateCompleteSites();
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

      // Mettre à jour la liste completeSites
      updateCompleteSites();

      return newSite;
    } catch (e) {
      throw Exception('Erreur lors de la création du site: ${e.toString()}');
    }
  }

  /// Charge tous les sites complets depuis l'API et met à jour la liste completeSites.
  /// Cette méthode est utile pour s'assurer que tous les sites sont chargés avant d'ouvrir un dialogue.
  Future<void> loadAllSites() async {
    try {
      print('Début du chargement de tous les sites');
      final url = Uri.parse('$baseUrl/sites/');
      print('Envoi de la requête GET à $url');
      final response = await http.get(url);
      print('Réponse reçue: Status ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty || response.body == 'null') {
          print('Aucun site disponible dans la réponse API');
          return;
        }

        print('Corps de la réponse: ${response.body}');
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is List) {
          print('Nombre de sites trouvés: ${decoded.length}');

          // Créer directement des objets Site à partir des données JSON
          for (var siteData in decoded) {
            if (siteData is Map<String, dynamic> && siteData['id'] != null) {
              final siteId = siteData['id'] as int;
              final siteName = siteData['name'] as String? ?? 'Site sans nom';
              print('Création du site: ID=$siteId, Nom=$siteName');

              // Créer un objet Site directement
              final site = Site(
                id: siteId,
                name: siteName,
                batiments: [],
                carte: null,
              );

              // Ajouter le site à la liste globale
              Site.updateOrAddSite(site);

              // Récupérer les détails complets du site en arrière-plan
              refreshSiteData(siteId);
            }
          }

          // Mettre à jour la liste completeSites immédiatement
          updateCompleteSites();
          print(
              'Liste completeSites mise à jour: ${completeSites.length} sites');
        } else {
          print('Format de données invalide: une liste était attendue');
        }
      } else {
        print(
            'Erreur lors de la récupération des sites. Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors du chargement de tous les sites: $e');
    }
  }

  /// Supprime un site via l'API.
  /// En cas de succès, met à jour les listes de sites et retourne true.
  /// En cas d'échec, retourne false.
  Future<bool> deleteSite(int siteId) async {
    try {
      print('Début de la suppression du site $siteId');

      // Appel à l'API pour supprimer le site
      final success = await SiteApi.deleteSite(siteId);

      if (success) {
        print('Site $siteId supprimé avec succès');

        // Supprimer le site de la liste des sites
        _sites.removeWhere((site) => site.id == siteId);

        // Si le site supprimé était le site sélectionné, sélectionner un autre site
        if (_selectedSite != null && _selectedSite!.id == siteId) {
          _selectedSite = _sites.isNotEmpty ? _sites.first : null;
        }

        // Supprimer le site de la liste globale
        Site.allSites.removeWhere((site) => site.id == siteId);

        // Mettre à jour la liste completeSites
        updateCompleteSites();

        // Notifier les écouteurs
        notifyListeners();

        return true;
      } else {
        print('Échec de la suppression du site $siteId');
        return false;
      }
    } catch (e) {
      print('Erreur lors de la suppression du site $siteId: $e');
      return false;
    }
  }
}
