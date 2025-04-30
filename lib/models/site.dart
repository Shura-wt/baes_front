part of "../main.dart";

class Site {
  static final List<Site> allSites = [];
  final int id;
  final String name;
  final List<Batiment> batiments;
  final Carte? carte;

  Site({
    required this.id,
    required this.name,
    required this.batiments,
    this.carte,
  });

  factory Site.fromJson(Map<String, dynamic> json) {
    // Récupération de la liste brute des bâtiments
    final List<dynamic>? rawBatiments = json['batiments'] as List<dynamic>?;

    final List<Batiment> batimentsList = rawBatiments != null
        ? rawBatiments
            .map((e) => Batiment.fromJson(e as Map<String, dynamic>))
            .toList()
        : <Batiment>[];

    // Création de l'objet Site
    final site = Site(
      id: json['id'] != null ? json['id'] as int : 0,  // Use 0 if id is null
      name: json['name'] != null ? json['name'] as String : '',  // Use empty string if name is null
      batiments: batimentsList,
      carte: json['carte'] != null
          ? Carte.fromJson(json['carte'] as Map<String, dynamic>)
          : null,
    );

    // Mise à jour ou ajout du site dans la liste globale
    updateOrAddSite(site);

    return site;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'batiments': batiments.map((e) => e.toJson()).toList(),
      'carte': carte?.toJson(),
    };
  }

  /// Met à jour un site existant ou ajoute un nouveau site à la liste globale.
  static void updateOrAddSite(Site site) {
    // Recherche si le site existe déjà dans la liste
    int existingIndex = -1;
    for (int i = 0; i < allSites.length; i++) {
      if (allSites[i].id == site.id) {
        existingIndex = i;
        break;
      }
    }

    if (existingIndex >= 0) {
      // Le site existe déjà, on le remplace
      allSites[existingIndex] = site;
    } else {
      // Le site n'existe pas encore, on l'ajoute
      allSites.add(site);
    }
  }

  /// Efface tous les sites de la liste globale.
  static void clearAllSites() {
    allSites.clear();
  }
}
