part of '../../main.dart';
//
// class GestionUtilisateursPage extends StatefulWidget {
//   const GestionUtilisateursPage({super.key});
//
//   @override
//   State<GestionUtilisateursPage> createState() =>
//       _GestionUtilisateursPageState();
// }
//
// class _GestionUtilisateursPageState extends State<GestionUtilisateursPage> {
//   // Liste locale des utilisateurs récupérée via l'API.
//   List<Utilisateur> _users = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUsers();
//   }
//
//   Future<void> _loadUsers() async {
//     try {
//       // Récupérer la liste des utilisateurs depuis l'API.
//       final users = await UtilisateurApi.getAllUsers();
//       setState(() {
//         _users = users;
//       });
//     } catch (e) {
//       // Gérez l'erreur (affichage d'un message, etc.)
//       debugPrint('Erreur lors du chargement des utilisateurs: $e');
//     }
//   }
//
//   /// Affiche un popup dialogue pour créer ou modifier un utilisateur.
//   /// Si [utilisateur] est null, il s'agit d'une création ; sinon, c'est une modification.
//   void _createOrEditUtilisateur({Utilisateur? utilisateur}) {
//     showDialog<Map<String, dynamic>>(
//       context: context,
//       builder: (context) {
//         return _UtilisateurDialog(
//           title: utilisateur == null
//               ? 'Créer un nouvel utilisateur'
//               : 'Modifier l\'utilisateur',
//           confirmButtonText: 'Valider',
//           initialUser: utilisateur,
//         );
//       },
//     ).then((result) async {
//       if (result != null) {
//         final username = result['username'] as String;
//         // On récupère la liste des rôles sous forme de List<String>
//         final roles = (result['roles'] as List<dynamic>).cast<String>();
//         // On récupère la liste des sites sous forme de titres.
//         final sitesNames = (result['sites'] as List<dynamic>).cast<String>();
//         final password = result['password'] as String?;
//
//         Utilisateur updatedUser;
//         try {
//           if (utilisateur == null) {
//             // Création d'un nouvel utilisateur.
//             updatedUser = await UtilisateurApi.createUser(
//               username: username,
//               role: roles.first, // Utilisation du premier rôle pour la création
//               password: password,
//             );
//             setState(() {
//               _users.add(updatedUser);
//             });
//           } else {
//             // Modification de l'utilisateur existant.
//             updatedUser = await UtilisateurApi.updateUser(
//               utilisateur.id,
//               username: username,
//               role: roles.first,
//               password: password,
//             );
//             setState(() {
//               final index = _users.indexWhere((u) => u.id == utilisateur.id);
//               if (index != -1) {
//                 _users[index] = updatedUser;
//               }
//             });
//           }
//           Site? findSiteByTitle(List<Site> sites, String title) {
//             for (var site in sites) {
//               if (site.title.toLowerCase() == title.toLowerCase()) {
//                 return site;
//               }
//             }
//             return null;
//           }
//
//           // Mise à jour de l'association des sites à l'utilisateur.
//           final siteProvider =
//               Provider.of<SiteProvider>(context, listen: false);
//           for (final siteName in sitesNames) {
//             try {
//               final matchingSite =
//                   findSiteByTitle(siteProvider.sites, siteName);
//               if (matchingSite != null) {
//                 await UtilisateurApi.associateSiteToUser(
//                   userId: updatedUser.id,
//                   siteId: matchingSite.id,
//                 );
//               } else {
//                 debugPrint("Aucun site trouvé pour le titre: $siteName");
//               }
//             } catch (e) {
//               debugPrint(
//                   "Erreur lors de l'association du site '$siteName': $e");
//             }
//           }
//
//           // Après avoir associé les sites, rafraîchir l'utilisateur pour obtenir la liste mise à jour.
//           final refreshedUser =
//               await UtilisateurApi.getUserById(updatedUser.id);
//           setState(() {
//             final index = _users.indexWhere((u) => u.id == updatedUser.id);
//             if (index != -1) {
//               _users[index] = refreshedUser;
//             }
//           });
//         } catch (e) {
//           debugPrint(
//               'Erreur lors de la création/modification de l\'utilisateur: $e');
//         }
//       }
//     });
//   }
//
//   /// Affiche un popup de confirmation pour supprimer un utilisateur.
//   void _deleteUtilisateur(Utilisateur utilisateur) {
//     showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('Supprimer l\'utilisateur'),
//           content:
//               Text('Êtes-vous sûr de vouloir supprimer ${utilisateur.login} ?'),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text('Annuler'),
//             ),
//             TextButton(
//               onPressed: () async {
//                 try {
//                   await UtilisateurApi.deleteUser(utilisateur.id);
//                   setState(() {
//                     _users.removeWhere((u) => u.id == utilisateur.id);
//                   });
//                 } catch (e) {
//                   debugPrint('Erreur lors de la suppression: $e');
//                 }
//                 Navigator.pop(context);
//               },
//               child: const Text('Supprimer'),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final siteProvider = Provider.of<SiteProvider>(context, listen: true);
//     for (final site in siteProvider._sites) {
//       print("Site: ${site.title}, ID: ${site.id}");
//     }
//
//     Widget content;
//     if (_users.isEmpty) {
//       content = Center(
//         child: Text(
//           "Aucun utilisateur disponible",
//           style: Theme.of(context).textTheme.titleLarge,
//         ),
//       );
//     } else {
//       content = Card(
//         margin: const EdgeInsets.all(15),
//         child: ListView.separated(
//           shrinkWrap: true,
//           padding: const EdgeInsets.all(10),
//           itemCount: _users.length,
//           separatorBuilder: (context, index) => const Divider(
//             height: 1,
//             color: Colors.grey,
//           ),
//           itemBuilder: (context, index) {
//             final utilisateur = _users[index];
//             return ListTile(
//               title: Text("Nom : ${utilisateur.login}"),
//               subtitle: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text("Rôle : ${utilisateur.roles}"),
//                   Text("Sites : ${utilisateur.sites}"),
//                 ],
//               ),
//               trailing: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   IconButton(
//                     icon: const Icon(Icons.edit),
//                     onPressed: () =>
//                         _createOrEditUtilisateur(utilisateur: utilisateur),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.delete),
//                     onPressed: () => _deleteUtilisateur(utilisateur),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       );
//     }
//
//     return Scaffold(
//       body: GradiantBackground.getSafeAreaGradiant(context, content),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => _createOrEditUtilisateur(),
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }
