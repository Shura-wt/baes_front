part of '../main.dart';

class LeftDrawer extends StatefulWidget {
  const LeftDrawer({super.key});

  @override
  State<LeftDrawer> createState() => _LeftDrawerState();
}

class _LeftDrawerState extends State<LeftDrawer> {
  // On peut supprimer la variable _selectedSite locale si l'on utilise le provider
  // String _selectedSite = "";

  // Variables pour les filtres
  bool _showConnectionError = true;
  bool _showBatteryError = true;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final siteProvider = Provider.of<SiteProvider>(context);

    // Utiliser la liste de sites du SiteProvider (qui est mise à jour lors de la création)
    final List<SiteAssociation> sites = siteProvider.sites;

    // Utiliser l'ID du site pour la correspondance
    final int? currentSiteId = siteProvider.selectedSite?.id ??
        (sites.isNotEmpty ? sites.first.id : null);

    // Déterminer si l'utilisateur peut changer de site
    final bool canChangeSite =
        authProvider.isAdmin || authProvider.isSuperAdmin;

    // Récupérer le site complet avec ses bâtiments
    final Site? completeSite = currentSiteId != null
        ? siteProvider.getCompleteSiteById(currentSiteId)
        : null;

    // Récupérer tous les bâtiments du site
    final List<Batiment> batiments = completeSite?.batiments ?? [];

    return SafeArea(
      child: Drawer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF98a069),
                Color(0xFF045f78),
                Color(0xFF1c2d41),
              ],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 50),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Site :  ",
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    if (canChangeSite)
                      Expanded(
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF045f78),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: DropdownButton<int>(
                              isExpanded: true,
                              // Ajout de cette propriété
                              value: currentSiteId,
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: Colors.white),
                              dropdownColor: const Color(0xFF045f78),
                              underline: Container(),
                              onChanged: (int? newSiteId) {
                                if (newSiteId != null) {
                                  final selected = sites.firstWhere(
                                    (site) => site.id == newSiteId,
                                    orElse: () => sites.first,
                                  );
                                  siteProvider.setSelectedSite(selected);
                                }
                              },
                              items: sites.map((site) {
                                return DropdownMenuItem<int>(
                                  value: site.id,
                                  child: Text(
                                    site.name,
                                    // Possibilité de tronquer le texte si besoin
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                            )),
                      )
                    else
                      Text(
                        // Affiche le nom du site sélectionné
                        siteProvider.selectedSite?.name ?? "",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 20),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (canChangeSite)
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _showNewSiteDialog,
                      ),
                  ],
                ),
              ),
              _buildHeader(authProvider),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: "Bâtiments"),
                          Tab(text: "Erreurs"),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Onglet 1 : Liste des bâtiments
                            ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: batiments.length,
                              itemBuilder: (context, index) {
                                final batiment = batiments[index];
                                return BuildingTile(
                                  batiment: batiment,
                                  showConnectionError: _showConnectionError,
                                  showBatteryError: _showBatteryError,
                                );
                              },
                            ),
                            // Onglet 2 : Liste des BAES en erreur
                            _buildErrorTab(batiments),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Widget pour le header (filtres).
  Widget _buildHeader(AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          const SizedBox(height: 10),
          // Filtres.
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Afficher erreurs de connexion",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Checkbox(
                value: _showConnectionError,
                onChanged: (value) {
                  setState(() {
                    _showConnectionError = value ?? false;
                  });
                },
              ),
            ],
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Afficher erreurs de batterie",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Checkbox(
                value: _showBatteryError,
                onChanged: (value) {
                  setState(() {
                    _showBatteryError = value ?? false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Widget pour l'onglet "Erreurs".
  Widget _buildErrorTab(List<Batiment> batiments) {
    // Collecter tous les BAES en erreur
    List<Baes> errorBaes = [];

    for (var batiment in batiments) {
      for (var etage in batiment.etages) {
        for (var baes in Baes.allBaes.where((b) => b.etageId == etage.id)) {
          // Un BAES est en erreur s'il a des erreurs dans sa liste
          if (baes.erreurs.isNotEmpty) {
            // Filtrer selon les types d'erreurs sélectionnés
            bool hasConnectionError =
                baes.erreurs.any((e) => e.typeErreur == 'connection');
            bool hasBatteryError =
                baes.erreurs.any((e) => e.typeErreur == 'battery');

            if ((_showConnectionError && hasConnectionError) ||
                (_showBatteryError && hasBatteryError)) {
              errorBaes.add(baes);
            }
          }
        }
      }
    }

    if (errorBaes.isEmpty) {
      return const Center(
        child: Text(
          "Aucune erreur détectée (selon votre filtre)",
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: errorBaes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final baes = errorBaes[index];
        return ErrorBAESTile(baes: baes);
      },
    );
  }

  /// Affiche une boîte de dialogue pour créer un nouveau site.
  void _showNewSiteDialog() {
    final TextEditingController siteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Créer un nouveau site"),
          content: TextField(
            controller: siteController,
            decoration: const InputDecoration(labelText: "Nom du site"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () async {
                String newSiteName = siteController.text.trim();
                if (newSiteName.isNotEmpty) {
                  try {
                    final siteProvider =
                        Provider.of<SiteProvider>(context, listen: false);
                    final newSite = await siteProvider.createSite(newSiteName);
                    // On met à jour directement le provider, pas besoin d'une variable locale ici
                    siteProvider.setSelectedSite(newSite);
                  } catch (e) {
                    // Erreur lors de la création du site
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text("Créer"),
            ),
          ],
        );
      },
    );
  }
}

class BuildingTile extends StatelessWidget {
  final Batiment batiment;
  final bool showConnectionError;
  final bool showBatteryError;

  const BuildingTile({
    super.key,
    required this.batiment,
    required this.showConnectionError,
    required this.showBatteryError,
  });

  @override
  Widget build(BuildContext context) {
    // Récupérer tous les BAES pour ce bâtiment
    List<Baes> allBaesInBuilding = [];
    for (var etage in batiment.etages) {
      allBaesInBuilding
          .addAll(Baes.allBaes.where((baes) => baes.etageId == etage.id));
    }

    final total = allBaesInBuilding.length;

    // Compter les erreurs selon les filtres
    int errors = 0;
    for (var baes in allBaesInBuilding) {
      bool hasConnectionError =
          baes.erreurs.any((e) => e.typeErreur == 'connection');
      bool hasBatteryError = baes.erreurs.any((e) => e.typeErreur == 'battery');

      if ((showConnectionError && hasConnectionError) ||
          (showBatteryError && hasBatteryError)) {
        errors++;
      }
    }

    final errorChipColor = errors == 0 ? Colors.green : Colors.red;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ExpansionTile(
        title: Row(
          children: [
            Text("Bâtiment ${batiment.name}",
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Chip(
              shape: CircleBorder(side: BorderSide(color: Colors.grey[300]!)),
              label: Text("$total",
                  style: const TextStyle(fontSize: 12, color: Colors.black)),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 8),
            Chip(
              shape: CircleBorder(side: BorderSide(color: errorChipColor)),
              label: Text("$errors",
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
              backgroundColor: errorChipColor,
            ),
          ],
        ),
        children: batiment.etages.map((etage) {
          return Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: FloorTile(
              etage: etage,
              showConnectionError: showConnectionError,
              showBatteryError: showBatteryError,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FloorTile extends StatelessWidget {
  final Etage etage;
  final bool showConnectionError;
  final bool showBatteryError;

  const FloorTile({
    super.key,
    required this.etage,
    required this.showConnectionError,
    required this.showBatteryError,
  });

  @override
  Widget build(BuildContext context) {
    // Récupérer tous les BAES pour cet étage
    final List<Baes> baesInFloor =
        Baes.allBaes.where((baes) => baes.etageId == etage.id).toList();

    final total = baesInFloor.length;

    // Compter les erreurs selon les filtres
    int errors = 0;
    for (var baes in baesInFloor) {
      bool hasConnectionError =
          baes.erreurs.any((e) => e.typeErreur == 'connection');
      bool hasBatteryError = baes.erreurs.any((e) => e.typeErreur == 'battery');

      if ((showConnectionError && hasConnectionError) ||
          (showBatteryError && hasBatteryError)) {
        errors++;
      }
    }

    final errorChipColor = errors == 0 ? Colors.green : Colors.red;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ExpansionTile(
        title: Row(
          children: [
            Text("Étage ${etage.name}",
                style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Chip(
              shape: CircleBorder(side: BorderSide(color: Colors.grey[300]!)),
              label: Text("$total",
                  style: const TextStyle(fontSize: 12, color: Colors.black)),
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(width: 8),
            Chip(
              shape: CircleBorder(side: BorderSide(color: errorChipColor)),
              label: Text("$errors",
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
              backgroundColor: errorChipColor,
            ),
          ],
        ),
        children: baesInFloor
            .map((baes) => Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: BAESTile(
                    baes: baes,
                    showConnectionError: showConnectionError,
                    showBatteryError: showBatteryError,
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class BAESTile extends StatelessWidget {
  final Baes baes;
  final bool showConnectionError;
  final bool showBatteryError;

  const BAESTile({
    super.key,
    required this.baes,
    required this.showConnectionError,
    required this.showBatteryError,
  });

  @override
  Widget build(BuildContext context) {
    // Vérifier les erreurs
    bool hasConnectionError =
        baes.erreurs.any((e) => e.typeErreur == 'connection');
    bool hasBatteryError = baes.erreurs.any((e) => e.typeErreur == 'battery');

    return ListTile(
      title: Text(
        "BAES ID: ${baes.id} - ${baes.name}",
        style: Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(color: Colors.black),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: "Connexion",
            child: Icon(
              Icons.wifi,
              color: hasConnectionError ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: "Erreur batterie",
            child: Icon(
              Icons.battery_unknown_outlined,
              color: hasBatteryError ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorBAESTile extends StatelessWidget {
  final Baes baes;

  const ErrorBAESTile({super.key, required this.baes});

  @override
  Widget build(BuildContext context) {
    // Trouver l'étage et le bâtiment pour ce BAES
    final etage = Etage.allEtages.firstWhere(
      (e) => e.id == baes.etageId,
      orElse: () => Etage(id: 0, name: "Inconnu", batimentId: 0, baes: []),
    );

    final batiment = Batiment.allBatiments.firstWhere(
      (b) => b.id == etage.batimentId,
      orElse: () =>
          Batiment(id: 0, name: "Inconnu", polygonPoints: {}, etages: []),
    );

    // Vérifier les erreurs
    bool hasConnectionError =
        baes.erreurs.any((e) => e.typeErreur == 'connection');
    bool hasBatteryError = baes.erreurs.any((e) => e.typeErreur == 'battery');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ListTile(
        title: Text(
          "Bâtiment ${batiment.name} - Étage ${etage.name} - BAES ID: ${baes.id}",
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.black),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: "Connexion",
              child: Icon(
                Icons.wifi,
                color: hasConnectionError ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: "Erreur batterie",
              child: Icon(
                Icons.battery_unknown_outlined,
                color: hasBatteryError ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
