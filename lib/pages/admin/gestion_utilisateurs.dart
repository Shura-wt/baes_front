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

  @override
  void initState() {
    super.initState();
    _loadUsers();
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
        // On récupère la liste des rôles sous forme de List<String>
        final roles = (result['roles'] as List<dynamic>).cast<String>();
        // On récupère la liste des sites sous forme de titres.
        final sitesNames = (result['sites'] as List<dynamic>).cast<String>();
        final password = result['password'] as String?;

        Utilisateur updatedUser;
        try {
          if (utilisateur == null) {
            // Création d'un nouvel utilisateur.
            updatedUser = await UtilisateurApi.createUser(
              username: username,
              roles: roles,
              password: password,
            );
            setState(() {
              _users.add(updatedUser);
            });
          } else {
            // Modification de l'utilisateur existant.
            updatedUser = await UtilisateurApi.updateUser(
              utilisateur.id,
              username: username,
              roles: roles,
              password: password,
            );
            setState(() {
              final index = _users.indexWhere((u) => u.id == utilisateur.id);
              if (index != -1) {
                _users[index] = updatedUser;
              }
            });
          }

          Site? findSiteByTitle(List<Site> sites, String title) {
            for (var site in sites) {
              if (site.name.toLowerCase() == title.toLowerCase()) {
                return site;
              }
            }
            return null;
          }

          // Mise à jour de l'association des sites à l'utilisateur.
          final siteProvider =
              Provider.of<SiteProvider>(context, listen: false);
          for (final siteName in sitesNames) {
            try {
              final matchingSite =
                  findSiteByTitle(siteProvider.completeSites, siteName);
              if (matchingSite != null) {
                await UtilisateurApi.associateSiteToUser(
                  userId: updatedUser.id,
                  siteId: matchingSite.id,
                );
              } else {
                // Site non trouvé
              }
            } catch (e) {
              // Erreur lors de l'association du site
            }
          }

          // Après avoir associé les sites, rafraîchir l'utilisateur pour obtenir la liste mise à jour.
          final refreshedUser =
              await UtilisateurApi.getUserById(updatedUser.id);
          setState(() {
            final index = _users.indexWhere((u) => u.id == updatedUser.id);
            if (index != -1) {
              _users[index] = refreshedUser;
            }

            // Mettre à jour la liste filtrée
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            _filterUsers(authProvider);
          });
        } catch (e) {
          // Erreur lors de la création/modification de l'utilisateur
        }
      }
    });
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

    // Mettre à jour la liste filtrée si l'utilisateur connecté change
    _filterUsers(authProvider);

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
                          DataCell(Text(user.globalRoles.join(', '))),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createOrEditUtilisateur(),
        tooltip: 'Ajouter un utilisateur',
        child: const Icon(Icons.add),
      ),
    );
  }
}
