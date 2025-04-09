part of '../main.dart';

class LeftDrawer extends StatefulWidget {
  const LeftDrawer({Key? key}) : super(key: key);

  @override
  State<LeftDrawer> createState() => _LeftDrawerState();
}

class _LeftDrawerState extends State<LeftDrawer> {
  // Stocke le nom du site sélectionné.
  String _selectedSite = "";

  @override
  void initState() {
    super.initState();
    // Au démarrage, si l'utilisateur est connecté et possède au moins un site,
    // on sélectionne le premier site.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null &&
        authProvider.currentUser!.sites.isNotEmpty) {
      _selectedSite = authProvider.currentUser!.sites.first.name;
      // Mise à jour du site sélectionné dans le SiteProvider.
      Provider.of<SiteProvider>(context, listen: false)
          .setSelectedSite(authProvider.currentUser!.sites.first);
    }
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
                    // Appel via SiteProvider pour créer le site.
                    final siteProvider =
                        Provider.of<SiteProvider>(context, listen: false);
                    final newSite = await siteProvider.createSite(newSiteName);
                    setState(() {
                      _selectedSite = newSite.name;
                    });
                    // Mettre à jour le site sélectionné dans le provider.
                    siteProvider.setSelectedSite(newSite);
                  } catch (e) {
                    debugPrint("Erreur lors de la création du site: $e");
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final List<SiteAssociation> sites = authProvider.currentUser?.sites ?? [];

    // Vérifier si l'utilisateur est admin ou super-admin (à adapter selon votre logique)
    final bool canChangeSite =
        authProvider.isAdmin || authProvider.isSuperAdmin;

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
              // En-tête du Drawer : sélection du site et bouton de création (pour admin/super-admin).
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
                    canChangeSite
                        ? Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF045f78),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: DropdownButton<String>(
                                value: _selectedSite.isNotEmpty
                                    ? _selectedSite
                                    : (sites.isNotEmpty
                                        ? sites.first.name
                                        : null),
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: Colors.white),
                                dropdownColor: const Color(0xFF045f78),
                                underline: Container(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _selectedSite = newValue;
                                      final selected = sites.firstWhere(
                                        (site) => site.name == newValue,
                                        orElse: () => sites.first,
                                      );
                                      Provider.of<SiteProvider>(context,
                                              listen: false)
                                          .setSelectedSite(selected);
                                    });
                                  }
                                },
                                items: sites.map((site) {
                                  return DropdownMenuItem<String>(
                                    value: site.name,
                                    child: Text(
                                      site.name,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          )
                        : Text(
                            _selectedSite,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 20),
                          ),
                    if (canChangeSite)
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: _showNewSiteDialog,
                      ),
                  ],
                ),
              ),
              // Ajoutez ici d'autres éléments du Drawer, par exemple des onglets ou listes de bâtiments.
              Expanded(
                child: Center(
                  child: Text(
                    "Contenu du Drawer",
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class BuildingTile extends StatelessWidget {
//   final int batId;
//   final List<Baes> baes;
//
//   const BuildingTile({
//     super.key,
//     required this.batId,
//     required this.baes,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final total = baes.length;
//     final errors =
//         baes.where((b) => b.status_error || !b.status_connection).length;
//     final errorChipColor = errors == 0 ? Colors.green : Colors.red;
//
//     // Regrouper les Baes par étage.
//     final Map<int, List<Baes>> floors = {};
//     for (var b in baes) {
//       floors.putIfAbsent(b.idEtage, () => []).add(b);
//     }
//
//     return Card(
//       elevation: 2,
//       margin: const EdgeInsets.only(bottom: 16.0),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
//       child: ExpansionTile(
//         title: Row(
//           children: [
//             Text("Bâtiment $batId",
//                 style: Theme.of(context).textTheme.titleMedium),
//             const Spacer(),
//             Chip(
//               shape: CircleBorder(side: BorderSide(color: Colors.grey[300]!)),
//               label: Text("$total",
//                   style: const TextStyle(fontSize: 12, color: Colors.black)),
//               backgroundColor: Colors.grey[300],
//             ),
//             const SizedBox(width: 8),
//             Chip(
//               shape: CircleBorder(side: BorderSide(color: errorChipColor)),
//               label: Text("$errors",
//                   style: const TextStyle(fontSize: 12, color: Colors.white)),
//               backgroundColor: errorChipColor,
//             ),
//           ],
//         ),
//         children: floors.entries.map((entry) {
//           return Padding(
//             padding: const EdgeInsets.only(left: 16.0),
//             child: FloorTile(
//               floorId: entry.key,
//               baes: entry.value,
//             ),
//           );
//         }).toList(),
//       ),
//     );
//   }
// }
//
// class FloorTile extends StatelessWidget {
//   final int floorId;
//   final List<Baes> baes;
//
//   const FloorTile({
//     Key? key,
//     required this.floorId,
//     required this.baes,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     final total = baes.length;
//     final errors =
//         baes.where((b) => b.status_error || !b.status_connection).length;
//     final errorChipColor = errors == 0 ? Colors.green : Colors.red;
//
//     return Card(
//       elevation: 1,
//       margin: const EdgeInsets.only(bottom: 8.0),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
//       child: ExpansionTile(
//         title: Row(
//           children: [
//             Text("Étage $floorId",
//                 style: Theme.of(context).textTheme.titleSmall),
//             const Spacer(),
//             Chip(
//               shape: CircleBorder(side: BorderSide(color: Colors.grey[300]!)),
//               label: Text("$total",
//                   style: const TextStyle(fontSize: 12, color: Colors.black)),
//               backgroundColor: Colors.grey[300],
//             ),
//             const SizedBox(width: 8),
//             Chip(
//               shape: CircleBorder(side: BorderSide(color: errorChipColor)),
//               label: Text("$errors",
//                   style: const TextStyle(fontSize: 12, color: Colors.white)),
//               backgroundColor: errorChipColor,
//             ),
//           ],
//         ),
//         children: baes
//             .map((b) => Padding(
//                   padding: const EdgeInsets.only(left: 16.0),
//                   child: BAESTile(baes: b),
//                 ))
//             .toList(),
//       ),
//     );
//   }
// }
//
// class BAESTile extends StatelessWidget {
//   final Baes baes;
//
//   const BAESTile({Key? key, required this.baes}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       title: Text(
//         "Baes ID: ${baes.id}",
//         style: Theme.of(context)
//             .textTheme
//             .bodyLarge
//             ?.copyWith(color: Colors.black),
//       ),
//       trailing: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Tooltip(
//             message: "Connexion",
//             child: Icon(
//               Icons.wifi,
//               color: baes.status_connection ? Colors.green : Colors.red,
//             ),
//           ),
//           const SizedBox(width: 8),
//           Tooltip(
//             message: "Erreur batterie",
//             child: Icon(
//               Icons.battery_unknown_outlined,
//               color: baes.status_error ? Colors.red : Colors.green,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class ErrorBAESTile extends StatelessWidget {
//   final Baes baes;
//
//   const ErrorBAESTile({super.key, required this.baes});
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
//       child: ListTile(
//         title: Text(
//           "Bâtiment ${baes.idBatiment} - Étage ${baes.idEtage} - Baes ID: ${baes.id}",
//           style: Theme.of(context)
//               .textTheme
//               .bodyLarge
//               ?.copyWith(color: Colors.black),
//         ),
//         trailing: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Tooltip(
//               message: "Connexion",
//               child: Icon(
//                 Icons.wifi,
//                 color: baes.status_connection ? Colors.green : Colors.red,
//               ),
//             ),
//             const SizedBox(width: 8),
//             Tooltip(
//               message: "Erreur batterie",
//               child: Icon(
//                 Icons.battery_unknown_outlined,
//                 color: baes.status_error ? Colors.red : Colors.green,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
