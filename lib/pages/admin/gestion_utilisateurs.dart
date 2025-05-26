part of '../../main.dart';

class GestionUtilisateursPage extends StatefulWidget {
  const GestionUtilisateursPage({super.key});

  @override
  State<GestionUtilisateursPage> createState() =>
      _GestionUtilisateursPageState();
}

class _GestionUtilisateursPageState extends State<GestionUtilisateursPage> {
  /// Liste des utilisateurs récupérés depuis l'API.
  List<Utilisateur> _users = [];
  List<Utilisateur> _filteredUsers = [];
  bool _isLoading = true;

  // Fonction de callback pour le listener de l'authProvider
  void _authProviderListener() {
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      setState(() {
        _filterUsers(authProvider);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();

    // Ajouter un listener pour mettre à jour les utilisateurs filtrés quand l'authProvider change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.addListener(_authProviderListener);
    });
  }

  @override
  void dispose() {
    // Nettoyer les listeners pour éviter les fuites de mémoire
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.removeListener(_authProviderListener);
    } catch (e) {
      // Ignorer les erreurs si le provider n'est plus disponible
    }
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer la liste des utilisateurs depuis l'API.
      final users = await UtilisateurApi.getAllUsers();

      // Filtrer les utilisateurs en fonction du rôle de l'utilisateur connecté
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      setState(() {
        _users = users;
        _filterUsers(authProvider);
        print('Utilisateurs récupérés: ${_users.length}');

        _isLoading = false;
      });
    } catch (e) {
      // Gérez l'erreur (affichage d'un message, etc.)
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterUsers(AuthProvider authProvider) {
    if (authProvider.isSuperAdmin) {
      // Super admin voit tous les utilisateurs
      _filteredUsers = List.from(_users);
    } else if (authProvider.isAdmin) {
      // Admin voit uniquement les utilisateurs des sites qui lui sont attribués
      final currentUserSiteIds =
          authProvider.currentUser?.sites.map((site) => site.id).toSet() ?? {};

      _filteredUsers = _users.where((user) {
        // Vérifier si l'utilisateur a au moins un site en commun avec l'admin
        final userSiteIds = user.sites.map((site) => site.id).toSet();
        return userSiteIds.intersection(currentUserSiteIds).isNotEmpty;
      }).toList();
    } else {
      // Autres rôles ne voient aucun utilisateur
      _filteredUsers = [];
    }
  }

  /// Affiche un popup dialogue pour créer ou modifier un utilisateur.
  /// Si [utilisateur] est null, il s'agit d'une création ; sinon, c'est une modification.
  void _createOrEditUtilisateur({Utilisateur? utilisateur}) {
    // S'assurer que les sites sont chargés avant d'afficher le dialogue
    final siteProvider = Provider.of<SiteProvider>(context, listen: false);
    print(
        'GestionUtilisateursPage: Chargement des sites avant d\'afficher le dialogue');
    siteProvider.loadAllSites().then((_) {
      print(
          'GestionUtilisateursPage: Sites chargés, nombre de sites: ${siteProvider.completeSites.length}');

      // Afficher le dialogue une fois les sites chargés
      showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) {
          return UtilisateurDialog(
            title: utilisateur == null
                ? 'Créer un nouvel utilisateur'
                : 'Modifier l\'utilisateur',
            confirmButtonText: 'Valider',
            initialUser: utilisateur,
          );
        },
      ).then((result) async {
        if (result != null) {
          final username = result['username'] as String;
          // On récupère la liste des rôles globaux sous forme de List<String> (vide dans la nouvelle UI)
          final globalRoles =
              (result['globalRoles'] as List<dynamic>).cast<String>();
          // On récupère la map des rôles par site sous forme de Map<int, List<int>>
          final siteRoles = (result['siteRoles'] as Map<dynamic, dynamic>).map(
              (key, value) => MapEntry(int.parse(key.toString()),
                  (value as List<dynamic>).cast<int>()));
          final password = result['password'] as String?;

          Utilisateur updatedUser;
          try {
            // Utiliser un bloc try-catch global pour gérer les erreurs de transaction
            try {
              if (utilisateur == null) {
                // Création d'un nouvel utilisateur avec relations site-rôle
                // Convertir la map siteRoles (Map<int, List<int>>) en map rolesBySite (Map<int, int>)
                // Pour chaque site, on prend le premier rôle assigné (si plusieurs rôles sont assignés)
                final Map<int, int> rolesBySite = {};
                for (final entry in siteRoles.entries) {
                  final siteId = entry.key;
                  final roleIds = entry.value;
                  if (roleIds.isNotEmpty) {
                    rolesBySite[siteId] = roleIds.first;
                  }
                }

                if (password == null || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Le mot de passe est requis pour créer un utilisateur')),
                  );
                  return;
                }

                // Utiliser la nouvelle API pour créer un utilisateur avec relations site-rôle
                updatedUser = await UtilisateurApi.createUserWithRelations(
                  username: username,
                  password: password,
                  rolesBySite: rolesBySite,
                  globalRoles: globalRoles,
                );
              } else {
                // Convertir la map siteRoles (Map<int, List<int>>) en map rolesBySite (Map<int, int>)
                // Pour chaque site, on prend le premier rôle assigné (si plusieurs rôles sont assignés)
                final Map<int, int> rolesBySite = {};
                for (final entry in siteRoles.entries) {
                  final siteId = entry.key;
                  final roleIds = entry.value;
                  if (roleIds.isNotEmpty) {
                    rolesBySite[siteId] = roleIds.first;
                  }
                }

                // Utiliser la nouvelle API pour mettre à jour un utilisateur avec relations site-rôle
                updatedUser = await UtilisateurApi.updateUserWithRelations(
                  userId: utilisateur.id,
                  username: username,
                  password: password,
                  rolesBySite: rolesBySite,
                  globalRoles: globalRoles,
                  replaceExistingRelations:
                      true, // Remplacer toutes les relations existantes
                );
              }
            } catch (e) {
              // En cas d'erreur lors de la création/modification de l'utilisateur
              print(
                  'Erreur lors de la création/modification de l\'utilisateur: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: $e')),
              );
              return; // Sortir de la méthode pour éviter de continuer avec un utilisateur non créé
            }

            // Récupérer tous les rôles pour avoir la correspondance ID-nom
            Map<int, String> roleIdToName = {};
            try {
              final allRoles = await UtilisateurApi.getAllRoles();
              print('Rôles disponibles récupérés: ${allRoles.length}');

              roleIdToName = {for (var role in allRoles) role.id: role.name};
            } catch (e) {
              print('Erreur lors de la récupération des rôles: $e');
              // Ce n'est pas une erreur critique, on continue
            }

            // Aucune assignation de rôle supplémentaire n'est nécessaire car updateUserWithRelations
            // gère déjà l'assignation des rôles aux sites
            print(
                'Utilisateur mis à jour avec relations site-rôle, pas besoin d\'assigner les rôles séparément');

            // Rafraîchir l'utilisateur pour obtenir la liste mise à jour
            try {
              final refreshedUser =
                  await UtilisateurApi.getUserById(updatedUser.id);

              // Mettre à jour l'état de l'interface utilisateur
              setState(() {
                if (utilisateur == null) {
                  // Nouvel utilisateur
                  _users.add(refreshedUser);
                } else {
                  // Utilisateur existant
                  final index =
                      _users.indexWhere((u) => u.id == updatedUser.id);
                  if (index != -1) {
                    _users[index] = refreshedUser;
                  }
                }

                // Mettre à jour la liste filtrée
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                _filterUsers(authProvider);
              });

              // Afficher un message de succès
              String message =
                  'Utilisateur ${utilisateur == null ? 'créé' : 'modifié'} avec succès';

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            } catch (e) {
              print(
                  'Erreur lors de la récupération de l\'utilisateur mis à jour: $e');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'L\'utilisateur a été ${utilisateur == null ? 'créé' : 'modifié'}, mais une erreur est survenue lors de la récupération des données mises à jour.')),
              );

              // Recharger tous les utilisateurs pour s'assurer que la liste est à jour
              _loadUsers();
            }
          } catch (e) {
            // Erreur lors de la création/modification de l'utilisateur
            print(
                'Erreur lors de la création/modification de l\'utilisateur: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: $e')),
            );
          }
        }
      });
    });
  }

  /// Retourne une couleur en fonction du rôle.
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'super-admin':
        return Colors.deepPurple;
      case 'technicien':
        return Colors.blue;
      case 'user':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  /// Affiche un popup de confirmation pour supprimer un utilisateur.
  void _deleteUtilisateur(Utilisateur utilisateur) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer l\'utilisateur'),
          content:
              Text('Êtes-vous sûr de vouloir supprimer ${utilisateur.login} ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await UtilisateurApi.deleteUser(utilisateur.id);
                  setState(() {
                    _users.removeWhere((u) => u.id == utilisateur.id);
                    _filteredUsers.removeWhere((u) => u.id == utilisateur.id);
                  });
                } catch (e) {
                  // Erreur lors de la suppression
                }
                Navigator.pop(context);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Récupérer l'authProvider pour accéder aux informations de l'utilisateur connecté
    final authProvider = Provider.of<AuthProvider>(context, listen: true);

    // Nous n'appelons plus _filterUsers ici pour éviter le double filtrage
    // Le filtrage est déjà fait dans _loadUsers et sera refait si l'utilisateur change

    Widget content;

    if (_isLoading) {
      content = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_filteredUsers.isEmpty) {
      content = Center(
        child: Text(
          "Aucun utilisateur disponible",
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
    } else {
      content = Card(
        margin: const EdgeInsets.all(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Gestion des utilisateurs",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Nom d\'utilisateur')),
                      DataColumn(label: Text('Rôles')),
                      DataColumn(label: Text('Sites')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _filteredUsers.map((user) {
                      return DataRow(
                        cells: [
                          DataCell(Text(user.login)),
                          DataCell(
                            user.globalRoles.isEmpty
                                ? const Text(
                                    'Aucun rôle',
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 4.0,
                                    runSpacing: 4.0,
                                    children: user.globalRoles.map((role) {
                                      return Container(
                                        margin: const EdgeInsets.only(
                                            right: 4, bottom: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(role),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 2,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          role,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ),
                          DataCell(Text(
                              user.sites.map((site) => site.name).join(', '))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _createOrEditUtilisateur(
                                      utilisateur: user),
                                  tooltip: 'Modifier',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteUtilisateur(user),
                                  tooltip: 'Supprimer',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: GradiantBackground.getSafeAreaGradiant(context, content),
      floatingActionButton: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: FloatingActionButton(
          onPressed: () => _createOrEditUtilisateur(),
          tooltip: 'Ajouter un utilisateur',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
