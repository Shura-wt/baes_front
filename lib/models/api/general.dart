part of '../../main.dart';

/// Cette méthode récupère toutes les informations de l'utilisateur (sites, bâtiments, étages, BAES, erreurs et cartes)
/// depuis l'API et reconstruit l'ensemble des objets en hiérarchie. Elle réalise ensuite des print() pour
/// vérifier que les objets créés sont corrects.
Future<void> getGeneralInfos(BuildContext context) async {
  // Récupère l'AuthProvider pour obtenir l'ID de l'utilisateur connecté.
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final int? userId = authProvider.userId;

  if (userId == null) {
    print("Aucun utilisateur connecté.");
    return;
  }

  // Construire l'URL (attention si vous utilisez un préfixe dans votre blueprint, adaptez l'URL)
  final url = Uri.parse('http://localhost:5000/general/user/$userId/alldata');

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      final List<dynamic> sitesJson = jsonData['sites'] ?? [];

      // Construction des objets Site (avec leurs relations) depuis la réponse JSON
      List<Site> sites = sitesJson.map((siteJson) {
        return Site.fromJson(siteJson as Map<String, dynamic>);
      }).toList();

      // Affichage de la hiérarchie dans la console
      print("----- SITES -----");
      for (var site in sites) {
        print("Site : id=${site.id}, name=${site.name}");
        if (site.carte != null) {
          print("  Carte du Site : ${site.carte!.toJson()}");
        }
        // Parcours des bâtiments du site
        if (site.batiments.isNotEmpty) {
          print("  BATIMENTS :");
          for (var bat in site.batiments) {
            print("    Batiment : id=${bat.id}, name=${bat.name}");
            print("      Polygon Points: ${bat.polygonPoints}");
            // Parcours des étages
            if (bat.etages.isNotEmpty) {
              print("      ETAGES :");
              for (var etage in bat.etages) {
                print("        Etage : id=${etage.id}, name=${etage.name}");
                if (etage.carte != null) {
                  print(
                      "          Carte de l'étage : ${etage.carte!.toJson()}");
                }
                // Parcours des BAES
                if (etage.baes.isNotEmpty) {
                  print("          BAES :");
                  for (var b in etage.baes) {
                    print("            BAES : id=${b.id}, name=${b.name}");
                    print("              Position : ${b.position}");
                    // Parcours des erreurs associées
                    if (b.erreurs.isNotEmpty) {
                      print("              ERREURS :");
                      for (var err in b.erreurs) {
                        print(
                            "                Erreur : id=${err.id}, type=${err.typeErreur}, timestamp=${err.timestamp.toIso8601String()}");
                      }
                    }
                  }
                }
              }
            }
          }
        } else {
          print("  Aucun bâtiment pour ce site.");
        }
        print("---------------------------");
      }
    } else {
      print(
          "Erreur lors de la récupération des données. Code: ${response.statusCode}");
    }
  } catch (e) {
    print("Exception lors de la récupération des données: $e");
  }
}
