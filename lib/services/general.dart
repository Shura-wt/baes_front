part of '../main.dart';

/// Cette méthode récupère toutes les informations de l'utilisateur (sites, bâtiments, étages, BAES, erreurs et cartes)
/// depuis l'API et reconstruit l'ensemble des objets en hiérarchie. Elle s'assure que tous les objets sont correctement
/// stockés dans leurs listes statiques respectives pour un accès facile.
Future<List<Site>> getGeneralInfos(BuildContext context) async {
  String baseUrl = Config.baseUrl;

  // Récupère l'AuthProvider pour obtenir l'ID de l'utilisateur connecté.
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final int? userId = authProvider.userId;

  if (userId == null) {
    return [];
  }

  // Vider les listes statiques pour éviter les doublons
  Site.allSites.clear();
  Batiment.allBatiments.clear();
  Etage.allEtages.clear();
  Carte.allCartes.clear();
  Baes.allBaes.clear();

  // Construire l'URL
  final url = Uri.parse("$baseUrl/general/user/$userId/alldata");

  try {
    // Log the API call

    final response = await http.get(url);

    // Log the API response

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = jsonDecode(response.body);

      // Vérification de la présence de la clé 'sites' dans la réponse JSON
      final List<dynamic> sitesJson = jsonData['sites'] ?? [];

      // Construction des objets Site (avec leurs relations) depuis la réponse JSON
      List<Site> sites = sitesJson.map((siteJson) {
        return Site.fromJson(siteJson as Map<String, dynamic>);
      }).toList();

      return sites;
    } else {
      return [];
    }
  } catch (e) {
    return [];
  }
}
